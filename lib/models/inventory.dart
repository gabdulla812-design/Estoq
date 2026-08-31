class Inventory {
  const Inventory({
    this.id,
    required this.name,
    required this.createdAt,
  });

  final int? id;
  final String name;
  final DateTime createdAt;

  Inventory copyWith({int? id, String? name, DateTime? createdAt}) {
    return Inventory(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'created_at': createdAt.toIso8601String(),
      };

  factory Inventory.fromMap(Map<String, Object?> map) {
    return Inventory(
      id: map['id'] as int?,
      name: map['name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}

class InventoryItem {
  const InventoryItem({
    this.id,
    required this.inventoryId,
    required this.barcode,
    this.name,
    required this.quantity,
  });

  final int? id;
  final int inventoryId;
  final String barcode;
  final String? name;
  final int quantity;

  InventoryItem copyWith({
    int? id,
    int? inventoryId,
    String? barcode,
    String? name,
    int? quantity,
  }) {
    return InventoryItem(
      id: id ?? this.id,
      inventoryId: inventoryId ?? this.inventoryId,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      quantity: quantity ?? this.quantity,
    );
  }

  Map<String, Object?> toMap() => {
        'id': id,
        'inventory_id': inventoryId,
        'barcode': barcode,
        'name': name,
        'quantity': quantity,
      };

  factory InventoryItem.fromMap(Map<String, Object?> map) {
    return InventoryItem(
      id: map['id'] as int?,
      inventoryId: map['inventory_id'] as int,
      barcode: map['barcode'] as String,
      name: map['name'] as String?,
      quantity: map['quantity'] as int,
    );
  }
}
