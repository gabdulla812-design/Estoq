import 'package:flutter/material.dart';

import '../data/inventory_repository.dart';
import '../models/inventory.dart';

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
  bool _loading = true;
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

  Future<void> _addItem({String? initialBarcode}) async {
    final barcodeController = TextEditingController(text: initialBarcode ?? '');
    final nameController = TextEditingController();
    final quantityController = TextEditingController(text: '1');

    final result = await showDialog<_ItemDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Добавить позицию'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: barcodeController,
                autofocus: initialBarcode == null,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Штрихкод *'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: nameController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Название товара'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: quantityController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Количество *'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text.trim());
              final barcode = barcodeController.text.trim();
              if (barcode.isEmpty || quantity == null || quantity <= 0) return;
              Navigator.pop(
                context,
                _ItemDraft(
                  barcode: barcode,
                  name: nameController.text.trim(),
                  quantity: quantity,
                ),
              );
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );

    barcodeController.dispose();
    nameController.dispose();
    quantityController.dispose();
    if (result == null) return;

    await widget.repository.addOrIncrementItem(
      inventoryId: _inventoryId,
      barcode: result.barcode,
      name: result.name,
      quantity: result.quantity,
    );
    await _reload();
  }

  Future<void> _editItem(InventoryItem item) async {
    final nameController = TextEditingController(text: item.name ?? '');
    final quantityController = TextEditingController(text: '${item.quantity}');

    final result = await showDialog<_ItemDraft>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Редактировать позицию'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Штрихкод: ${item.barcode}'),
            const SizedBox(height: 12),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Название товара'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: quantityController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Количество'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () {
              final quantity = int.tryParse(quantityController.text.trim());
              if (quantity == null || quantity <= 0) return;
              Navigator.pop(
                context,
                _ItemDraft(
                  barcode: item.barcode,
                  name: nameController.text.trim(),
                  quantity: quantity,
                ),
              );
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );

    nameController.dispose();
    quantityController.dispose();
    if (result == null) return;

    await widget.repository.updateItem(
      item.copyWith(name: result.name, quantity: result.quantity),
    );
    await _reload();
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
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuantity = _items.fold<int>(0, (sum, item) => sum + item.quantity);

    return Scaffold(
      appBar: AppBar(title: Text(widget.inventory.name)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addItem,
        icon: const Icon(Icons.add),
        label: const Text('Добавить'),
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
                    ? const Center(
                        child: Padding(
                          padding: EdgeInsets.all(32),
                          child: Text(
                            'Позиции пока не добавлены.\nДобавьте товар вручную или отсканируйте штрихкод.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _reload,
                        child: ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: _items.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
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
