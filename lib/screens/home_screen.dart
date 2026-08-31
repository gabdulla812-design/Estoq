import 'package:flutter/material.dart';

import '../data/inventory_repository.dart';
import '../models/inventory.dart';
import 'inventory_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.repository});

  final InventoryRepository repository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loading = true;
  List<Inventory> _inventories = const [];

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    final inventories = await widget.repository.listInventories();
    if (!mounted) return;
    setState(() {
      _inventories = inventories;
      _loading = false;
    });
  }

  Future<void> _createInventory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _CreateInventoryDialog(),
    );
    if (!mounted || name == null || name.trim().isEmpty) return;

    final inventory = await widget.repository.createInventory(name.trim());
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => InventoryScreen(
          inventory: inventory,
          repository: widget.repository,
        ),
      ),
    );
    if (mounted) await _reload();
  }

  Future<void> _deleteInventory(Inventory inventory) async {
    if (inventory.id == null) return;
    final confirmed = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Удалить инвентаризацию?'),
            content: Text(
              '«${inventory.name}» и все её позиции будут удалены без возможности восстановления.',
            ),
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
    await widget.repository.deleteInventory(inventory.id!);
    if (mounted) await _reload();
  }

  String _formatDate(DateTime value) {
    final d = value.day.toString().padLeft(2, '0');
    final m = value.month.toString().padLeft(2, '0');
    return '$d.$m.${value.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('СкладСкан'),
            Text(
              'Версия 0.1.5 · сборка 6',
              style: TextStyle(fontSize: 11, fontWeight: FontWeight.normal),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createInventory,
        icon: const Icon(Icons.add),
        label: const Text('Новая инвентаризация'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _inventories.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Text(
                      'Инвентаризаций пока нет.\nСоздайте первую кнопкой ниже.',
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _reload,
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    itemCount: _inventories.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final inventory = _inventories[index];
                      return Card(
                        child: ListTile(
                          leading: const CircleAvatar(
                            child: Icon(Icons.inventory_2_outlined),
                          ),
                          title: Text(inventory.name),
                          subtitle: Text(_formatDate(inventory.createdAt)),
                          trailing: PopupMenuButton<String>(
                            onSelected: (value) {
                              if (value == 'delete') {
                                _deleteInventory(inventory);
                              }
                            },
                            itemBuilder: (_) => const [
                              PopupMenuItem(
                                value: 'delete',
                                child: Text('Удалить'),
                              ),
                            ],
                          ),
                          onTap: () async {
                            await Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => InventoryScreen(
                                  inventory: inventory,
                                  repository: widget.repository,
                                ),
                              ),
                            );
                            if (mounted) await _reload();
                          },
                        ),
                      );
                    },
                  ),
                ),
    );
  }
}

class _CreateInventoryDialog extends StatefulWidget {
  const _CreateInventoryDialog();

  @override
  State<_CreateInventoryDialog> createState() => _CreateInventoryDialogState();
}

class _CreateInventoryDialogState extends State<_CreateInventoryDialog> {
  String _name = '';
  bool _submitting = false;

  Future<void> _submit() async {
    final value = _name.trim();
    if (value.isEmpty || _submitting) return;

    setState(() => _submitting = true);
    FocusManager.instance.primaryFocus?.unfocus();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    if (!mounted) return;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Новая инвентаризация'),
      content: TextFormField(
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          labelText: 'Название',
          hintText: 'Например: Склад №1',
        ),
        onChanged: (value) => _name = value,
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _submitting ? null : _submit,
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
