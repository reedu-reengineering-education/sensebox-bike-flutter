const bleConnectTimeLimit = Duration(minutes: 2);
const bleReconnectTimeLimit = Duration(minutes: 10);

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 8);
const bleScanTimeout = Duration(seconds: 10);

/// Bounded scan window for a silent auto-connect attempt to a remembered
/// device. Shorter than [bleScanTimeout] since the user isn't watching a
/// scanning UI — if the box isn't advertising within this window we give up
/// quietly rather than keeping the radio on.
const bleAutoConnectScanTimeout = Duration(seconds: 8);

const blePostDisconnectSettleDelay = Duration(milliseconds: 800);
const bleDataStaleTimeout = Duration(seconds: 15);
