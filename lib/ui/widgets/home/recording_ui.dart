import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/blocs/recording_bloc.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/batch_upload_service.dart';
import 'package:sensebox_bike/services/custom_exceptions.dart';
import 'package:sensebox_bike/services/error_service.dart';
import 'package:sensebox_bike/ui/widgets/common/upload_progress_modal.dart';
import 'package:sensebox_bike/ui/widgets/home/ble_connection_dialogs.dart';

Future<void> showBatchUploadAfterRecording({
  required BuildContext context,
  required TrackData track,
  required SenseBox? senseBox,
  required BatchUploadService batchUploadService,
  required OpenSenseMapBloc openSenseMapBloc,
  required VoidCallback onFinished,
}) async {
  if (!context.mounted) {
    batchUploadService.dispose();
    onFinished();
    return;
  }

  final canUpload =
      senseBox != null && openSenseMapBloc.hasAuthAndSelectedSenseBox;

  try {
    await track.geolocations.load();
    if (track.geolocations.isEmpty) {
      throw TrackHasNoGeolocationsException(track.id);
    }

    UploadProgressOverlay.show(
      context,
      batchUploadService: batchUploadService,
      canUpload: canUpload,
      isAuthenticated: openSenseMapBloc.isAuthenticated,
      hasSelectedBox: openSenseMapBloc.selectedSenseBox != null,
      onUploadComplete: () {
        batchUploadService.dispose();
        onFinished();
        debugPrint('[RecordingUi] Batch upload completed successfully');
      },
      onUploadFailed: () {
        batchUploadService.dispose();
        onFinished();
        debugPrint('[RecordingUi] Batch upload failed permanently');
      },
      onStartUpload: () {
        if (canUpload) {
          unawaited(_uploadTrack(track, senseBox!, batchUploadService));
        }
      },
    );
  } catch (e, stack) {
    debugPrint('[RecordingUi] Error showing upload modal: $e');
    ErrorService.handleError(e, stack);
    UploadProgressOverlay.hide();
    batchUploadService.dispose();
    onFinished();
  }
}

Future<void> _uploadTrack(
  TrackData track,
  SenseBox senseBox,
  BatchUploadService batchUploadService,
) async {
  try {
    await batchUploadService.uploadTrack(track, senseBox);
  } catch (e, stack) {
    ErrorService.handleError(
      'Batch upload failed after recording stop: $e',
      stack,
      sendToSentry: true,
    );
  }
}

void bindRecordingUiCallbacks(
  BuildContext context,
  OpenSenseMapBloc openSenseMapBloc,
  RecordingBloc recordingBloc,
) {
  recordingBloc.setUiCallbacks(
    onRecordingStoppedDueToBle: () =>
        showRecordingStoppedDueToBleDialog(context),
    onBatchUploadPrompt: ({
      required TrackData track,
      required SenseBox? senseBox,
      required BatchUploadService batchUploadService,
      required VoidCallback onFinished,
    }) =>
        showBatchUploadAfterRecording(
          context: context,
          track: track,
          senseBox: senseBox,
          batchUploadService: batchUploadService,
          openSenseMapBloc: openSenseMapBloc,
          onFinished: onFinished,
        ),
  );
}
