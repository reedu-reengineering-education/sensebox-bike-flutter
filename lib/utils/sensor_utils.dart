String? getTitleFromSensorKey(String key, String? attribute) {
  String searchKey = key;
  if (attribute != null) {
    searchKey = '${key}_${attribute.replaceAll(".", "_")}';
  }

  switch (searchKey) {
    case 'temperature':
      return 'Temperature';
    case 'humidity':
      return 'Rel. Humidity';
    case 'finedust_pm10':
      return 'Finedust PM10';
    case 'finedust_pm4':
      return 'Finedust PM4';
    case 'finedust_pm2_5':
      return 'Finedust PM2.5';
    case 'finedust_pm1':
      return 'Finedust PM1';
    case 'distance':
      return 'Overtaking Distance';
    case 'overtaking':
      return 'Overtaking Manoeuvre';
    case 'surface_classification_asphalt':
      return 'Surface Asphalt';
    case 'surface_classification_sett':
      return 'Surface Sett';
    case 'surface_classification_compacted':
      return 'Surface Compacted';
    case 'surface_classification_paved':
      return 'Surface Paving';
    case 'surface_classification_standing':
      return 'Standing';
    case 'surface_anomaly':
      return 'Surface Anomaly';
    case 'speed':
      return 'Speed';
    default:
      return null;
  }
}
