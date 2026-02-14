class Observation {
  final DateTime seenAt;
  final double? lat;
  final double? lng;
  final double? accuracyM;
  final String? notes;
  final String? zooName;
  final String? zone;

  const Observation({
    required this.seenAt,
    this.lat,
    this.lng,
    this.accuracyM,
    this.notes,
    this.zooName,
    this.zone,
  });

  Map<String, dynamic> toMap() => {
        'seenAt': seenAt.toIso8601String(),
        'lat': lat,
        'lng': lng,
        'accuracyM': accuracyM,
        'notes': notes,
        'zooName': zooName,
        'zone': zone,
      };

  static Observation fromMap(Map<dynamic, dynamic> map) {
    final seenAtRaw = map['seenAt'];
    DateTime parsedSeenAt;
    if (seenAtRaw is String) {
      parsedSeenAt = DateTime.tryParse(seenAtRaw) ?? DateTime.now();
    } else {
      parsedSeenAt = DateTime.now();
    }

    double? asDouble(dynamic v) => (v is num) ? v.toDouble() : null;

    return Observation(
      seenAt: parsedSeenAt,
      lat: asDouble(map['lat']),
      lng: asDouble(map['lng']),
      accuracyM: asDouble(map['accuracyM']),
      notes: map['notes'] as String?,
      zooName: map['zooName'] as String?,
      zone: map['zone'] as String?,
    );
  }
}

String formatLocalDateTime(DateTime dt) {
  final d = dt.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)} ${two(d.hour)}:${two(d.minute)}';
}
