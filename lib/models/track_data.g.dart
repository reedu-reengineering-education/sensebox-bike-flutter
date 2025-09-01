// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'track_data.dart';

// **************************************************************************
// IsarCollectionGenerator
// **************************************************************************

// coverage:ignore-file
// ignore_for_file: duplicate_ignore, non_constant_identifier_names, constant_identifier_names, invalid_use_of_protected_member, unnecessary_cast, prefer_const_constructors, lines_longer_than_80_chars, require_trailing_commas, inference_failure_on_function_invocation, unnecessary_parenthesis, unnecessary_raw_strings, unnecessary_null_checks, join_return_with_assignment, prefer_final_locals, avoid_js_rounded_ints, avoid_positional_boolean_parameters, always_specify_types

extension GetTrackDataCollection on Isar {
  IsarCollection<TrackData> get trackDatas => this.collection();
}

const TrackDataSchema = CollectionSchema(
  name: r'TrackData',
  id: -595095596094647637,
  properties: {
    r'isDirectUpload': PropertySchema(
      id: 0,
      name: r'isDirectUpload',
      type: IsarType.long,
    ),
    r'lastUploadAttempt': PropertySchema(
      id: 1,
      name: r'lastUploadAttempt',
      type: IsarType.dateTime,
    ),
    r'uploadAttempts': PropertySchema(
      id: 2,
      name: r'uploadAttempts',
      type: IsarType.long,
    ),
    r'uploaded': PropertySchema(
      id: 3,
      name: r'uploaded',
      type: IsarType.long,
    )
  },
  estimateSize: _trackDataEstimateSize,
  serialize: _trackDataSerialize,
  deserialize: _trackDataDeserialize,
  deserializeProp: _trackDataDeserializeProp,
  idName: r'id',
  indexes: {
    r'isDirectUpload': IndexSchema(
      id: 2514252948223284489,
      name: r'isDirectUpload',
      unique: false,
      replace: false,
      properties: [
        IndexPropertySchema(
          name: r'isDirectUpload',
          type: IndexType.value,
          caseSensitive: false,
        )
      ],
    )
  },
  links: {
    r'geolocations': LinkSchema(
      id: 545730778271505761,
      name: r'geolocations',
      target: r'GeolocationData',
      single: false,
      linkName: r'track',
    )
  },
  embeddedSchemas: {},
  getId: _trackDataGetId,
  getLinks: _trackDataGetLinks,
  attach: _trackDataAttach,
  version: '3.1.8',
);

int _trackDataEstimateSize(
  TrackData object,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  var bytesCount = offsets.last;
  return bytesCount;
}

void _trackDataSerialize(
  TrackData object,
  IsarWriter writer,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  writer.writeLong(offsets[0], object.isDirectUpload);
  writer.writeDateTime(offsets[1], object.lastUploadAttempt);
  writer.writeLong(offsets[2], object.uploadAttempts);
  writer.writeLong(offsets[3], object.uploaded);
}

TrackData _trackDataDeserialize(
  Id id,
  IsarReader reader,
  List<int> offsets,
  Map<Type, List<int>> allOffsets,
) {
  final object = TrackData();
  object.id = id;
  object.isDirectUpload = reader.readLongOrNull(offsets[0]);
  object.lastUploadAttempt = reader.readDateTimeOrNull(offsets[1]);
  object.uploadAttempts = reader.readLongOrNull(offsets[2]);
  object.uploaded = reader.readLongOrNull(offsets[3]);
  return object;
}

P _trackDataDeserializeProp<P>(
  IsarReader reader,
  int propertyId,
  int offset,
  Map<Type, List<int>> allOffsets,
) {
  switch (propertyId) {
    case 0:
      return (reader.readLongOrNull(offset)) as P;
    case 1:
      return (reader.readDateTimeOrNull(offset)) as P;
    case 2:
      return (reader.readLongOrNull(offset)) as P;
    case 3:
      return (reader.readLongOrNull(offset)) as P;
    default:
      throw IsarError('Unknown property with id $propertyId');
  }
}

Id _trackDataGetId(TrackData object) {
  return object.id;
}

List<IsarLinkBase<dynamic>> _trackDataGetLinks(TrackData object) {
  return [object.geolocations];
}

