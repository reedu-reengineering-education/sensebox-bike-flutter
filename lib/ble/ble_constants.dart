const bleConnectMaxAttempts = 10;

const bleDeviceConnectTimeout = Duration(seconds: 10);
const bleSessionRetryDelay = Duration(seconds: 1);
const bleConnectionSessionProbeTimeout = Duration(seconds: 4);
/// Second (and later) liveness waits on the same GATT link before tearing it
/// down. A booting box can be connected with a partial characteristic table and
/// no payloads yet; re-running establish on the held link picks up late chars.
const bleConnectionSessionExtendedProbeTimeout = Duration(seconds: 12);
const bleEstablishProbeAttemptsPerLink = 2;
const bleScanTimeout = Duration(seconds: 10);

/// How long to wait after the adapter reports "off" before tearing down a live
/// link. Android power-save/Doze can emit a transient `poweredOff` status even
/// though the radio (and the existing GATT link) is still alive; debouncing
/// avoids a self-inflicted disconnect on those spurious blips.
const bleAdapterOffDebounce = Duration(seconds: 2);

const blePostDisconnectSettleDelay = Duration(milliseconds: 800);
const bleLinkOnlyDisconnectSettleDelay = Duration(milliseconds: 300);
const bleDataStaleTimeout = Duration(seconds: 6);
