import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/inventory.dart';

class InventoryRepository {
  InventoryRepository._();

  static final InventoryRepository instance = InventoryRepository._();

  Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    final databasesPath = await getDatabasesPath();
    final dbPath = p.join(databasesPath, 'skladscan.db');
    _database = await openDatabase(
      dbPath,
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
    final cleanBarcode = barcode.trim();
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
    final db = await database;
    await db.update(
      'inventory_items',
      {
        'barcode': item.barcode.trim(),
        'name': item.name?.trim().isEmpty == true ? null : item.name?.trim(),
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