void _trackDataAttach(IsarCollection<dynamic> col, Id id, TrackData object) {
  object.id = id;
  object.geolocations
      .attach(col, col.isar.collection<GeolocationData>(), r'geolocations', id);
}

extension TrackDataQueryWhereSort
    on QueryBuilder<TrackData, TrackData, QWhere> {
  QueryBuilder<TrackData, TrackData, QAfterWhere> anyId() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(const IdWhereClause.any());
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhere> anyIsDirectUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        const IndexWhereClause.any(indexName: r'isDirectUpload'),
      );
    });
  }
}

extension TrackDataQueryWhere
    on QueryBuilder<TrackData, TrackData, QWhereClause> {
  QueryBuilder<TrackData, TrackData, QAfterWhereClause> idEqualTo(Id id) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IdWhereClause.between(
        lower: id,
        upper: id,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> idNotEqualTo(Id id) {
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

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> idGreaterThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.greaterThan(lower: id, includeLower: include),
      );
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> idLessThan(Id id,
      {bool include = false}) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(
        IdWhereClause.lessThan(upper: id, includeUpper: include),
      );
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> idBetween(
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

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> isDirectUploadIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDirectUpload',
        value: [null],
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause>
      isDirectUploadIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'isDirectUpload',
        lower: [null],
        includeLower: false,
        upper: [],
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> isDirectUploadEqualTo(
      int? isDirectUpload) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.equalTo(
        indexName: r'isDirectUpload',
        value: [isDirectUpload],
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause>
      isDirectUploadNotEqualTo(int? isDirectUpload) {
    return QueryBuilder.apply(this, (query) {
      if (query.whereSort == Sort.asc) {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDirectUpload',
              lower: [],
              upper: [isDirectUpload],
              includeUpper: false,
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDirectUpload',
              lower: [isDirectUpload],
              includeLower: false,
              upper: [],
            ));
      } else {
        return query
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDirectUpload',
              lower: [isDirectUpload],
              includeLower: false,
              upper: [],
            ))
            .addWhereClause(IndexWhereClause.between(
              indexName: r'isDirectUpload',
              lower: [],
              upper: [isDirectUpload],
              includeUpper: false,
            ));
      }
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause>
      isDirectUploadGreaterThan(
    int? isDirectUpload, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'isDirectUpload',
        lower: [isDirectUpload],
        includeLower: include,
        upper: [],
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> isDirectUploadLessThan(
    int? isDirectUpload, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'isDirectUpload',
        lower: [],
        upper: [isDirectUpload],
        includeUpper: include,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterWhereClause> isDirectUploadBetween(
    int? lowerIsDirectUpload,
    int? upperIsDirectUpload, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addWhereClause(IndexWhereClause.between(
        indexName: r'isDirectUpload',
        lower: [lowerIsDirectUpload],
        includeLower: includeLower,
        upper: [upperIsDirectUpload],
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TrackDataQueryFilter
    on QueryBuilder<TrackData, TrackData, QFilterCondition> {
  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> idEqualTo(
      Id value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'id',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> idGreaterThan(
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

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> idLessThan(
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

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> idBetween(
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

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'isDirectUpload',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'isDirectUpload',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'isDirectUpload',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'isDirectUpload',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'isDirectUpload',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      isDirectUploadBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'isDirectUpload',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'lastUploadAttempt',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'lastUploadAttempt',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptEqualTo(DateTime? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'lastUploadAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptGreaterThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'lastUploadAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptLessThan(
    DateTime? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'lastUploadAttempt',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      lastUploadAttemptBetween(
    DateTime? lower,
    DateTime? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'lastUploadAttempt',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uploadAttempts',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uploadAttempts',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsEqualTo(int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uploadAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uploadAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uploadAttempts',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadAttemptsBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uploadAttempts',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> uploadedIsNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNull(
        property: r'uploaded',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      uploadedIsNotNull() {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(const FilterCondition.isNotNull(
        property: r'uploaded',
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> uploadedEqualTo(
      int? value) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.equalTo(
        property: r'uploaded',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> uploadedGreaterThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.greaterThan(
        include: include,
        property: r'uploaded',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> uploadedLessThan(
    int? value, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.lessThan(
        include: include,
        property: r'uploaded',
        value: value,
      ));
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> uploadedBetween(
    int? lower,
    int? upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.addFilterCondition(FilterCondition.between(
        property: r'uploaded',
        lower: lower,
        includeLower: includeLower,
        upper: upper,
        includeUpper: includeUpper,
      ));
    });
  }
}

extension TrackDataQueryObject
    on QueryBuilder<TrackData, TrackData, QFilterCondition> {}

extension TrackDataQueryLinks
    on QueryBuilder<TrackData, TrackData, QFilterCondition> {
  QueryBuilder<TrackData, TrackData, QAfterFilterCondition> geolocations(
      FilterQuery<GeolocationData> q) {
    return QueryBuilder.apply(this, (query) {
      return query.link(q, r'geolocations');
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsLengthEqualTo(int length) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocations', length, true, length, true);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsIsEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocations', 0, true, 0, true);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsIsNotEmpty() {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocations', 0, false, 999999, true);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsLengthLessThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocations', 0, true, length, include);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsLengthGreaterThan(
    int length, {
    bool include = false,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(r'geolocations', length, include, 999999, true);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterFilterCondition>
      geolocationsLengthBetween(
    int lower,
    int upper, {
    bool includeLower = true,
    bool includeUpper = true,
  }) {
    return QueryBuilder.apply(this, (query) {
      return query.linkLength(
          r'geolocations', lower, includeLower, upper, includeUpper);
    });
  }
}

extension TrackDataQuerySortBy on QueryBuilder<TrackData, TrackData, QSortBy> {
  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByIsDirectUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirectUpload', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByIsDirectUploadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirectUpload', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByLastUploadAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUploadAttempt', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy>
      sortByLastUploadAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUploadAttempt', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByUploadAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadAttempts', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByUploadAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadAttempts', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> sortByUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.desc);
    });
  }
}

extension TrackDataQuerySortThenBy
    on QueryBuilder<TrackData, TrackData, QSortThenBy> {
  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenById() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByIdDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'id', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByIsDirectUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirectUpload', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByIsDirectUploadDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'isDirectUpload', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByLastUploadAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUploadAttempt', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy>
      thenByLastUploadAttemptDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'lastUploadAttempt', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByUploadAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadAttempts', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByUploadAttemptsDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploadAttempts', Sort.desc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.asc);
    });
  }

  QueryBuilder<TrackData, TrackData, QAfterSortBy> thenByUploadedDesc() {
    return QueryBuilder.apply(this, (query) {
      return query.addSortBy(r'uploaded', Sort.desc);
    });
  }
}

extension TrackDataQueryWhereDistinct
    on QueryBuilder<TrackData, TrackData, QDistinct> {
  QueryBuilder<TrackData, TrackData, QDistinct> distinctByIsDirectUpload() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'isDirectUpload');
    });
  }

  QueryBuilder<TrackData, TrackData, QDistinct> distinctByLastUploadAttempt() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'lastUploadAttempt');
    });
  }

  QueryBuilder<TrackData, TrackData, QDistinct> distinctByUploadAttempts() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uploadAttempts');
    });
  }

  QueryBuilder<TrackData, TrackData, QDistinct> distinctByUploaded() {
    return QueryBuilder.apply(this, (query) {
      return query.addDistinctBy(r'uploaded');
    });
  }
}

extension TrackDataQueryProperty
    on QueryBuilder<TrackData, TrackData, QQueryProperty> {
  QueryBuilder<TrackData, int, QQueryOperations> idProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'id');
    });
  }

  QueryBuilder<TrackData, int?, QQueryOperations> isDirectUploadProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'isDirectUpload');
    });
  }

  QueryBuilder<TrackData, DateTime?, QQueryOperations>
      lastUploadAttemptProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'lastUploadAttempt');
    });
  }

  QueryBuilder<TrackData, int?, QQueryOperations> uploadAttemptsProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uploadAttempts');
    });
  }

  QueryBuilder<TrackData, int?, QQueryOperations> uploadedProperty() {
    return QueryBuilder.apply(this, (query) {
      return query.addPropertyName(r'uploaded');
    });
  }
}
