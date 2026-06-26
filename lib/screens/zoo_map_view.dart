import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../l10n/app_localizations.dart';
import '../models/entitlement.dart';
import '../models/zoo.dart';

/// Map view for the Zoos tab. Shows OpenStreetMap tiles with a pin over every
/// zoo that has confirmed coordinates ([Zoo.hasLocation], i.e. `coords_set:true`),
/// tries to centre on the user's current location, and lets the user pan/zoom and
/// tap a pin to open that zoo. Tiles require an internet connection.
class ZooMapView extends StatefulWidget {
  /// All zoos (unfiltered); the view itself drops any without confirmed coords.
  final List<Zoo> zoos;

  /// Used to colour pins locked vs unlocked.
  final Entitlement entitlement;

  /// Called when a pin is tapped — the parent decides whether to open the zoo or
  /// show the unlock sheet (same behaviour as the list).
  final void Function(Zoo zoo) onOpenZoo;

  const ZooMapView({
    super.key,
    required this.zoos,
    required this.entitlement,
    required this.onOpenZoo,
  });

  @override
  State<ZooMapView> createState() => _ZooMapViewState();
}

class _ZooMapViewState extends State<ZooMapView> {
  final MapController _map = MapController();

  /// Zoos with real, confirmed coordinates — the only ones that get a pin.
  late final List<Zoo> _mappable =
      widget.zoos.where((z) => z.hasLocation).toList(growable: false);

  LatLng? _me; // current location, once known
  bool _locating = false;
  bool _ready = false; // map has been laid out at least once

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      _ready = true;
      final located = await _locate(recentre: true);
      if (!located && mounted) _fitToZoos();
    });
  }

  /// Default camera before we know anything: centre of the mappable zoos, or a
  /// rough UK centre if there are none.
  LatLng get _initialCentre {
    if (_mappable.isEmpty) return const LatLng(54.0, -2.0);
    final lat = _mappable.map((z) => z.lat!).reduce((a, b) => a + b) /
        _mappable.length;
    final lng = _mappable.map((z) => z.lng!).reduce((a, b) => a + b) /
        _mappable.length;
    return LatLng(lat, lng);
  }

  double get _initialZoom => _mappable.length <= 1 ? 9 : 5;

  /// Frame all zoo pins in view.
  void _fitToZoos() {
    if (!_ready || _mappable.isEmpty) return;
    final pts = _mappable.map((z) => LatLng(z.lat!, z.lng!)).toList();
    if (pts.length == 1) {
      _map.move(pts.first, 11);
      return;
    }
    _map.fitCamera(
      CameraFit.coordinates(
        coordinates: pts,
        padding: const EdgeInsets.all(64),
        maxZoom: 13,
      ),
    );
  }

  /// Fetch the current position (requesting permission if needed). Returns true
  /// if a location was obtained. Never throws; failures just fall back.
  Future<bool> _locate({bool recentre = false}) async {
    if (_locating) return false;
    setState(() => _locating = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return false;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.denied ||
          perm == LocationPermission.deniedForever) {
        return false;
      }
      final pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
      if (!mounted) return false;
      final me = LatLng(pos.latitude, pos.longitude);
      setState(() => _me = me);
      if (recentre && _ready) _map.move(me, 11);
      return true;
    } catch (_) {
      return false;
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Marker _zooMarker(Zoo zoo) {
    final unlocked = widget.entitlement.grantsAccessTo(zoo);
    final color = unlocked
        ? Theme.of(context).colorScheme.primary
        : Theme.of(context).colorScheme.outline;
    return Marker(
      point: LatLng(zoo.lat!, zoo.lng!),
      width: 140,
      height: 48,
      alignment: Alignment.topCenter,
      child: GestureDetector(
        onTap: () => widget.onOpenZoo(zoo),
        child: Tooltip(
          message: zoo.name,
          child: Icon(
            unlocked ? Icons.location_on : Icons.location_off,
            color: color,
            size: 40,
            shadows: const [Shadow(color: Colors.black54, blurRadius: 3)],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final markers = [for (final z in _mappable) _zooMarker(z)];
    if (_me != null) {
      markers.add(Marker(
        point: _me!,
        width: 24,
        height: 24,
        child: const _MeDot(),
      ));
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _map,
          options: MapOptions(
            initialCenter: _initialCentre,
            initialZoom: _initialZoom,
            minZoom: 2,
            maxZoom: 18,
            interactionOptions:
                const InteractionOptions(flags: InteractiveFlag.all),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.zoodex.app',
            ),
            MarkerLayer(markers: markers),
            const RichAttributionWidget(
              attributions: [
                TextSourceAttribution('© OpenStreetMap contributors'),
              ],
            ),
          ],
        ),
        if (_mappable.isEmpty)
          Positioned(
            top: 12,
            left: 12,
            right: 12,
            child: _MapNotice(AppLocalizations.of(context).zooMapNoCoords),
          ),
        Positioned(
          right: 12,
          bottom: 24,
          child: FloatingActionButton.small(
            heroTag: 'zooMapLocate',
            tooltip: AppLocalizations.of(context).zooMapCentreOnMe,
            onPressed: _locating ? null : () => _locate(recentre: true),
            child: _locating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
          ),
        ),
      ],
    );
  }
}

/// Blue "you are here" dot.
class _MeDot extends StatelessWidget {
  const _MeDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
        boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 4)],
      ),
    );
  }
}

class _MapNotice extends StatelessWidget {
  final String text;
  const _MapNotice(this.text);

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
      borderRadius: BorderRadius.circular(8),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(text, style: Theme.of(context).textTheme.bodySmall),
      ),
    );
  }
}
