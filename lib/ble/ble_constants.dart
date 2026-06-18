// Shared timeouts and delays for BLE connection, scan, and retry flows.

const bleInitialConnectMaxAttempts = 5;
const bleMaxReconnectionAttempts = 10;

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 4);
const bleScanTimeout = Duration(seconds: 10);
const blePostDisconnectSettleDelay = Duration(milliseconds: 800);
const bleLinkOnlyDisconnectSettleDelay = Duration(milliseconds: 300);
const bleReconnectPrescanDuration = Duration(seconds: 5);
// A connected senseBox streams continuously. If no characteristic data arrives
// for this long the link is treated as lost, since flutter_reactive_ble does
// not reliably surface an unexpected peripheral power-off on Android.
const bleDataStaleTimeout = Duration(seconds: 6);
