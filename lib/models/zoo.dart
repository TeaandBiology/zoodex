class Zoo {
  final String id;
  final String name;

  /// Authoritative centre point. Null when coordinates haven't been provided yet
  /// (in which case location verification simply can't confirm this zoo).
  final double? lat;
  final double? lng;

  /// Geofence radius in metres around [lat]/[lng]. A visit counts as "verified"
  /// when the user's GPS location is within this distance of the zoo centre.
  final double radiusM;

  /// ISO country code (e.g. "GB"). The "premium" plan unlocks every zoo whose
  /// country matches the user's chosen home country.
  final String country;

  /// Whether [lat]/[lng] are a real, hand-verified centre (`coords_set: true` in
  /// the data). When false, any coordinates present are placeholders and must not
  /// be trusted — the zoo is omitted from the map and can't be GPS-verified.
  final bool coordsSet;

  final String lastUpdated;

  const Zoo({
    required this.id,
    this.name = '',
    this.lat,
    this.lng,
    this.radiusM = 500,
    this.country = '',
    this.coordsSet = false,
    this.lastUpdated = '',
  });

  /// True only when real coordinates exist *and* have been confirmed. Use this
  /// for anything that places the zoo geographically (map pins, verification).
  bool get hasLocation => coordsSet && lat != null && lng != null;

  factory Zoo.fromJson(Map<String, dynamic> json) {
    // supports new ("id"/"name") and old ("pack_id"/"zoo_name") keys
    final id = (json['id'] as String?) ?? (json['pack_id'] as String?) ?? '';

    double? lat;
    double? lng;
    final loc = json['location'];
    if (loc is Map) {
      final la = loc['lat'];
      final ln = loc['lng'];
      lat = la is num ? la.toDouble() : null;
      lng = ln is num ? ln.toDouble() : null;
    }

    final r = json['radius_m'];

    return Zoo(
      id: id,
      name: (json['name'] as String?) ?? (json['zoo_name'] as String?) ?? '',
      lat: lat,
      lng: lng,
      radiusM: r is num ? r.toDouble() : 500,
      country: (json['country'] as String?) ?? '',
      coordsSet: json['coords_set'] == true,
      lastUpdated: (json['last_updated'] as String?) ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        if (lat != null && lng != null) 'location': {'lat': lat, 'lng': lng},
        'radius_m': radiusM,
        'coords_set': coordsSet,
        'country': country,
        'last_updated': lastUpdated,
      };
}
