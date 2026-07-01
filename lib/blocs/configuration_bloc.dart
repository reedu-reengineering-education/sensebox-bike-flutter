import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/models/sensebox.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/constants.dart';

@immutable
class ConfigurationState {
  const ConfigurationState({
    required this.boxConfigurations,
    required this.campaigns,
    required this.apiUrls,
    required this.isLoadingBoxConfigurations,
    required this.isLoadingCampaigns,
    required this.isLoadingApiUrls,
    required this.boxConfigurationsError,
    required this.campaignsError,
    required this.apiUrlsError,
    required this.allSensorTitles,
  });

  final List<BoxConfiguration>? boxConfigurations;
  final List<Campaign>? campaigns;
  final List<String>? apiUrls;
  final bool isLoadingBoxConfigurations;
  final bool isLoadingCampaigns;
  final bool isLoadingApiUrls;
  final String? boxConfigurationsError;
  final String? campaignsError;
  final String? apiUrlsError;
  final Set<String> allSensorTitles;

  ConfigurationState copyWith({
    List<BoxConfiguration>? boxConfigurations,
    List<Campaign>? campaigns,
    List<String>? apiUrls,
    bool? isLoadingBoxConfigurations,
    bool? isLoadingCampaigns,
    bool? isLoadingApiUrls,
    String? boxConfigurationsError,
    String? campaignsError,
    String? apiUrlsError,
    Set<String>? allSensorTitles,
  }) {
    return ConfigurationState(
      boxConfigurations: boxConfigurations ?? this.boxConfigurations,
      campaigns: campaigns ?? this.campaigns,
      apiUrls: apiUrls ?? this.apiUrls,
      isLoadingBoxConfigurations:
          isLoadingBoxConfigurations ?? this.isLoadingBoxConfigurations,
      isLoadingCampaigns: isLoadingCampaigns ?? this.isLoadingCampaigns,
      isLoadingApiUrls: isLoadingApiUrls ?? this.isLoadingApiUrls,
      boxConfigurationsError:
          boxConfigurationsError ?? this.boxConfigurationsError,
      campaignsError: campaignsError ?? this.campaignsError,
      apiUrlsError: apiUrlsError ?? this.apiUrlsError,
      allSensorTitles: allSensorTitles ?? this.allSensorTitles,
    );
  }
}

class ConfigurationBloc extends Cubit<ConfigurationState> {
  final RemoteDataService _remoteDataService;

  ConfigurationBloc({RemoteDataService? remoteDataService})
      : _remoteDataService = remoteDataService ?? RemoteDataService(),
        super(const ConfigurationState(
          boxConfigurations: null,
          campaigns: null,
          apiUrls: null,
          isLoadingBoxConfigurations: false,
          isLoadingCampaigns: false,
          isLoadingApiUrls: false,
          boxConfigurationsError: null,
          campaignsError: null,
          apiUrlsError: null,
          allSensorTitles: {},
        ));

  // Getters for backward compatibility with consumers
  List<BoxConfiguration>? get boxConfigurations => state.boxConfigurations;
  List<Campaign>? get campaigns => state.campaigns;
  List<String>? get apiUrls => state.apiUrls;
  bool get isLoadingBoxConfigurations => state.isLoadingBoxConfigurations;
  bool get isLoadingCampaigns => state.isLoadingCampaigns;
  bool get isLoadingApiUrls => state.isLoadingApiUrls;
  String? get boxConfigurationsError => state.boxConfigurationsError;
  String? get campaignsError => state.campaignsError;
  String? get apiUrlsError => state.apiUrlsError;

  Future<void> loadApiUrls() async {
    final result = await _loadData<List<String>>(
      url: apiUrlsUrl,
      isAlreadyLoading: () => state.isLoadingApiUrls,
      isAlreadyLoaded: () => state.apiUrls != null,
      onLoading: (isLoading) {
        emit(state.copyWith(isLoadingApiUrls: isLoading));
      },
      onError: (error) {
        emit(state.copyWith(apiUrlsError: error));
      },
      parseData: (data) => (data as List<dynamic>).cast<String>(),
    );
    emit(state.copyWith(apiUrls: result));
  }

