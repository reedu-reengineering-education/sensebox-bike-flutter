const openSenseMapUrl = 'https://api.opensensemap.org';
const Map<String, String> headers = {
  'Content-Type': 'application/json',
};

const classicModelSensors = [
      {
        "id": "0",
        "icon": 'osem-thermometer',
        "title": 'Temperature',
        "unit": '°C',
        "sensorType": 'HDC1080'
      },
      {
        "id": "1",
        "icon": 'osem-humidity',
        "title": 'Rel. Humidity',
        "unit": '%',
        "sensorType": 'HDC1080'
      },
      {
        "id": "2",
        "icon": 'osem-cloud',
        "title": 'Finedust PM1',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "3",
        "icon": 'osem-cloud',
        "title": 'Finedust PM2.5',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "4",
        "icon": 'osem-cloud',
        "title": 'Finedust PM4',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "5",
        "icon": 'osem-cloud',
        "title": 'Finedust PM10',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "6",
        "icon": 'osem-signal',
        "title": 'Overtaking Distance',
        "unit": 'cm',
        "sensorType": 'HC-SR04'
      },
      {
        "id": "7",
        "icon": 'osem-shock',
        "title": 'Acceleration X',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "8",
        "icon": 'osem-shock',
        "title": 'Acceleration Y',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "9",
        "icon": 'osem-shock',
        "title": 'Acceleration Z',
        "unit": 'm/s²',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "10",
        "icon": 'osem-dashboard',
        "title": 'Speed',
        "unit": 'km/h',
        "sensorType": 'GPS'
      }
    ];

    const atraiModelSensors = [
      {
        "id": "0",
        "icon": 'osem-thermometer',
        "title": 'Temperature',
        "unit": '°C',
        "sensorType": 'HDC1080'
      },
      {
        "id": "1",
        "icon": 'osem-humidity',
        "title": 'Rel. Humidity',
        "unit": '%',
        "sensorType": 'HDC1080'
      },
      {
        "id": "2",
        "icon": 'osem-cloud',
        "title": 'Finedust PM1',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "3",
        "icon": 'osem-cloud',
        "title": 'Finedust PM2.5',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "4",
        "icon": 'osem-cloud',
        "title": 'Finedust PM4',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "5",
        "icon": 'osem-cloud',
        "title": 'Finedust PM10',
        "unit": 'µg/m³',
        "sensorType": 'SPS30'
      },
      {
        "id": "6",
        "icon": 'osem-shock',
        "title": 'Overtaking Manoeuvre',
        "unit": '%',
        "sensorType": 'VL53L8CX'
      },
      {
        "id": "7",
        "icon": 'osem-shock',
        "title": 'Overtaking Distance',
        "unit": 'cm',
        "sensorType": 'VL53L8CX'
      },
      {
        "id": "8",
        "icon": 'osem-shock',
        "title": 'Surface Asphalt',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "9",
        "icon": 'osem-shock',
        "title": 'Surface Sett',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "10",
        "icon": 'osem-shock',
        "title": 'Surface Compacted',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "11",
        "icon": 'osem-shock',
        "title": 'Surface Paving',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "12",
        "icon": 'osem-shock',
        "title": 'Standing',
        "unit": '%',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "13",
        "icon": 'osem-shock',
        "title": 'Surface Anomaly',
        "unit": 'Δ',
        "sensorType": 'MPU-6050'
      },
      {
        "id": "14",
        "icon": 'osem-dashboard',
        "title": 'Speed',
        "unit": 'm/s',
        "sensorType": 'GPS'
      }
    ];
