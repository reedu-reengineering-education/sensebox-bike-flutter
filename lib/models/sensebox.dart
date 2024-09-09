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
        ? new CurrentLocation.fromJson(json['currentLocation'])
        : null;
    if (json['sensors'] != null) {
      sensors = <Sensor>[];
      json['sensors'].forEach((v) {
        sensors!.add(new Sensor.fromJson(v));
      });
    }
    lastMeasurementAt = json['lastMeasurementAt'];
    sId = json['_id'];
    if (json['loc'] != null) {
      loc = <Loc>[];
      json['loc'].forEach((v) {
        loc!.add(new Loc.fromJson(v));
      });
    }
    integrations = json['integrations'] != null
        ? new Integrations.fromJson(json['integrations'])
        : null;
    accessToken = json['access_token'];
    useAuth = json['useAuth'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['createdAt'] = this.createdAt;
    data['exposure'] = this.exposure;
    data['model'] = this.model;
    data['grouptag'] = this.grouptag;
    data['name'] = this.name;
    data['updatedAt'] = this.updatedAt;
    if (this.currentLocation != null) {
      data['currentLocation'] = this.currentLocation!.toJson();
    }
    if (this.sensors != null) {
      data['sensors'] = this.sensors!.map((v) => v.toJson()).toList();
    }
    data['lastMeasurementAt'] = this.lastMeasurementAt;
    data['_id'] = this.sId;
    if (this.loc != null) {
      data['loc'] = this.loc!.map((v) => v.toJson()).toList();
    }
    if (this.integrations != null) {
      data['integrations'] = this.integrations!.toJson();
    }
    data['access_token'] = this.accessToken;
    data['useAuth'] = this.useAuth;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['type'] = this.type;
    data['coordinates'] = this.coordinates;
    data['timestamp'] = this.timestamp;
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
        ? new LastMeasurement.fromJson(json['lastMeasurement'])
        : null;
    sensorType = json['sensorType'];
    title = json['title'];
    unit = json['unit'];
    updatedAt = json['updatedAt'];
    icon = json['icon'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['_id'] = this.id;
    data['createdAt'] = this.createdAt;
    if (this.lastMeasurement != null) {
      data['lastMeasurement'] = this.lastMeasurement!.toJson();
    }
    data['sensorType'] = this.sensorType;
    data['title'] = this.title;
    data['unit'] = this.unit;
    data['updatedAt'] = this.updatedAt;
    data['icon'] = this.icon;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['createdAt'] = this.createdAt;
    data['value'] = this.value;
    return data;
  }
}

class Loc {
  CurrentLocation? geometry;
  String? type;

  Loc({this.geometry, this.type});

  Loc.fromJson(Map<String, dynamic> json) {
    geometry = json['geometry'] != null
        ? new CurrentLocation.fromJson(json['geometry'])
        : null;
    type = json['type'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.geometry != null) {
      data['geometry'] = this.geometry!.toJson();
    }
    data['type'] = this.type;
    return data;
  }
}

class Integrations {
  Mqtt? mqtt;
  Ttn? ttn;

  Integrations({this.mqtt, this.ttn});

  Integrations.fromJson(Map<String, dynamic> json) {
    mqtt = json['mqtt'] != null ? new Mqtt.fromJson(json['mqtt']) : null;
    ttn = json['ttn'] != null ? new Ttn.fromJson(json['ttn']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.mqtt != null) {
      data['mqtt'] = this.mqtt!.toJson();
    }
    if (this.ttn != null) {
      data['ttn'] = this.ttn!.toJson();
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['enabled'] = this.enabled;
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
        decodeOptions!.add(new DecodeOptions.fromJson(v));
      });
    }
    profile = json['profile'];
    devId = json['dev_id'];
    appId = json['app_id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = new Map<String, dynamic>();
    if (this.decodeOptions != null) {
      data['decodeOptions'] =
          this.decodeOptions!.map((v) => v.toJson()).toList();
    }
    data['profile'] = this.profile;
    data['dev_id'] = this.devId;
    data['app_id'] = this.appId;
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
    final Map<String, dynamic> data = new Map<String, dynamic>();
    data['channel'] = this.channel;
    data['decoder'] = this.decoder;
    data['sensor_type'] = this.sensorType;
    data['sensor_title'] = this.sensorTitle;
    return data;
  }
}
