// Shared timeouts and delays for BLE connection, scan, and retry flows.

const bleInitialConnectMaxAttempts = 5;
const bleMaxReconnectionAttempts = 10;

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 4);
const bleScanTimeout = Duration(seconds: 10);
