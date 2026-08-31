import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart' as sqflite;

import '../models/inventory.dart';
import '../utils/barcode_normalizer.dart';

class InventoryRepository {
  InventoryRepository._({
    sqflite.DatabaseFactory? databaseFactory,
    String? databasePath,
  })  : _databaseFactory = databaseFactory,
        _databasePath = databasePath;

  static final InventoryRepository instance = InventoryRepository._();

  factory InventoryRepository.testing({
    required sqflite.DatabaseFactory databaseFactory,
    required String databasePath,
  }) {
    return InventoryRepository._(
      databaseFactory: databaseFactory,
      databasePath: databasePath,
    );
  }

  final sqflite.DatabaseFactory? _databaseFactory;
  final String? _databasePath;
  sqflite.Database? _database;

  Future<sqflite.Database> get database async {
    if (_database != null) return _database!;

    final factory = _databaseFactory ?? sqflite.databaseFactory;
    final dbPath = _databasePath ??
        p.join(await sqflite.getDatabasesPath(), 'skladscan.db');

    _database = await factory.openDatabase(
      dbPath,
      options: sqflite.OpenDatabaseOptions(
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE inventories(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              name TEXT NOT NULL,
              created_at TEXT NOT NULL
            )
          ''');
          await db.execute('''
            CREATE TABLE inventory_items(
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              inventory_id INTEGER NOT NULL,
              barcode TEXT NOT NULL,
              name TEXT,
              quantity INTEGER NOT NULL CHECK(quantity > 0),
              FOREIGN KEY(inventory_id) REFERENCES inventories(id) ON DELETE CASCADE,
              UNIQUE(inventory_id, barcode)
            )
          ''');
        },
      ),
    );
    return _database!;
  }

  Future<Inventory> createInventory(String name, {DateTime? createdAt}) async {
    final cleanName = name.trim();
    if (cleanName.isEmpty) {
      throw ArgumentError('Название инвентаризации не может быть пустым.');
    }
    final db = await database;
    final inventory = Inventory(
      name: cleanName,
      createdAt: createdAt ?? DateTime.now(),
    );
    final id = await db.insert('inventories', inventory.toMap()..remove('id'));
    return inventory.copyWith(id: id);
  }

  Future<List<Inventory>> listInventories() async {
    final db = await database;
    final rows = await db.query('inventories', orderBy: 'created_at DESC');
    return rows.map(Inventory.fromMap).toList(growable: false);
  }

  Future<void> deleteInventory(int inventoryId) async {
    final db = await database;
    await db.delete('inventories', where: 'id = ?', whereArgs: [inventoryId]);
  }

  Future<List<InventoryItem>> listItems(int inventoryId) async {
    final db = await database;
    final rows = await db.query(
      'inventory_items',
      where: 'inventory_id = ?',
      whereArgs: [inventoryId],
      orderBy: 'id DESC',
    );
    return rows.map(InventoryItem.fromMap).toList(growable: false);
  }

  Future<InventoryItem> addOrIncrementItem({
    required int inventoryId,
    required String barcode,
    String? name,
    int quantity = 1,
  }) async {
    final cleanBarcode = BarcodeNormalizer.normalize(barcode);
    final cleanName = name?.trim();
    if (cleanBarcode.isEmpty) {
      throw ArgumentError('Штрихкод не может быть пустым.');
    }
    if (quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля.');
    }

    final db = await database;
    return db.transaction((txn) async {
      final existingRows = await txn.query(
        'inventory_items',
        where: 'inventory_id = ? AND barcode = ?',
        whereArgs: [inventoryId, cleanBarcode],
        limit: 1,
      );

      if (existingRows.isNotEmpty) {
        final existing = InventoryItem.fromMap(existingRows.first);
        final updated = existing.copyWith(
          name: (cleanName == null || cleanName.isEmpty) ? existing.name : cleanName,
          quantity: existing.quantity + quantity,
        );
        await txn.update(
          'inventory_items',
          {
            'name': updated.name,
            'quantity': updated.quantity,
          },
          where: 'id = ?',
          whereArgs: [existing.id],
        );
        return updated;
      }

      final item = InventoryItem(
        inventoryId: inventoryId,
        barcode: cleanBarcode,
        name: (cleanName == null || cleanName.isEmpty) ? null : cleanName,
        quantity: quantity,
      );
      final id = await txn.insert('inventory_items', item.toMap()..remove('id'));
      return item.copyWith(id: id);
    });
  }

  Future<void> updateItem(InventoryItem item) async {
    if (item.id == null) throw ArgumentError('Позиция должна иметь id.');
    if (item.quantity <= 0) {
      throw ArgumentError('Количество должно быть больше нуля.');
    }

    final cleanName = item.name?.trim();
    final cleanBarcode = BarcodeNormalizer.normalize(item.barcode);
    final db = await database;
    await db.update(
      'inventory_items',
      {
        'barcode': cleanBarcode,
        'name': cleanName == null || cleanName.isEmpty ? null : cleanName,
        'quantity': item.quantity,
      },
      where: 'id = ?',
      whereArgs: [item.id],
    );
  }

  Future<void> deleteItem(int itemId) async {
    final db = await database;
    await db.delete('inventory_items', where: 'id = ?', whereArgs: [itemId]);
  }

  Future<void> close() async {
    await _database?.close();
    _database = null;
  }
}
