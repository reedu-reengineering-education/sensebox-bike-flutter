class SenseBox {
  String? createdAt;
  String? exposure;
  String? model;
  List<String>? grouptag;
  String? name;
  String? updatedAt;
  CurrentLocation? currentLocation;
  List<Sensor>? sensors;
  String? lastMeasurementAt;
  String? sId;
  List<Loc>? loc;
  Integrations? integrations;
  String? accessToken;
  bool? useAuth;

  get id => sId;

  SenseBox(
      {this.createdAt,
      this.exposure,
      this.model,
      this.grouptag,
      this.name,
      this.updatedAt,
      this.currentLocation,
      this.sensors,
      this.lastMeasurementAt,
      this.sId,
      this.loc,
      this.integrations,
      this.accessToken,
      this.useAuth});

  SenseBox.fromJson(Map<String, dynamic> json) {
    createdAt = json['createdAt'];
    exposure = json['exposure'];
    model = json['model'];
    grouptag = json['grouptag'].cast<String>();
    name = json['name'];
    updatedAt = json['updatedAt'];
    currentLocation = json['currentLocation'] != null
        ? CurrentLocation.fromJson(json['currentLocation'])
        : null;
    if (json['sensors'] != null) {
      sensors = <Sensor>[];
      json['sensors'].forEach((v) {
        sensors!.add(Sensor.fromJson(v));
      });
    }
    lastMeasurementAt = json['lastMeasurementAt'];
    sId = json['_id'];
    if (json['loc'] != null) {
      loc = <Loc>[];
      json['loc'].forEach((v) {
        loc!.add(Loc.fromJson(v));
      });
    }
    integrations = json['integrations'] != null
        ? Integrations.fromJson(json['integrations'])
        : null;
    accessToken = json['access_token'];
    useAuth = json['useAuth'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createdAt'] = createdAt;
    data['exposure'] = exposure;
    data['model'] = model;
    data['grouptag'] = grouptag;
    data['name'] = name;
    data['updatedAt'] = updatedAt;
    if (currentLocation != null) {
      data['currentLocation'] = currentLocation!.toJson();
    }
    if (sensors != null) {
      data['sensors'] = sensors!.map((v) => v.toJson()).toList();
    }
    data['lastMeasurementAt'] = lastMeasurementAt;
    data['_id'] = sId;
    if (loc != null) {
      data['loc'] = loc!.map((v) => v.toJson()).toList();
    }
    if (integrations != null) {
      data['integrations'] = integrations!.toJson();
    }
    data['access_token'] = accessToken;
    data['useAuth'] = useAuth;
    return data;
  }
}

class CurrentLocation {
  String? type;
  List<double>? coordinates;
  String? timestamp;

  CurrentLocation({this.type, this.coordinates, this.timestamp});

  CurrentLocation.fromJson(Map<String, dynamic> json) {
    type = json['type'];
    coordinates = json['coordinates'].cast<double>();
    timestamp = json['timestamp'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = Map<String, dynamic>();
    data['type'] = type;
    data['coordinates'] = coordinates;
    data['timestamp'] = timestamp;
    return data;
  }
}

class Sensor {
  String? id;
  String? createdAt;
  LastMeasurement? lastMeasurement;
  String? sensorType;
  String? title;
  String? unit;
  String? updatedAt;
  String? icon;

  Sensor(
      {this.id,
      this.createdAt,
      this.lastMeasurement,
      this.sensorType,
      this.title,
      this.unit,
      this.updatedAt,
      this.icon});

  Sensor.fromJson(Map<String, dynamic> json) {
    id = json['_id'];
    createdAt = json['createdAt'];
    lastMeasurement = json['lastMeasurement'] != null
        ? LastMeasurement.fromJson(json['lastMeasurement'])
        : null;
    sensorType = json['sensorType'];
    title = json['title'];
    unit = json['unit'];
    updatedAt = json['updatedAt'];
    icon = json['icon'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['createdAt'] = createdAt;
    if (lastMeasurement != null) {
      data['lastMeasurement'] = lastMeasurement!.toJson();
    }
    data['sensorType'] = sensorType;
    data['title'] = title;
    data['unit'] = unit;
    data['updatedAt'] = updatedAt;
    data['icon'] = icon;
    return data;
  }
}

class LastMeasurement {
  String? createdAt;
  String? value;

  LastMeasurement({this.createdAt, this.value});

  LastMeasurement.fromJson(Map<String, dynamic> json) {
    createdAt = json['createdAt'];
    value = json['value'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['createdAt'] = createdAt;
    data['value'] = value;
    return data;
  }
}

class Loc {
  CurrentLocation? geometry;
  String? type;

  Loc({this.geometry, this.type});

  Loc.fromJson(Map<String, dynamic> json) {
    geometry = json['geometry'] != null
        ? CurrentLocation.fromJson(json['geometry'])
        : null;
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (geometry != null) {
      data['geometry'] = geometry!.toJson();
    }
    data['type'] = type;
    return data;
  }
}

class Integrations {
  Mqtt? mqtt;
  Ttn? ttn;

  Integrations({this.mqtt, this.ttn});

  Integrations.fromJson(Map<String, dynamic> json) {
    mqtt = json['mqtt'] != null ? Mqtt.fromJson(json['mqtt']) : null;
    ttn = json['ttn'] != null ? Ttn.fromJson(json['ttn']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (mqtt != null) {
      data['mqtt'] = mqtt!.toJson();
    }
    if (ttn != null) {
      data['ttn'] = ttn!.toJson();
    }
    return data;
  }
}

class Mqtt {
  bool? enabled;

  Mqtt({this.enabled});

  Mqtt.fromJson(Map<String, dynamic> json) {
    enabled = json['enabled'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['enabled'] = enabled;
    return data;
  }
}

class Ttn {
  List<DecodeOptions>? decodeOptions;
  String? profile;
  String? devId;
  String? appId;

  Ttn({this.decodeOptions, this.profile, this.devId, this.appId});

  Ttn.fromJson(Map<String, dynamic> json) {
    if (json['decodeOptions'] != null) {
      decodeOptions = <DecodeOptions>[];
      json['decodeOptions'].forEach((v) {
        decodeOptions!.add(DecodeOptions.fromJson(v));
      });
    }
    profile = json['profile'];
    devId = json['dev_id'];
    appId = json['app_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    if (decodeOptions != null) {
      data['decodeOptions'] = decodeOptions!.map((v) => v.toJson()).toList();
    }
    data['profile'] = profile;
    data['dev_id'] = devId;
    data['app_id'] = appId;
    return data;
  }
}

class DecodeOptions {
  int? channel;
  String? decoder;
  String? sensorType;
  String? sensorTitle;

  DecodeOptions(
      {this.channel, this.decoder, this.sensorType, this.sensorTitle});

  DecodeOptions.fromJson(Map<String, dynamic> json) {
    channel = json['channel'];
    decoder = json['decoder'];
    sensorType = json['sensor_type'];
    sensorTitle = json['sensor_title'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['channel'] = channel;
    data['decoder'] = decoder;
    data['sensor_type'] = sensorType;
    data['sensor_title'] = sensorTitle;
    return data;
  }
}
