import 'dart:async';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/upload_progress.dart';
import 'package:sensebox_bike/services/chunked_uploader.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/services/isar_service/track_service.dart';
import 'package:sensebox_bike/services/opensensemap_service.dart';
import 'package:sensebox_bike/services/upload_error_classifier.dart';

class BatchUploadService {
  static const Duration defaultChunkUploadTimeout = Duration(seconds: 60);
  static const Duration _authCheckTimeout = Duration(seconds: 15);

  final OpenSenseMapService _openSenseMapService;
  final TrackService _trackService;
  final OpenSenseMapBloc _openSenseMapBloc;

  /// Hard limit for uploading a single chunk, including its retry.
  final Duration chunkUploadTimeout;

  final _progressController = StreamController<UploadProgress>.broadcast();

  /// Completed when the running upload is cancelled or has ended.
  Completer<void>? _session;
  int _totalChunks = 0;
  int _completedChunks = 0;

  BatchUploadService({
    required OpenSenseMapService openSenseMapService,
    required TrackService trackService,
    required OpenSenseMapBloc openSenseMapBloc,
    this.chunkUploadTimeout = defaultChunkUploadTimeout,
  })  : _openSenseMapService = openSenseMapService,
        _trackService = trackService,
        _openSenseMapBloc = openSenseMapBloc;

  Stream<UploadProgress> get uploadProgressStream => _progressController.stream;

  bool get isUploading => _session != null;

  /// Stops at the first chunk that fails and rethrows its error.
  /// Returns normally when cancelled via [cancelUpload].
  Future<void> uploadTrack(TrackData track, SenseBox senseBox) async {
    if (isUploading) {
      final error = Exception('Another upload is already in progress');
      unawaited(ErrorService.reportToSentry(error, StackTrace.current));
      throw error;
    }

    final session = _session = Completer<void>();
    _totalChunks = 0;
    _completedChunks = 0;

    // Work given up on (timeout, cancel) keeps running in the background;
    // once the session is over it must not report progress or send data.
    bool isActive() => !session.isCompleted;
    void report(UploadStatus status, [UploadStage? stage]) {
      if (isActive()) _emit(status, stage: stage);
    }

    try {
      track.uploadAttempts = (track.uploadAttempts ?? 0) + 1;
      track.lastUploadAttempt = DateTime.now();
      await _trackService.saveTrack(track);

      report(UploadStatus.preparing, UploadStage.checkingLogin);
      await _orCancelled(session, _waitForAuthentication());

      report(UploadStatus.preparing);
      await _orCancelled(session, track.geolocations.load());
      final geolocations = track.geolocations.toList()
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

      final uploader = ChunkedUploader(
          openSenseMapService: _openSenseMapService, senseBox: senseBox);
      final chunks = uploader.splitIntoChunks(geolocations);
      _totalChunks = chunks.length;

      for (final chunk in chunks) {
        report(UploadStatus.uploading, UploadStage.uploadingPart);
        await _orCancelled(
          session,
          uploader
              .uploadChunk(
                chunk,
                shouldSend: isActive,
                onRetry: (_) => report(UploadStatus.retrying),
              )
              .timeout(chunkUploadTimeout),
        );
        _completedChunks++;
      }

      if (chunks.isNotEmpty) {
        track.uploaded = 1;
        await _trackService.saveTrack(track);
      }
      _emit(UploadStatus.completed);
    } on UploadCancelledException {
      // A request already in flight may still reach the server.
    } catch (e, stackTrace) {
      await _fail(track, e, stackTrace);
      rethrow;
    } finally {
      if (!session.isCompleted) session.complete();
      _session = null;
    }
  }

  void cancelUpload() {
    final session = _session;
    if (session != null && !session.isCompleted) session.complete();
  }

  void dispose() {
    cancelUpload();
    _progressController.close();
  }

  Future<void> _fail(TrackData track, Object error, StackTrace stackTrace) async {
    unawaited(ErrorService.reportToSentry(
        'Batch upload of track ${track.id} failed after '
        '$_completedChunks/$_totalChunks chunks: $error',
        stackTrace));

    final kind = UploadErrorClassifier.failureKindOf(error);
    final isAuthError = kind == UploadFailureKind.authentication;
    if (isAuthError) {
      await _openSenseMapBloc.markAuthenticationFailed().catchError(
          (Object e, StackTrace s) => ErrorService.reportToSentry(e, s));
    }

    _emit(
      UploadStatus.failed,
      errorMessage: '$error',
      errorDetail: UploadErrorClassifier.describe(error),
      failureKind: kind,
      canRetry: !isAuthError,
    );
  }

  Future<void> _waitForAuthentication() async {
    final deadline = DateTime.now().add(_authCheckTimeout);
    while (_openSenseMapBloc.isAuthenticating) {
      if (DateTime.now().isAfter(deadline)) {
        throw TimeoutException('Login check did not finish', _authCheckTimeout);
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
    if (!_openSenseMapBloc.isAuthenticated) {
      throw PermanentAuthenticationError('Not logged in to openSenseMap');
    }
  }

  /// Throws [UploadCancelledException] as soon as [session] is over. The
  /// underlying work is not aborted, its result is just ignored.
  Future<T> _orCancelled<T>(Completer<void> session, Future<T> future) {
    return Future.any<T>([
      future,
      session.future.then<T>((_) => throw const UploadCancelledException()),
    ]);
  }

  void _emit(
    UploadStatus status, {
    UploadStage? stage,
    String? errorMessage,
    String? errorDetail,
    UploadFailureKind? failureKind,
    bool canRetry = false,
  }) {
    // The service may be disposed while an upload is still finishing.
    if (_progressController.isClosed) return;
    _progressController.add(UploadProgress(
      totalChunks: _totalChunks,
      completedChunks: _completedChunks,
      failedChunks: status == UploadStatus.failed ? 1 : 0,
      status: status,
      stage: stage,
      errorMessage: errorMessage,
      errorDetail: errorDetail,
      failureKind: failureKind,
      canRetry: canRetry,
    ));
  }
}
