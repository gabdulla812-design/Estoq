import 'package:flutter/material.dart';

void main() {
  runApp(const SkladScanApp());
}

class SkladScanApp extends StatelessWidget {
  const SkladScanApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'СкладСкан',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1565C0)),
        useMaterial3: true,
      ),
      home: const InventoryHomePage(),
    );
  }
}

class InventoryHomePage extends StatefulWidget {
  const InventoryHomePage({super.key});

  @override
  State<InventoryHomePage> createState() => _InventoryHomePageState();
}

class _InventoryHomePageState extends State<InventoryHomePage> {
  final List<InventoryItem> _items = [];
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _quantityController = TextEditingController(text: '1');

  @override
  void dispose() {
    _barcodeController.dispose();
    _nameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  void _addItem() {
    final barcode = _barcodeController.text.trim();
    final name = _nameController.text.trim();
    final quantity = int.tryParse(_quantityController.text.trim()) ?? 1;
    if (barcode.isEmpty) return;

    final existing = _items.indexWhere((item) => item.barcode == barcode);
    setState(() {
      if (existing >= 0) {
        _items[existing] = _items[existing].copyWith(
          quantity: _items[existing].quantity + quantity,
          name: name.isEmpty ? _items[existing].name : name,
        );
      } else {
        _items.insert(
          0,
          InventoryItem(
            barcode: barcode,
            name: name.isEmpty ? 'Без названия' : name,
            quantity: quantity,
          ),
        );
      }
    });
    _barcodeController.clear();
    _nameController.clear();
    _quantityController.text = '1';
    FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.fold<int>(0, (sum, item) => sum + item.quantity);
    return Scaffold(
      appBar: AppBar(
        title: const Text('СкладСкан'),
        actions: [
          IconButton(
            tooltip: 'Экспорт',
            onPressed: _items.isEmpty ? null : () {},
            icon: const Icon(Icons.ios_share),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {},
        icon: const Icon(Icons.qr_code_scanner),
        label: const Text('Сканировать'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(child: _StatCard(label: 'Позиций', value: '${_items.length}')),
                  const SizedBox(width: 12),
                  Expanded(child: _StatCard(label: 'Единиц', value: '$total')),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _barcodeController,
                decoration: const InputDecoration(
                  labelText: 'Штрихкод',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.barcode_reader),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Наименование',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  SizedBox(
                    width: 110,
                    child: TextField(
                      controller: _quantityController,
                      decoration: const InputDecoration(
                        labelText: 'Количество',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.number,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _addItem,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text('Инвентаризация', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Expanded(
                child: _items.isEmpty
                    ? const Center(
                        child: Text(
                          'Пока нет позиций.\nОтсканируйте штрихкод или добавьте его вручную.',
                          textAlign: TextAlign.center,
                        ),
                      )
                    : ListView.separated(
                        itemCount: _items.length,
                        separatorBuilder: (_, __) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(item.name),
                            subtitle: Text(item.barcode),
                            leading: CircleAvatar(child: Text('${item.quantity}')),
                            trailing: IconButton(
                              tooltip: 'Удалить',
                              onPressed: () => setState(() => _items.removeAt(index)),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InventoryItem {
  const InventoryItem({required this.barcode, required this.name, required this.quantity});

  final String barcode;
  final String name;
  final int quantity;

  InventoryItem copyWith({String? barcode, String? name, int? quantity}) {
    return InventoryItem(
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value});

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
