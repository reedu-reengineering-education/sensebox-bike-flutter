import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:sensebox_bike/models/track_data.dart';
import 'package:sensebox_bike/services/isar_service/isar_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> runIsarMigrations() async {
  final isar = await IsarProvider().getDatabase();

  final prefs = await SharedPreferences.getInstance();
  final currentVersion = prefs.getInt('isar_migration_version') ?? 1;

  switch (currentVersion) {
    case 1:
      debugPrint("Starting migration for version 1");
      await migrateTrackDirectUpload(isar);
      debugPrint("Migration for version 1 completed");
      // Update version
      await prefs.setInt('isar_migration_version', 2);
      break;
    case 2:
      // If the version is already 2, we do not need to migrate
      return;
    default:
      throw Exception('Unknown version: $currentVersion');
  }
}

Future<void> migrateTrackDirectUpload(Isar isar) async {
  final trackCount = await isar.trackDatas.count();

  debugPrint('Migrating $trackCount tracks to set isDirectUpload to true');

  // We paginate through the tracks to avoid loading all tracks into memory at once
  int batchSize = 20;
  for (var i = 0; i < trackCount; i += batchSize) {
    debugPrint(
        'Migrating tracks ${i + 1} to ${i + batchSize > trackCount ? trackCount : i + batchSize}');
    final tracks =
        await isar.trackDatas.where().offset(i).limit(batchSize).findAll();
    await isar.writeTxn(() async {
      for (final track in tracks) {
        track.isDirectUpload = true;
        await isar.trackDatas.put(track);
      }
    });
  }
}
