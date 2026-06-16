// Shared timeouts and delays for BLE connection, scan, and retry flows.

const bleInitialConnectMaxAttempts = 5;
const bleMaxReconnectionAttempts = 10;

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 4);
const bleScanTimeout = Duration(seconds: 10);
const blePostDisconnectSettleDelay = Duration(milliseconds: 800);
const bleNotificationDisableTimeout = Duration(seconds: 2);

/// How long the BLE stack scans for the advertising device before attempting a
/// reconnect. Prevents the Android stack from hanging on an out-of-range box.
const bleReconnectPrescanDuration = Duration(seconds: 5);
