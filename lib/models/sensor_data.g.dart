// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'sensor_data.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetSensorDataCollection on Isar {
  IsarCollection<SensorData> get sensorDatas => this.collection();
}

const SensorDataSchema = CollectionSchema(
  name: r'SensorData',
  id: -4425084427627382434,
  properties: {
    r'characteristicUuid': PropertySchema(
      id: 0,
      name: r'characteristicUuid',
      type: IsarType.string,
    ),
    r'value': PropertySchema(
      id: 1,
      name: r'value',
      type: IsarType.double,
    )
  },
  estimateSize: _sensorDataEstimateSize,
  serialize: _sensorDataSerialize,
  deserialize: _sensorDataDeserialize,
  deserializeProp: _sensorDataDeserializeProp,
  idName: r'id',
  indexes: {},
  links: {
    r'geolocationData': LinkSchema(
      id: -1649479526683294081,
      name: r'geolocationData',
      target: r'GeolocationData',
      single: true,
    )
  },
  embeddedSchemas: {},
  getId: _sensorDataGetId,
  getLinks: _sensorDataGetLinks,
  attach: _sensorDataAttach,
  version: '3.1.0+1',
);

int _sensorDataEstimateSize(
  SensorData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  bytesCount += 3 + object.characteristicUuid.length * 3;
  return bytesCount;
}

void _sensorDataSerialize(
  SensorData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeString(offsets[0], object.characteristicUuid);
  writer.writeDouble(offsets[1], object.value);
}

SensorData _sensorDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = SensorData();
  object.characteristicUuid = reader.readString(offsets[0]);
  object.id = id;
  object.value = reader.readDouble(offsets[1]);
  return object;
}

P _sensorDataDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readString(offset)) as P;
    case 1:
      return (reader.readDouble(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _sensorDataGetId(SensorData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _sensorDataGetLinks(SensorData object) {
  return [object.geolocationData];
}

void _sensorDataAttach(IsarCollection<dynamic> col, Id id, SensorData object) {
  object.id = id;
  object.geolocationData.attach(
      col, col.isar.collection<GeolocationData>(), r'geolocationData', id);
}

extension SensorDataQueryWhereSort
    on QueryBuilder<SensorData, SensorData, QWhere> {
  QueryBuilder<SensorData, SensorData, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }
}

extension SensorDataQueryWhere
    on QueryBuilder<SensorData, SensorData, QWhereClause> {
  QueryBuilder<SensorData, SensorData, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterWhereClause> idNotEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            )
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            );
      } else {
        return query
            .addWhereClause(
              IdWhereClause.greaterThan(lower: id, includeLower: false),
            )
            .addWhereClause(
              IdWhereClause.lessThan(upper: id, includeUpper: false),
            );
      }
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterWhereClause> idBetween(
    Id lowerId,
    Id upperId, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: lowerId,
        includeLower: includeLower,
        upper: upperId,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension SensorDataQueryFilter
    on QueryBuilder<SensorData, SensorData, QFilterCondition> {
  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidEqualTo(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidGreaterThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidLessThan(
    String value, {
    bool include = false,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidBetween(
    String lower,
    String upper, {
    bool includeLower = true,
    bool includeUpper = true,
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'characteristicUuid',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidStartsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.startsWith(
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidEndsWith(
    String value, {
    bool caseSensitive = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.endsWith(
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidContains(String value, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.contains(
        property: r'characteristicUuid',
        value: value,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidMatches(String pattern, {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.matches(
        property: r'characteristicUuid',
        wildcard: pattern,
        caseSensitive: caseSensitive,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'characteristicUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      characteristicUuidIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        property: r'characteristicUuid',
        value: '',
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> idGreaterThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> idLessThan(
    Id value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> idBetween(
    Id lower,
    Id upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'id',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> valueEqualTo(
    double value, {
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'value',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> valueGreaterThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'value',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> valueLessThan(
    double value, {
    bool include = false,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'value',
        value: value,
        epsilon: epsilon,
      ));
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> valueBetween(
    double lower,
    double upper, {
    bool includeLower = true,
    bool includeUpper = true,
    double epsilon = Query.epsilon,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'value',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
        epsilon: epsilon,
      ));
    });
  }
}

extension SensorDataQueryObject
    on QueryBuilder<SensorData, SensorData, QFilterCondition> {}

extension SensorDataQueryLinks
    on QueryBuilder<SensorData, SensorData, QFilterCondition> {
  QueryBuilder<SensorData, SensorData, QAfterFilterCondition> geolocationData(
      FilterQuery<GeolocationData> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'geolocationData');
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterFilterCondition>
      geolocationDataIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocationData', 0, true, 0, true);
    });
  }
}

extension SensorDataQuerySortBy
    on QueryBuilder<SensorData, SensorData, QSortBy> {
  QueryBuilder<SensorData, SensorData, QAfterSortBy>
      sortByCharacteristicUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characteristicUuid', Sort.asc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy>
      sortByCharacteristicUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characteristicUuid', Sort.desc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> sortByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> sortByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension SensorDataQuerySortThenBy
    on QueryBuilder<SensorData, SensorData, QSortThenBy> {
  QueryBuilder<SensorData, SensorData, QAfterSortBy>
      thenByCharacteristicUuid() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characteristicUuid', Sort.asc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy>
      thenByCharacteristicUuidDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'characteristicUuid', Sort.desc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> thenByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.asc);
    });
  }

  QueryBuilder<SensorData, SensorData, QAfterSortBy> thenByValueDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'value', Sort.desc);
    });
  }
}

extension SensorDataQueryWhereDistinct
    on QueryBuilder<SensorData, SensorData, QDistinct> {
  QueryBuilder<SensorData, SensorData, QDistinct> distinctByCharacteristicUuid(
      {bool caseSensitive = true}) {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'characteristicUuid',
          caseSensitive: caseSensitive);
    });
  }

  QueryBuilder<SensorData, SensorData, QDistinct> distinctByValue() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'value');
    });
  }
}

extension SensorDataQueryProperty
    on QueryBuilder<SensorData, SensorData, QQueryProperty> {
  QueryBuilder<SensorData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<SensorData, String, QQueryOperations>
      characteristicUuidProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'characteristicUuid');
    });
  }

  QueryBuilder<SensorData, double, QQueryOperations> valueProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'value');
    });
  }
}
