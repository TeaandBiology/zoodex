import 'dart:math';

import 'package:geolocator/geolocator.dart';

import '../models/verification.dart';
import '../models/zoo.dart';
import 'reference_data.dart';

/// Confirms whether the user is physically at a zoo, to grant a visit the
/// `verified` badge. Raw coordinates are used only to compute distance and are
/// then discarded — nothing positional is ever returned or stored.
class VerificationService {
  VerificationService._();

  static double _rad(double d) => d * pi / 180.0;

  static double _haversineM(double lat1, double lon1, double lat2, double lon2) {
    const earthR = 6371000.0;
    final dLat = _rad(lat2 - lat1);
    final dLon = _rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    return 2 * earthR * asin(min(1.0, sqrt(a)));
  }

  static Future<Position?> _getFix() async {
    if (!await Geolocator.isLocationServiceEnabled()) return null;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return null;
    }
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (_) {
      return null;
    }
  }

  /// Confirm presence at a specific (already-chosen) zoo.
  static Future<VerificationResult> verifyAtZoo(String zooId) async {
    final zoo = ReferenceData.instance.zooById(zooId);
    if (zoo == null || !zoo.hasLocation) {
      // No coordinates set for this zoo yet — can't verify.
      return const VerificationResult(VerificationStatus.skipped);
    }
    final fix = await _getFix();
    if (fix == null) {
      return const VerificationResult(VerificationStatus.unverified);
    }
    final d = _haversineM(fix.latitude, fix.longitude, zoo.lat!, zoo.lng!);
    final within = (d - fix.accuracy) <= zoo.radiusM;
    return VerificationResult(
      within ? VerificationStatus.verified : VerificationStatus.unverified,
      detectedZooId: within ? zoo.id : null,
    );
  }

  /// Auto-detect the nearest qualifying zoo (for a future GPS-first flow).
  static Future<VerificationResult> detectNearestZoo() async {
    final fix = await _getFix();
    if (fix == null) {
      return const VerificationResult(VerificationStatus.unverified);
    }
    Zoo? best;
    var bestD = double.infinity;
    for (final z in ReferenceData.instance.zoos) {
      if (!z.hasLocation) continue;
      final d = _haversineM(fix.latitude, fix.longitude, z.lat!, z.lng!);
      if ((d - fix.accuracy) <= z.radiusM && d < bestD) {
        best = z;
        bestD = d;
      }
    }
    if (best == null) {
      return const VerificationResult(VerificationStatus.unverified);
    }
    return VerificationResult(VerificationStatus.verified, detectedZooId: best.id);
  }
}
