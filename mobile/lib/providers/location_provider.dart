import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'auth_provider.dart';

/// A simple latitude/longitude pair.
class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint(this.lat, this.lng);
}

/// Resolves the user's current coordinates for geographic search.
///
/// Tries the device GPS first (requesting permission as needed) and falls back
/// to the coordinates stored on the user's profile when location services are
/// unavailable or denied. Returns `null` if no location can be determined.
final currentLocationProvider = FutureProvider<LatLngPoint?>((ref) async {
  final profile = ref.watch(currentProfileProvider);

  LatLngPoint? profileFallback;
  if (profile?.locationLat != null && profile?.locationLng != null) {
    profileFallback = LatLngPoint(profile!.locationLat!, profile.locationLng!);
  }

  try {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) return profileFallback;

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      return profileFallback;
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
      ),
    );
    return LatLngPoint(position.latitude, position.longitude);
  } catch (_) {
    return profileFallback;
  }
});
