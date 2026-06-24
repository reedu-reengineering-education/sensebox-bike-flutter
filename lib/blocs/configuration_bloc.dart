import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/models/data_collection_mode.dart';
import 'package:sensebox_bike/models/sensor_catalog_entry.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/services/sensor_catalog_registry.dart';
import 'package:sensebox_bike/constants.dart';

Future<dynamic> _defaultLoadBundledJson(String assetPath) async {
  final jsonString = await rootBundle.loadString(assetPath);
  return json.decode(jsonString);
}

class ConfigurationBloc extends ChangeNotifier {
  final RemoteDataService _remoteDataService;
  final Future<dynamic> Function(String assetPath) _loadBundledJson;

  List<SensorCatalogEntry>? _sensorCatalog;
  List<BoxConfiguration>? _boxConfigurations;
  List<Campaign>? _campaigns;
  List<String>? _apiUrls;
  bool _isLoadingSensorCatalog = false;
  bool _isLoadingBoxConfigurations = false;
  bool _isLoadingCampaigns = false;
  bool _isLoadingApiUrls = false;
  String? _sensorCatalogError;
  String? _boxConfigurationsError;
  String? _campaignsError;
  String? _apiUrlsError;

  ConfigurationBloc({
    RemoteDataService? remoteDataService,
    Future<dynamic> Function(String assetPath)? loadBundledJson,
  })  : _remoteDataService = remoteDataService ?? RemoteDataService(),
        _loadBundledJson = loadBundledJson ?? _defaultLoadBundledJson;

  List<SensorCatalogEntry>? get sensorCatalog => _sensorCatalog;
  List<BoxConfiguration>? get boxConfigurations => _boxConfigurations;
  List<Campaign>? get campaigns => _campaigns;
  List<String>? get apiUrls => _apiUrls;
  bool get isLoadingSensorCatalog => _isLoadingSensorCatalog;
  bool get isLoadingBoxConfigurations => _isLoadingBoxConfigurations;
  bool get isLoadingCampaigns => _isLoadingCampaigns;
  bool get isLoadingApiUrls => _isLoadingApiUrls;
  String? get sensorCatalogError => _sensorCatalogError;
  String? get boxConfigurationsError => _boxConfigurationsError;
  String? get campaignsError => _campaignsError;
  String? get apiUrlsError => _apiUrlsError;

  Future<void> loadApiUrls() async {
    final result = await _loadData<List<String>>(
      url: apiUrlsUrl,
      isAlreadyLoading: () => _isLoadingApiUrls,
      isAlreadyLoaded: () => _apiUrls != null,
      setLoading: (value) {
        _isLoadingApiUrls = value;
        notifyListeners();
      },
      setError: (error) {
        _apiUrlsError = error;
        notifyListeners();
      },
      parseData: (data) => (data as List<dynamic>).cast<String>(),
    );
    _apiUrls = result;
    notifyListeners();
  }

  BoxConfiguration? getBoxConfigurationById(String id) {
    if (_boxConfigurations == null) return null;
    for (final config in _boxConfigurations!) {
      if (config.id == id) return config;
    }
    return null;
  }

  BoxConfiguration? getBoxConfigurationByGrouptag(List<String>? grouptags) {
    if (_boxConfigurations == null || grouptags == null || grouptags.isEmpty) {
      return null;
    }
    for (final config in _boxConfigurations!) {
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
    required void Function(bool) setLoading,
    required void Function(String?) setError,
    required T Function(dynamic) parseData,
    bool allowReload = false,
    String? assetPath,
  }) async {
    if (isAlreadyLoading() || (!allowReload && isAlreadyLoaded())) {
      return null;
    }

    setLoading(true);
    setError(null);

    T parseList(dynamic data) {
      if (data is List) {
        return parseData(data);
      }
      throw Exception('Invalid data format: Expected List');
    }

    try {
      final dynamic data = await _remoteDataService.fetchJson(url);
      final parsed = parseList(data);
      setError(null);
      return parsed;
    } catch (remoteError) {
      if (assetPath == null) {
        setError('Failed to load data: $remoteError');
        return null;
      }

      try {
        final dynamic data = await _loadBundledJson(assetPath);
        final parsed = parseList(data);
        setError(null);
        return parsed;
      } catch (assetError) {
        setError('Failed to load data: $remoteError');
        return null;
      }
    } finally {
      setLoading(false);
    }
  }

