import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  SettingsBloc()
      : super(const SettingsState(
          vibrateOnDisconnect: false,
          privacyZones: <String>[],
          directUploadMode: false,
        )) {
    _loadSettings();
  }

  SettingsBloc.withState(super.initialState);

  factory SettingsBloc.createForTest() {
    return SettingsBloc.withState(
      const SettingsState(
        vibrateOnDisconnect: false,
        privacyZones: <String>[],
        directUploadMode: false,
      ),
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
    final prefs = await SharedPreferences.getInstance();
    if (isClosed) return;
    emit(
      state.copyWith(
        vibrateOnDisconnect: prefs.getBool('vibrateOnDisconnect') ?? false,
        privacyZones: prefs.getStringList('privacyZones') ?? <String>[],
        directUploadMode: prefs.getBool('directUploadMode') ?? false,
      ),
    );
  }

  Future<void> toggleVibrateOnDisconnect(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('vibrateOnDisconnect', value);
    if (isClosed) return;
    emit(state.copyWith(vibrateOnDisconnect: value));
  }

  Future<void> setPrivacyZones(List<String> zones) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('privacyZones', zones);
    if (isClosed) return;
    emit(state.copyWith(privacyZones: zones));
  }

  Future<void> toggleDirectUploadMode(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('directUploadMode', value);
    if (isClosed) return;
    emit(state.copyWith(directUploadMode: value));
  }

  void dispose() {
    close();
  }

  static bool _sameList(List<String> a, List<String> b) => listEquals(a, b);
}
