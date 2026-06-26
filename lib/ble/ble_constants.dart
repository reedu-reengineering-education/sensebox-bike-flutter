const bleInitialConnectMaxAttempts = 5;
const bleMaxReconnectionAttempts = 10;

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 4);
const bleScanTimeout = Duration(seconds: 10);
const blePostDisconnectSettleDelay = Duration(milliseconds: 800);
const bleLinkOnlyDisconnectSettleDelay = Duration(milliseconds: 300);
const bleDataStaleTimeout = Duration(seconds: 6);
