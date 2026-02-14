class Zoo {
  final String id;
  final String name;
  final String lastUpdated;

  const Zoo({
    required this.id,
    required this.name,
    required this.lastUpdated,
  });

  factory Zoo.fromJson(Map<String, dynamic> json) {
    return Zoo(
      // supports both new ("id"/"name") and old ("pack_id"/"zoo_name") keys
      id: (json['id'] as String?) ?? (json['pack_id'] as String?) ?? '',
      name: (json['name'] as String?) ?? (json['zoo_name'] as String?) ?? '',
      lastUpdated: (json['last_updated'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'last_updated': lastUpdated,
      };
}
