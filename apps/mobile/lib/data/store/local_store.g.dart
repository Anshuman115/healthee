// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_store.dart';

// ignore_for_file: type=lint
class $CachedPayloadsTable extends CachedPayloads
    with TableInfo<$CachedPayloadsTable, CachedPayload> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedPayloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dayMeta = const VerificationMeta('day');
  @override
  late final GeneratedColumn<String> day = GeneratedColumn<String>(
    'day',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 10,
      maxTextLength: 10,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _metricMeta = const VerificationMeta('metric');
  @override
  late final GeneratedColumn<String> metric = GeneratedColumn<String>(
    'metric',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 64,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fetchedAtMeta = const VerificationMeta(
    'fetchedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fetchedAt = GeneratedColumn<DateTime>(
    'fetched_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [day, metric, payload, fetchedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_payloads';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedPayload> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('day')) {
      context.handle(
        _dayMeta,
        day.isAcceptableOrUnknown(data['day']!, _dayMeta),
      );
    } else if (isInserting) {
      context.missing(_dayMeta);
    }
    if (data.containsKey('metric')) {
      context.handle(
        _metricMeta,
        metric.isAcceptableOrUnknown(data['metric']!, _metricMeta),
      );
    } else if (isInserting) {
      context.missing(_metricMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    } else if (isInserting) {
      context.missing(_payloadMeta);
    }
    if (data.containsKey('fetched_at')) {
      context.handle(
        _fetchedAtMeta,
        fetchedAt.isAcceptableOrUnknown(data['fetched_at']!, _fetchedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_fetchedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {day, metric};
  @override
  CachedPayload map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedPayload(
      day: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day'],
      )!,
      metric: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}metric'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      fetchedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}fetched_at'],
      )!,
    );
  }

  @override
  $CachedPayloadsTable createAlias(String alias) {
    return $CachedPayloadsTable(attachedDatabase, alias);
  }
}

class CachedPayload extends DataClass implements Insertable<CachedPayload> {
  /// The owner-local calendar date this payload describes, as `YYYY-MM-DD`.
  final String day;

  /// Which payload it is — `today`, `sleep`, `activity`, … (the endpoint's name).
  final String metric;

  /// The response body, verbatim, as JSON text.
  final String payload;