  Future<void> loadSensorCatalog() async {
    final result = await _loadData<List<SensorCatalogEntry>>(
      url: sensorsUrl,
      assetPath: sensorsAssetPath,
      isAlreadyLoading: () => _isLoadingSensorCatalog,
      isAlreadyLoaded: () => _sensorCatalog != null,
      setLoading: (value) => _isLoadingSensorCatalog = value,
      setError: (error) {
        _sensorCatalogError = error;
        if (error != null) {
          SensorCatalogRegistry.clear();
        }
      },
      parseData: (data) => (data as List)
          .map((item) =>
              SensorCatalogEntry.fromJson(item as Map<String, dynamic>))
          .toList(),
      allowReload: true,
    );
    _sensorCatalog = result;
    if (result != null) {
      SensorCatalogRegistry.setEntries(result);
    }
    notifyListeners();
  }

  Future<void> loadBoxConfigurations() async {
    if (_sensorCatalog == null) {
      await loadSensorCatalog();
    }

    final result = await _loadData<List<BoxConfiguration>>(
      url: boxConfigurationsUrl,
      assetPath: boxConfigurationsAssetPath,
      isAlreadyLoading: () => _isLoadingBoxConfigurations,
      isAlreadyLoaded: () => _boxConfigurations != null,
      setLoading: (value) => _isLoadingBoxConfigurations = value,
      setError: (error) => _boxConfigurationsError = error,
      parseData: (data) => (data as List)
          .map(
              (item) => BoxConfiguration.fromJson(item as Map<String, dynamic>))
          .toList(),
      allowReload: true,
    );
    _boxConfigurations =
        result != null ? _withAllSensorsConfiguration(result) : null;
    notifyListeners();
  }

  List<BoxConfiguration> _withAllSensorsConfiguration(
    List<BoxConfiguration> configs,
  ) {
    final profiles =
        configs.where((config) => config.id != 'all').toList(growable: false);
    final catalog = _sensorCatalog;
    if (catalog == null || catalog.isEmpty) {
      return profiles;
    }
    return [...profiles, _buildAllSensorsConfiguration(catalog)];
  }

  BoxConfiguration _buildAllSensorsConfiguration(
    List<SensorCatalogEntry> catalog,
  ) {
    final sensors = catalog.asMap().entries.map((entry) {
      return SensorDefinition.fromCatalog(
        catalogEntry: entry.value,
        titleOverride: entry.value.title,
        id: entry.key.toString(),
      );
    }).toList();

    return BoxConfiguration(
      id: 'all',
      displayName: 'All sensors',
      defaultGrouptag: 'all',
      dataCollectionMode: DataCollectionMode.periodic,
      collectionIntervalSeconds: defaultCollectionIntervalSeconds,
      sensors: sensors,
    );
  }

  Future<void> loadCampaigns() async {
    final result = await _loadData<List<Campaign>>(
      url: campaignsUrl,
      isAlreadyLoading: () => _isLoadingCampaigns,
      isAlreadyLoaded: () => _campaigns != null,
      setLoading: (value) => _isLoadingCampaigns = value,
      setError: (error) => _campaignsError = error,
      parseData: (data) => (data as List)
          .map((item) => Campaign.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
    _campaigns = result;
  }

  Future<void> loadAll() async {
    await loadSensorCatalog();
    await Future.wait([
      loadBoxConfigurations(),
      loadCampaigns(),
      loadApiUrls(),
    ]);
  }
}
