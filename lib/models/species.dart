class Species {
  final String id;
  final String commonName;
  final String scientificName;
  final String group;

  /// In your old pack JSON this is per-zoo placement. Keep it for now.
  final String zone;

  final String description;

  const Species({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.group,
    required this.zone,
    required this.description,
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    return Species(
      id: json['id'] as String,
      commonName: (json['common_name'] as String?) ?? '',
      scientificName: (json['scientific_name'] as String?) ?? '',
      group: (json['group'] as String?) ?? '',
      zone: (json['zone'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'common_name': commonName,
        'scientific_name': scientificName,
        'group': group,
        'zone': zone,
        'description': description,
      };
}
