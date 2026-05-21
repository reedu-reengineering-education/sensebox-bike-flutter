import 'package:flutter/foundation.dart';

bool get isIosPlatform => defaultTargetPlatform == TargetPlatform.iOS;

bool get isAndroidPlatform => defaultTargetPlatform == TargetPlatform.android;

bool get requiresAlwaysLocationPermission => isIosPlatform;
