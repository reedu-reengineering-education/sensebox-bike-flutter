import 'package:flutter/material.dart';
import 'package:sensebox_bike/models/box_configuration.dart';
import 'package:sensebox_bike/models/campaign.dart';
import 'package:sensebox_bike/services/remote_data_service.dart';
import 'package:sensebox_bike/constants.dart';

class ConfigurationBloc with ChangeNotifier {
  final RemoteDataService _remoteDataService;

  List<BoxConfiguration>? _boxConfigurations;
  List<Campaign>? _campaigns;
  bool _isLoadingBoxConfigurations = false;
  bool _isLoadingCampaigns = false;
  String? _boxConfigurationsError;
  String? _campaignsError;

  ConfigurationBloc({RemoteDataService? remoteDataService})
      : _remoteDataService = remoteDataService ?? RemoteDataService();

  List<BoxConfiguration>? get boxConfigurations => _boxConfigurations;
  List<Campaign>? get campaigns => _campaigns;
  bool get isLoadingBoxConfigurations => _isLoadingBoxConfigurations;
  bool get isLoadingCampaigns => _isLoadingCampaigns;
  String? get boxConfigurationsError => _boxConfigurationsError;
  String? get campaignsError => _campaignsError;

  BoxConfiguration? getBoxConfigurationById(String id) {
    if (_boxConfigurations == null) return null;
    try {
      return _boxConfigurations!.firstWhere((config) => config.id == id);
    } catch (e) {
      return null;
    }
  }

  Future<void> _loadData({
    required String url,
    required bool Function() isAlreadyLoading,
    required bool Function() isAlreadyLoaded,
    required void Function(bool) setLoading,
    required void Function(String?) setError,
    required void Function(dynamic) setData,
    required dynamic Function(dynamic) parseData,
    required String dataTypeName,
  }) async {
    if (isAlreadyLoading() || isAlreadyLoaded()) {
      return;
    }

    setLoading(true);
    setError(null);
    notifyListeners();

    try {
      final dynamic data = await _remoteDataService.fetchJson(url);
      if (data is List) {
        final parsed = parseData(data);
        setData(parsed);
        setError(null);
      } else {
        throw Exception('Invalid $dataTypeName format: Expected List');
      }
    } catch (e) {
      setError('Failed to load $dataTypeName: $e');
      setData(null);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> loadBoxConfigurations() async {
    await _loadData(
      url: boxConfigurationsUrl,
      isAlreadyLoading: () => _isLoadingBoxConfigurations,
      isAlreadyLoaded: () => _boxConfigurations != null,
      setLoading: (value) => _isLoadingBoxConfigurations = value,
      setError: (error) => _boxConfigurationsError = error,
      setData: (data) => _boxConfigurations = data as List<BoxConfiguration>?,
      parseData: (data) => (data as List)
          .map((item) =>
              BoxConfiguration.fromJson(item as Map<String, dynamic>))
          .toList(),
      dataTypeName: 'box configurations',
    );
  }

  Future<void> loadCampaigns() async {
    await _loadData(
      url: campaignsUrl,
      isAlreadyLoading: () => _isLoadingCampaigns,
      isAlreadyLoaded: () => _campaigns != null,
      setLoading: (value) => _isLoadingCampaigns = value,
      setError: (error) => _campaignsError = error,
      setData: (data) => _campaigns = data as List<Campaign>?,
      parseData: (data) => (data as List)
          .map((item) => Campaign.fromJson(item as Map<String, dynamic>))
          .toList(),
      dataTypeName: 'campaigns',
    );
  }

  Future<void> loadAll() async {
    await Future.wait([
      loadBoxConfigurations(),
      loadCampaigns(),
    ]);
  }
}

