import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:skladscan/data/inventory_repository.dart';
import 'package:skladscan/utils/barcode_normalizer.dart';

void main() {
  sqfliteFfiInit();

  late Directory tempDir;
  late String dbPath;
  late InventoryRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('skladscan_test_');
    dbPath = '${tempDir.path}/skladscan_test.db';
    repository = InventoryRepository.testing(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );
  });

  tearDown(() async {
    await repository.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('добавляет позицию и суммирует одинаковый штрихкод', () async {
    final inventory = await repository.createInventory('Тест');

    await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '4601234567890',
      name: 'Товар',
      quantity: 2,
    );
    await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '4601234567890',
      quantity: 3,
    );

    final items = await repository.listItems(inventory.id!);
    expect(items, hasLength(1));
    expect(items.single.quantity, 5);
    expect(items.single.name, 'Товар');
  });

  test('GS1 DataMatrix и EAN-13 одного товара суммируются вместе', () async {
    final inventory = await repository.createInventory('Склад №1');

    await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '4607015235401',
      name: 'Пряники',
      quantity: 100,
    );
    await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '0104607015235401215IMmPM93XxxA',
      quantity: 2,
    );

    final items = await repository.listItems(inventory.id!);
    expect(items, hasLength(1));
    expect(items.single.barcode, '4607015235401');
    expect(items.single.name, 'Пряники');
    expect(items.single.quantity, 102);
  });

  test('нормализует GS1 DataMatrix с идентификатором символики и FNC1', () {
    expect(
      BarcodeNormalizer.normalize(']d20104607015235401\u001D21SERIAL123'),
      '4607015235401',
    );
    expect(
      BarcodeNormalizer.normalize('(01)0460701523540121SERIAL123'),
      '4607015235401',
    );
  });

  test('изменяет количество и название позиции', () async {
    final inventory = await repository.createInventory('Тест');
    final item = await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '12345',
      quantity: 1,
    );

    await repository.updateItem(item.copyWith(name: 'Новое имя', quantity: 7));

    final saved = (await repository.listItems(inventory.id!)).single;
    expect(saved.name, 'Новое имя');
    expect(saved.quantity, 7);
  });

  test('удаляет позицию', () async {
    final inventory = await repository.createInventory('Тест');
    final item = await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '777',
      quantity: 1,
    );

    await repository.deleteItem(item.id!);

    expect(await repository.listItems(inventory.id!), isEmpty);
  });

  test('сохраняет данные после закрытия и повторного открытия базы', () async {
    final inventory = await repository.createInventory(
      'Склад №1',
      createdAt: DateTime(2026, 8, 27),
    );
    await repository.addOrIncrementItem(
      inventoryId: inventory.id!,
      barcode: '4600000000001',
      name: 'Сохранённый товар',
      quantity: 4,
    );

    await repository.close();

    repository = InventoryRepository.testing(
      databaseFactory: databaseFactoryFfi,
      databasePath: dbPath,
    );

    final inventories = await repository.listInventories();
    expect(inventories, hasLength(1));
    expect(inventories.single.name, 'Склад №1');

    final items = await repository.listItems(inventories.single.id!);
    expect(items, hasLength(1));
    expect(items.single.barcode, '4600000000001');
    expect(items.single.quantity, 4);
  });
}
