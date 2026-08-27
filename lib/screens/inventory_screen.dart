import 'package:flutter/material.dart';

import '../data/inventory_repository.dart';
import '../models/inventory.dart';
import '../services/csv_export_service.dart';
import 'scanner_screen.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({
    super.key,
    required this.inventory,
    required this.repository,
  });

  final Inventory inventory;
  final InventoryRepository repository;

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  final CsvExportService _csvExportService = const CsvExportService();

  bool _loading = true;
  bool _exporting = false;
  List<InventoryItem> _items = const [];

  int get _inventoryId => widget.inventory.id!;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final items = await widget.repository.listItems(_inventoryId);
    if (!mounted) return;
    setState(() {
      _items = items;
      _loading = false;
    });
  }

  Future<void> _scanItem() async {
    final barcode = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const ScannerScreen()),
    );
    if (!mounted || barcode == null || barcode.isEmpty) return;
    await _addItem(initialBarcode: barcode);
  }

  Future<void> _export() async {
    if (_items.isEmpty || _exporting) return;
    setState(() => _exporting = true);
    try {
      await _csvExportService.share(
        inventory: widget.inventory,
        items: _items,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Не удалось экспортировать CSV: $error')),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _addItem({String? initialBarcode}) async {
    final result = await showDialog<_ItemDraft>(
      context: context,
      builder: (_) => _ItemDialog(initialBarcode: initialBarcode),
    );
    if (!mounted || result == null) return;

    await widget.repository.addOrIncrementItem(
      inventoryId: _inventoryId,
      barcode: result.barcode,
      name: result.name,
      quantity: result.quantity,
    );
    if (mounted) await _reload();
  }

  Future<void> _editItem(InventoryItem item) async {
    final result = await showDialog<_ItemDraft>(
      context: context,
      builder: (_) => _ItemDialog(
        item: item,
        initialBarcode: item.barcode,
      ),
    );
    if (!mounted || result == null) return;

    await widget.repository.updateItem(
      item.copyWith(name: result.name, quantity: result.quantity),
    );
    if (mounted) await _reload();
  }

  Future<void> _deleteItem(InventoryItem item) async {
    if (item.id == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить позицию?'),
            content: Text(item.name?.isNotEmpty == true ? item.name! : item.barcode),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Удалить'),
              ),
            ],
          ),
        ) ??
        false;
    if (!confirmed) return;
    await widget.repository.deleteItem(item.id!);
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity = _items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.inventory.name),
        actions: [
          IconButton(
            tooltip: 'Сканировать',
            onPressed: _scanItem,
            icon: const Icon(Icons.qr_code_scanner),
          ),
          IconButton(
            tooltip: 'Экспорт CSV',
            onPressed: _items.isEmpty || _exporting ? null : _export,
            icon: _exporting
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.ios_share_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Ввести вручную'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: _SummaryCard(label: 'Позиций', value: '${_items.length}'),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryCard(label: 'Единиц', value: '$totalQuantity'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _items.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.inventory_2_outlined, size: 64),
                              const SizedBox(height: 16),
                              const Text(
                                'Позиции пока не добавлены.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              FilledButton.icon(
                                onPressed: _scanItem,
                                icon: const Icon(Icons.qr_code_scanner),
                                label: const Text('Сканировать штрихкод'),
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final item = _items[index];
                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(child: Text('${item.quantity}')),
                              title: Text(
                                item.name?.isNotEmpty == true ? item.name! : 'Без названия',
                              ),
                              subtitle: Text(item.barcode),
                              onTap: () => _editItem(item),
                              trailing: IconButton(
                                tooltip: 'Удалить',
                                onPressed: () => _deleteItem(item),
                                icon: const Icon(Icons.delete_outline),
                              ),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _ItemDraft {
  const _ItemDraft({
    required this.barcode,
    required this.name,
    required this.quantity,
  });

  final String barcode;
  final String name;
  final int quantity;
}

class _ItemDialog extends StatefulWidget {
  const _ItemDialog({this.item, this.initialBarcode});

  final InventoryItem? item;
  final String? initialBarcode;

  bool get editing => item != null;

  @override
  State<_ItemDialog> createState() => _ItemDialogState();
}

class _ItemDialogState extends State<_ItemDialog> {
  late final TextEditingController _barcodeController;
  late final TextEditingController _nameController;
  late final TextEditingController _quantityController;

  @override
  void initState() {
    super.initState();
    _barcodeController = TextEditingController(
      text: widget.initialBarcode ?? widget.item?.barcode ?? '',
    );
    _nameController = TextEditingController(text: widget.item?.name ?? '');
    _quantityController = TextEditingController(
      text: widget.item == null ? '1' : '${widget.item!.quantity}',
    );
  }

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _submit() {
    final barcode = _barcodeController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim());
    if (barcode.isEmpty || quantity == null || quantity <= 0) return;

    Navigator.of(context).pop(
      _ItemDraft(
        barcode: barcode,
        name: _nameController.text.trim(),
        quantity: quantity,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.editing ? 'Редактировать позицию' : 'Добавить позицию'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _barcodeController,
              enabled: !widget.editing,
              autofocus: !widget.editing && widget.initialBarcode == null,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Штрихкод *'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Название товара'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Количество *'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.editing ? 'Сохранить' : 'Добавить'),
        ),
      ],
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 4),
            Text(value, style: Theme.of(context).textTheme.headlineMedium),
          ],
        ),
      ),
    );
  }
}
