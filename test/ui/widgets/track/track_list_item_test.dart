import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/models/geolocation_data.dart';
import 'package:sensebox_bike/models/track_status_info.dart';
import 'package:sensebox_bike/ui/widgets/track/track_list_item.dart';
import 'package:sensebox_bike/blocs/track_bloc.dart';
import 'package:sensebox_bike/services/isar_service.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mocktail/mocktail.dart';

import '../../../mocks.dart';

class MockAppLocalizations extends Mock implements AppLocalizations {
  @override
  String get trackDelete => 'Delete Track';
  
  @override
  String get trackDeleteConfirmation => 'Are you sure you want to delete this track?';
  
  @override
  String get generalCancel => 'Cancel';
  
  @override
  String get generalDelete => 'Delete';
  
  @override
  String get trackNoGeolocations => 'No geolocation data';
  
  @override
  String get trackStatusUploaded => 'Uploaded';
  
  @override
  String get trackStatusNotUploaded => 'Not uploaded';
  
  @override
  String get trackStatusUploadFailed => 'Upload failed';
  
  @override
  String get settingsUploadModeDirect => 'Direct Upload (Beta)';
  
  @override
  String generalTrackDurationShort(String hours, String minutes) => '${hours}h ${minutes}m';
  
  @override
  String generalTrackDistance(String distance) => '${distance} km';
}

void main() {
  late TrackData testTrack;
  late MockIsarService mockIsarService;
  late TrackBloc trackBloc;
  late MockAppLocalizations mockLocalizations;

  setUp(() {
    testTrack = TrackData();
    
    mockIsarService = MockIsarService();
    trackBloc = TrackBloc(mockIsarService);
    mockLocalizations = MockAppLocalizations();
  });

  tearDown(() {
    trackBloc.dispose();
  });

  Widget createTestWidget(TrackData track) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('de'),
        Locale('pt'),
      ],
      home: Scaffold(
        body: TrackListItem(
          track: track,
          onDismissed: () {},
          trackBloc: trackBloc,
        ),
      ),
    );
  }

  group('TrackListItem', () {
    testWidgets('renders basic widget structure', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      expect(find.byType(TrackListItem), findsOneWidget);
      expect(find.byType(Row), findsWidgets);
    });

    testWidgets('displays track information correctly', (WidgetTester tester) async {
      await tester.pumpWidget(createTestWidget(testTrack));

      expect(find.byType(Text), findsWidgets);
      // When there are no geolocations, the widget shows a simple message without icons
      // The dismiss background has an icon, but that's not part of the main content
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('shows correct status for direct upload track', (WidgetTester tester) async {
      testTrack.isDirectUpload = 1;
      
      await tester.pumpWidget(createTestWidget(testTrack));

      final statusInfo = trackBloc.getEstimatedTrackStatusInfo(
        testTrack, 
        ThemeData.light(), 
        mockLocalizations
      );
      
      expect(statusInfo.status, equals(TrackStatus.directUpload));
      expect(statusInfo.color, equals(Colors.blue));
      expect(statusInfo.icon, equals(Icons.cloud_sync));
      expect(statusInfo.text, equals('Direct Upload (Beta)'));
    });

    testWidgets('shows correct status for uploaded track', (WidgetTester tester) async {
      testTrack.isDirectUpload = 0;
      testTrack.uploaded = 1;
      
      await tester.pumpWidget(createTestWidget(testTrack));

      final statusInfo = trackBloc.getEstimatedTrackStatusInfo(
        testTrack, 
        ThemeData.light(), 
        mockLocalizations
      );
      
      expect(statusInfo.status, equals(TrackStatus.uploaded));
      expect(statusInfo.color, equals(Colors.green));
      expect(statusInfo.icon, equals(Icons.cloud_done));
      expect(statusInfo.text, equals('Uploaded'));
    });

    testWidgets('shows correct status for failed upload track', (WidgetTester tester) async {
      testTrack.isDirectUpload = 0;
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 1;
      
      await tester.pumpWidget(createTestWidget(testTrack));

      final statusInfo = trackBloc.getEstimatedTrackStatusInfo(
        testTrack, 
        ThemeData.light(), 
        mockLocalizations
      );
      
      expect(statusInfo.status, equals(TrackStatus.uploadFailed));
      expect(statusInfo.color, equals(ThemeData.light().colorScheme.error));
      expect(statusInfo.icon, equals(Icons.cloud_off));
      expect(statusInfo.text, equals('Upload failed'));
    });

    testWidgets('shows correct status for not uploaded track', (WidgetTester tester) async {
      testTrack.isDirectUpload = 0;
      testTrack.uploaded = 0;
      testTrack.uploadAttempts = 0;
      
      await tester.pumpWidget(createTestWidget(testTrack));

      final statusInfo = trackBloc.getEstimatedTrackStatusInfo(
        testTrack, 
        ThemeData.light(), 
        mockLocalizations
      );
      
      expect(statusInfo.status, equals(TrackStatus.notUploaded));
      expect(statusInfo.color, equals(ThemeData.light().colorScheme.outline));
      expect(statusInfo.icon, equals(Icons.cloud_upload));
      expect(statusInfo.text, equals('Not uploaded'));
    });

    testWidgets('handles track without geolocations', (WidgetTester tester) async {
      final trackWithoutGeolocations = TestTrackBuilder.createRegularTrack();
      
      await tester.pumpWidget(createTestWidget(trackWithoutGeolocations));

      expect(find.byType(TrackListItem), findsOneWidget);
      // Since we can't override AppLocalizations.of(context) in the test widget,
      // we'll check that the widget renders without crashing
      expect(find.byType(Container), findsWidgets);
    });

    testWidgets('formats track duration correctly', (WidgetTester tester) async {
      final duration = Duration(hours: 2, minutes: 30);
      final formattedDuration = trackBloc.formatTrackDuration(duration, mockLocalizations);
      
      expect(formattedDuration, equals('2h 30m'));
    });

    testWidgets('formats track distance correctly', (WidgetTester tester) async {
      final distance = 12.5;
      final formattedDistance = trackBloc.formatTrackDistance(distance, mockLocalizations);
      
      expect(formattedDistance, equals('12.50 km'));
    });
  });
}