  /// When we received it. A genuine instant, so a DateTime is the right type
  /// here — and `storeDateTimeAsText` below keeps it in UTC across the round
  /// trip. It drives staleness display, never correctness.
  final DateTime fetchedAt;
  const CachedPayload({
    required this.day,
    required this.metric,
    required this.payload,
    required this.fetchedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['day'] = Variable<String>(day);
    map['metric'] = Variable<String>(metric);
    map['payload'] = Variable<String>(payload);
    map['fetched_at'] = Variable<DateTime>(fetchedAt);
    return map;
  }

  CachedPayloadsCompanion toCompanion(bool nullToAbsent) {
    return CachedPayloadsCompanion(
      day: Value(day),
      metric: Value(metric),
      payload: Value(payload),
      fetchedAt: Value(fetchedAt),
    );
  }

  factory CachedPayload.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedPayload(
      day: serializer.fromJson<String>(json['day']),
      metric: serializer.fromJson<String>(json['metric']),
      payload: serializer.fromJson<String>(json['payload']),
      fetchedAt: serializer.fromJson<DateTime>(json['fetchedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'day': serializer.toJson<String>(day),
      'metric': serializer.toJson<String>(metric),
      'payload': serializer.toJson<String>(payload),
      'fetchedAt': serializer.toJson<DateTime>(fetchedAt),
    };
  }

  CachedPayload copyWith({
    String? day,
    String? metric,
    String? payload,
    DateTime? fetchedAt,
  }) => CachedPayload(
    day: day ?? this.day,
    metric: metric ?? this.metric,
    payload: payload ?? this.payload,
    fetchedAt: fetchedAt ?? this.fetchedAt,
  );
  CachedPayload copyWithCompanion(CachedPayloadsCompanion data) {
    return CachedPayload(
      day: data.day.present ? data.day.value : this.day,
      metric: data.metric.present ? data.metric.value : this.metric,
      payload: data.payload.present ? data.payload.value : this.payload,
      fetchedAt: data.fetchedAt.present ? data.fetchedAt.value : this.fetchedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedPayload(')
          ..write('day: $day, ')
          ..write('metric: $metric, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(day, metric, payload, fetchedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedPayload &&
          other.day == this.day &&
          other.metric == this.metric &&
          other.payload == this.payload &&
          other.fetchedAt == this.fetchedAt);
}

class CachedPayloadsCompanion extends UpdateCompanion<CachedPayload> {
  final Value<String> day;
  final Value<String> metric;
  final Value<String> payload;
  final Value<DateTime> fetchedAt;
  final Value<int> rowid;
  const CachedPayloadsCompanion({
    this.day = const Value.absent(),
    this.metric = const Value.absent(),
    this.payload = const Value.absent(),
    this.fetchedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedPayloadsCompanion.insert({
    required String day,
    required String metric,
    required String payload,
    required DateTime fetchedAt,
    this.rowid = const Value.absent(),
  }) : day = Value(day),
       metric = Value(metric),
       payload = Value(payload),
       fetchedAt = Value(fetchedAt);
  static Insertable<CachedPayload> custom({
    Expression<String>? day,
    Expression<String>? metric,
    Expression<String>? payload,
    Expression<DateTime>? fetchedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (day != null) 'day': day,
      if (metric != null) 'metric': metric,
      if (payload != null) 'payload': payload,
      if (fetchedAt != null) 'fetched_at': fetchedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedPayloadsCompanion copyWith({
    Value<String>? day,
    Value<String>? metric,
    Value<String>? payload,
    Value<DateTime>? fetchedAt,
    Value<int>? rowid,
  }) {
    return CachedPayloadsCompanion(
      day: day ?? this.day,
      metric: metric ?? this.metric,
      payload: payload ?? this.payload,
      fetchedAt: fetchedAt ?? this.fetchedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (day.present) {
      map['day'] = Variable<String>(day.value);
    }
    if (metric.present) {
      map['metric'] = Variable<String>(metric.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (fetchedAt.present) {
      map['fetched_at'] = Variable<DateTime>(fetchedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedPayloadsCompanion(')
          ..write('day: $day, ')
          ..write('metric: $metric, ')
          ..write('payload: $payload, ')
          ..write('fetchedAt: $fetchedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$LocalStore extends GeneratedDatabase {
  _$LocalStore(QueryExecutor e) : super(e);
  $LocalStoreManager get managers => $LocalStoreManager(this);
  late final $CachedPayloadsTable cachedPayloads = $CachedPayloadsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [cachedPayloads];
}

typedef $$CachedPayloadsTableCreateCompanionBuilder =
    CachedPayloadsCompanion Function({
      required String day,
      required String metric,
      required String payload,
      required DateTime fetchedAt,
      Value<int> rowid,
    });
typedef $$CachedPayloadsTableUpdateCompanionBuilder =
    CachedPayloadsCompanion Function({
      Value<String> day,
      Value<String> metric,
      Value<String> payload,
      Value<DateTime> fetchedAt,
      Value<int> rowid,
    });

class $$CachedPayloadsTableFilterComposer
    extends Composer<_$LocalStore, $CachedPayloadsTable> {
  $$CachedPayloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get metric => $composableBuilder(
    column: $table.metric,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedPayloadsTableOrderingComposer
    extends Composer<_$LocalStore, $CachedPayloadsTable> {
  $$CachedPayloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get day => $composableBuilder(
    column: $table.day,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get metric => $composableBuilder(
    column: $table.metric,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fetchedAt => $composableBuilder(
    column: $table.fetchedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedPayloadsTableAnnotationComposer
    extends Composer<_$LocalStore, $CachedPayloadsTable> {
  $$CachedPayloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get day =>
      $composableBuilder(column: $table.day, builder: (column) => column);

  GeneratedColumn<String> get metric =>
      $composableBuilder(column: $table.metric, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<DateTime> get fetchedAt =>
      $composableBuilder(column: $table.fetchedAt, builder: (column) => column);
}

class $$CachedPayloadsTableTableManager
    extends
        RootTableManager<
          _$LocalStore,
          $CachedPayloadsTable,
          CachedPayload,
          $$CachedPayloadsTableFilterComposer,
          $$CachedPayloadsTableOrderingComposer,
          $$CachedPayloadsTableAnnotationComposer,
          $$CachedPayloadsTableCreateCompanionBuilder,
          $$CachedPayloadsTableUpdateCompanionBuilder,
          (
            CachedPayload,
            BaseReferences<_$LocalStore, $CachedPayloadsTable, CachedPayload>,
          ),
          CachedPayload,
          PrefetchHooks Function()
        > {
  $$CachedPayloadsTableTableManager(_$LocalStore db, $CachedPayloadsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedPayloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedPayloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedPayloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> day = const Value.absent(),
                Value<String> metric = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<DateTime> fetchedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedPayloadsCompanion(
                day: day,
                metric: metric,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String day,
                required String metric,
                required String payload,
                required DateTime fetchedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedPayloadsCompanion.insert(
                day: day,
                metric: metric,
                payload: payload,
                fetchedAt: fetchedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedPayloadsTableProcessedTableManager =
    ProcessedTableManager<
      _$LocalStore,
      $CachedPayloadsTable,
      CachedPayload,
      $$CachedPayloadsTableFilterComposer,
      $$CachedPayloadsTableOrderingComposer,
      $$CachedPayloadsTableAnnotationComposer,
      $$CachedPayloadsTableCreateCompanionBuilder,
      $$CachedPayloadsTableUpdateCompanionBuilder,
      (
        CachedPayload,
        BaseReferences<_$LocalStore, $CachedPayloadsTable, CachedPayload>,
      ),
      CachedPayload,
      PrefetchHooks Function()
    >;

class $LocalStoreManager {
  final _$LocalStore _db;
  $LocalStoreManager(this._db);
  $$CachedPayloadsTableTableManager get cachedPayloads =>
      $$CachedPayloadsTableTableManager(_db, _db.cachedPayloads);
}