  BoxConfiguration? getBoxConfigurationById(String id) {
    if (state.boxConfigurations == null) return null;
    for (final config in state.boxConfigurations!) {
      if (config.id == id) return config;
    }
    return null;
  }

  BoxConfiguration? getBoxConfigurationByGrouptag(List<String>? grouptags) {
    if (state.boxConfigurations == null ||
        grouptags == null ||
        grouptags.isEmpty) {
      return null;
    }
    for (final config in state.boxConfigurations!) {
      if (grouptags.contains(config.defaultGrouptag)) {
        return config;
      }
    }
    return null;
  }

  Future<T?> _loadData<T>({
    required String url,
    required bool Function() isAlreadyLoading,
    required bool Function() isAlreadyLoaded,
    required void Function(bool) onLoading,
    required void Function(String?) onError,
    required T Function(dynamic) parseData,
    bool allowReload = false,
  }) async {
    if (isAlreadyLoading() || (!allowReload && isAlreadyLoaded())) {
      return null;
    }

    onLoading(true);
    onError(null);

    try {
      final dynamic data = await _remoteDataService.fetchJson(url);
      if (data is List) {
        final parsed = parseData(data);
        onError(null);
        return parsed;
      } else {
        throw Exception('Invalid data format: Expected List');
      }
    } catch (e) {
      onError('Failed to load data: $e');
      return null;
    } finally {
      onLoading(false);
    }
  }

  Future<void> loadBoxConfigurations() async {
    final result = await _loadData<List<BoxConfiguration>>(
      url: boxConfigurationsUrl,
      isAlreadyLoading: () => state.isLoadingBoxConfigurations,
      isAlreadyLoaded: () => state.boxConfigurations != null,
      onLoading: (isLoading) {
        emit(state.copyWith(isLoadingBoxConfigurations: isLoading));
      },
      onError: (error) {
        emit(state.copyWith(
          boxConfigurationsError: error,
          allSensorTitles: error != null ? {} : state.allSensorTitles,
        ));
      },
      parseData: (data) => (data as List)
          .map(
              (item) => BoxConfiguration.fromJson(item as Map<String, dynamic>))
          .toList(),
      allowReload: true,
    );
    final newTitles =
        result != null ? _calculateAllSensorTitles(result) : <String>{};
    emit(state.copyWith(
      boxConfigurations: result,
      allSensorTitles: newTitles,
    ));
  }

  Future<void> loadCampaigns() async {
    final result = await _loadData<List<Campaign>>(
      url: campaignsUrl,
      isAlreadyLoading: () => state.isLoadingCampaigns,
      isAlreadyLoaded: () => state.campaigns != null,
      onLoading: (isLoading) {
        emit(state.copyWith(isLoadingCampaigns: isLoading));
      },
      onError: (error) {
        emit(state.copyWith(campaignsError: error));
      },
      parseData: (data) => (data as List)
          .map((item) => Campaign.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    emit(state.copyWith(campaigns: result));
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadBoxConfigurations(),
      loadCampaigns(),
      loadApiUrls(),
    ]);
  }

  Set<String> _calculateAllSensorTitles(List<BoxConfiguration> configs) {
    if (configs.isEmpty) {
      return {};
    }
    return configs
        .expand((config) => config.sensors.map((sensor) => sensor.title))
        .toSet();
  }

  bool isSenseBoxBikeCompatible(SenseBox sensebox) {
    if (state.allSensorTitles.isEmpty) {
      return false;
    }

    if (sensebox.sensors == null || sensebox.sensors!.isEmpty) {
      return false;
    }

    for (var sensor in sensebox.sensors!) {
      if (!state.allSensorTitles.contains(sensor.title)) {
        return false;
      }
    }
    return true;
  }
}
