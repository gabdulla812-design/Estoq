import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/inventory.dart';

class CsvExportService {
  const CsvExportService();

  Future<File> buildFile({
    required Inventory inventory,
    required List<InventoryItem> items,
  }) async {
    final directory = await getApplicationDocumentsDirectory();
    final date = _dateForFile(inventory.createdAt);
    final safeName = _safeFilePart(inventory.name);
    final file = File(p.join(directory.path, 'inventory_${date}_$safeName.csv'));

    final buffer = StringBuffer('\uFEFF');
    buffer.writeln('штрихкод;название;количество');
    for (final item in items) {
      buffer.writeln([
        _escape(item.barcode),
        _escape(item.name ?? ''),
        item.quantity.toString(),
      ].join(';'));
    }

    await file.writeAsString(buffer.toString(), encoding: utf8, flush: true);
    return file;
  }

  Future<void> share({
    required Inventory inventory,
    required List<InventoryItem> items,
  }) async {
    final file = await buildFile(inventory: inventory, items: items);
    await SharePlus.instance.share(
      ShareParams(
        title: 'Экспорт «${inventory.name}»',
        subject: 'Инвентаризация ${inventory.name}',
        text: 'CSV-файл инвентаризации «${inventory.name}».',
        files: [XFile(file.path, mimeType: 'text/csv')],
      ),
    );
  }

  String _escape(String value) {
    final escaped = value.replaceAll('"', '""');
    if (escaped.contains(';') || escaped.contains('"') || escaped.contains('\n') || escaped.contains('\r')) {
      return '"$escaped"';
    }
    return escaped;
  }

  String _safeFilePart(String value) {
    final normalized = value.trim().replaceAll(RegExp(r'[\\/:*?"<>|]+'), '_');
    final compact = normalized.replaceAll(RegExp(r'\s+'), '_');
    return compact.isEmpty ? 'inventory' : compact;
  }

  String _dateForFile(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }
}
