// lib/core/sync/sync_engine.dart
import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/app_constants.dart';
import '../database/app_database.dart';

enum SyncStatus { idle, syncing, error, offline }

class SyncState {
  final SyncStatus status;
  final String?   message;
  final DateTime? lastSync;
  final int       pendingCount;

  const SyncState({
    this.status      = SyncStatus.idle,
    this.message,
    this.lastSync,
    this.pendingCount = 0,
  });

  SyncState copyWith({
    SyncStatus? status,
    String?     message,
    DateTime?   lastSync,
    int?        pendingCount,
  }) => SyncState(
    status:       status       ?? this.status,
    message:      message      ?? this.message,
    lastSync:     lastSync     ?? this.lastSync,
    pendingCount: pendingCount ?? this.pendingCount,
  );
}

class SyncEngine {
  final AppDatabase   _db;
  final SupabaseClient _sb;
  Timer? _timer;
  SyncState _state = const SyncState();
  final _ctrl = StreamController<SyncState>.broadcast();

  Stream<SyncState> get stream => _ctrl.stream;
  SyncState         get state  => _state;

  SyncEngine(this._db, this._sb);

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(
      const Duration(seconds: AppConstants.syncIntervalSeconds),
      (_) => sync(),
    );
    Connectivity().onConnectivityChanged.listen((results) {
      if (results.any((r) => r != ConnectivityResult.none)) sync();
    });
  }

  void stop() { _timer?.cancel(); }

  Future<void> sync() async {
    if (_state.status == SyncStatus.syncing) return;
    if (!await _isOnline()) { _emit(_state.copyWith(status: SyncStatus.offline)); return; }

    _emit(_state.copyWith(status: SyncStatus.syncing));
    try {
      await _pushOutbox();
      await _pullAll();
      _emit(_state.copyWith(status: SyncStatus.idle, lastSync: DateTime.now(), pendingCount: 0));
    } catch (e) {
      _emit(_state.copyWith(status: SyncStatus.error, message: e.toString()));
    }
  }

  Future<void> enqueue({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) async {
    await _db.into(_db.outboxQueue).insert(OutboxQueueCompanion.insert(
      id:         '${entityType}_${entityId}_${DateTime.now().millisecondsSinceEpoch}',
      entityType: entityType,
      entityId:   entityId,
      operation:  operation,
      payload:    jsonEncode(payload),
      createdAt:  DateTime.now().millisecondsSinceEpoch,
    ));
  }

  Future<void> _pushOutbox() async {
    final pending = await (_db.select(_db.outboxQueue)
      ..where((t) => t.syncedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.createdAt)])
      ..limit(AppConstants.outboxBatchSize)).get();

    for (final entry in pending) {
      try {
        final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
        if (entry.operation == 'DELETE') {
          await _sb.from(entry.entityType)
              .update({'is_deleted': true}).eq('id', entry.entityId);
        } else {
          await _sb.from(entry.entityType).upsert(payload, onConflict: 'id');
        }
        await (_db.update(_db.outboxQueue)..where((t) => t.id.equals(entry.id)))
            .write(OutboxQueueCompanion(syncedAt: Value(DateTime.now().millisecondsSinceEpoch)));
      } catch (e) {
        await (_db.update(_db.outboxQueue)..where((t) => t.id.equals(entry.id)))
            .write(OutboxQueueCompanion(
              attempts:  Value(entry.attempts + 1),
              lastError: Value(e.toString()),
            ));
      }
    }

    // Clean synced entries older than 7 days
    final cutoff = DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch;
    await (_db.delete(_db.outboxQueue)
      ..where((t) => t.syncedAt.isNotNull() & t.syncedAt.isSmallerThanValue(cutoff))).go();
  }

  Future<void> _pullAll() async {
    for (final entity in [
      'products', 'product_categories', 'customers',
      'invoices', 'inventory', 'vendors',
    ]) { await _pullEntity(entity); }
  }

  Future<void> _pullEntity(String entity) async {
    final wm = await (_db.select(_db.syncWatermarks)
      ..where((t) => t.entityType.equals(entity))).getSingleOrNull();
    final since = wm?.lastSyncAt ?? 0;

    try {
      final rows = await _sb.from(entity).select()
          .gt('updated_at', since).order('updated_at') as List;

      for (final row in rows) { await _upsertRow(entity, row as Map<String, dynamic>); }

      if (rows.isNotEmpty) {
        final maxTs = rows.map((r) => (r as Map)['updated_at'] as int? ?? 0)
            .reduce((a, b) => a > b ? a : b);
        await _db.into(_db.syncWatermarks).insertOnConflictUpdate(
          SyncWatermarksCompanion.insert(entityType: entity, lastSyncAt: Value(maxTs)));
      }
    } catch (_) {} // silent — retry next cycle
  }

  Future<void> _upsertRow(String entity, Map<String, dynamic> row) async {
    switch (entity) {
      case 'products':
        await _db.into(_db.products).insertOnConflictUpdate(ProductsCompanion.insert(
          id:         row['id'] as String,
          tenantId:   row['tenant_id'] as String,
          name:       row['name'] as String,
          salePrice:  Value((row['sale_price'] as num?)?.toDouble() ?? 0.0),
          pctCode:    Value(row['pct_code'] as String? ?? '9999.99'),
          updatedAt:  Value(row['updated_at'] as int? ?? 0),
        ));
      case 'customers':
        await _db.into(_db.customers).insertOnConflictUpdate(CustomersCompanion.insert(
          id:       row['id'] as String,
          tenantId: row['tenant_id'] as String,
          name:     row['name'] as String,
          phone:    Value(row['phone'] as String?),
          balance:  Value((row['balance'] as num?)?.toDouble() ?? 0.0),
          updatedAt: Value(row['updated_at'] as int? ?? 0),
        ));
      default:
        break; // other entities handled as needed
    }
  }

  Future<bool> _isOnline() async {
    final r = await Connectivity().checkConnectivity();
    return r.any((c) => c != ConnectivityResult.none);
  }

  Future<int> pendingCount() async {
    final rows = await (_db.select(_db.outboxQueue)..where((t) => t.syncedAt.isNull())).get();
    return rows.length;
  }

  void _emit(SyncState s) { _state = s; _ctrl.add(s); }

  void dispose() { _timer?.cancel(); _ctrl.close(); }
}
