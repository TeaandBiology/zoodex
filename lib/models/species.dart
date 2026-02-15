class Species {
  final String id;
  final String commonName;
  final String scientificName;
  final String group;

  /// In your old pack JSON this is per-zoo placement. Keep it for now.
  final String zone;

  final String description;
  final String range;
  final String iucn;

  const Species({
    required this.id,
    required this.commonName,
    required this.scientificName,
    required this.group,
    required this.zone,
    required this.description,
    required this.range,
    this.iucn = '',
  });

  factory Species.fromJson(Map<String, dynamic> json) {
    String iucnVal = '';
    if (json['iucn'] is String) {
      iucnVal = json['iucn'] as String;
    } else if (json['iucn_status'] is String) {
      iucnVal = json['iucn_status'] as String;
    } else if (json['iucnStatus'] is String) {
      iucnVal = json['iucnStatus'] as String;
    } else if (json['IUCN status'] is String) {
      iucnVal = json['IUCN status'] as String;
    } else if (json['IUCN_status'] is String) {
      iucnVal = json['IUCN_status'] as String;
    }

    return Species(
      id: json['id'] as String,
      commonName: (json['common_name'] as String?) ?? '',
      scientificName: (json['scientific_name'] as String?) ?? '',
      group: (json['group'] as String?) ?? '',
      zone: (json['zone'] as String?) ?? '',
      description: (json['description'] as String?) ?? '',
      range: (json['range'] as String?) ?? '',
      iucn: iucnVal,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'common_name': commonName,
        'scientific_name': scientificName,
        'group': group,
        'zone': zone,
        'description': description,
        'range': range,
        'iucn': iucn,
      };
}
