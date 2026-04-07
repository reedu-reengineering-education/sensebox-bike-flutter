import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/services/storage/settings_storage.dart';

@immutable
class SettingsState {
  const SettingsState({
    required this.vibrateOnDisconnect,
    required this.privacyZones,
    required this.directUploadMode,
  });

  final bool vibrateOnDisconnect;
  final List<String> privacyZones;
  final bool directUploadMode;

  SettingsState copyWith({
    bool? vibrateOnDisconnect,
    List<String>? privacyZones,
    bool? directUploadMode,
  }) {
    return SettingsState(
      vibrateOnDisconnect: vibrateOnDisconnect ?? this.vibrateOnDisconnect,
      privacyZones: privacyZones ?? this.privacyZones,
      directUploadMode: directUploadMode ?? this.directUploadMode,
    );
  }
}

class SettingsBloc extends Cubit<SettingsState> {
  SettingsBloc({required SettingsStorage storage})
      : _storage = storage,
        super(const SettingsState(
          vibrateOnDisconnect: false,
          privacyZones: <String>[],
          directUploadMode: false,
        )) {
    _loadSettings();
  }

  SettingsBloc.withState(
    super.initialState, {
    required SettingsStorage storage,
  }) : _storage = storage;

  final SettingsStorage _storage;

  factory SettingsBloc.createForTest() {
    return SettingsBloc.withState(
      const SettingsState(
        vibrateOnDisconnect: false,
        privacyZones: <String>[],
        directUploadMode: false,
      ),
      storage: InMemorySettingsStorage(),
    );
  }

  bool get vibrateOnDisconnect => state.vibrateOnDisconnect;
  List<String> get privacyZones => state.privacyZones;
  bool get directUploadMode => state.directUploadMode;

  Stream<bool> get vibrateOnDisconnectStream =>
      stream.map((state) => state.vibrateOnDisconnect).distinct();

  Stream<List<String>> get privacyZonesStream =>
      stream.map((state) => state.privacyZones).distinct(_sameList);

  Stream<bool> get directUploadModeStream =>
      stream.map((state) => state.directUploadMode).distinct();

  Future<void> _loadSettings() async {
    final loaded = await _storage.load();
    if (isClosed) return;
    emit(
      state.copyWith(
        vibrateOnDisconnect: loaded.vibrateOnDisconnect,
        privacyZones: loaded.privacyZones,
        directUploadMode: loaded.directUploadMode,
      ),
    );
  }

  Future<void> toggleVibrateOnDisconnect(bool value) async {
    await _storage.setVibrateOnDisconnect(value);
    if (isClosed) return;
    emit(state.copyWith(vibrateOnDisconnect: value));
  }

  Future<void> setPrivacyZones(List<String> zones) async {
    await _storage.setPrivacyZones(zones);
    if (isClosed) return;
    emit(state.copyWith(privacyZones: zones));
  }

  Future<void> toggleDirectUploadMode(bool value) async {
    await _storage.setDirectUploadMode(value);
    if (isClosed) return;
    emit(state.copyWith(directUploadMode: value));
  }

  void dispose() {
    close();
  }

  static bool _sameList(List<String> a, List<String> b) => listEquals(a, b);
}
