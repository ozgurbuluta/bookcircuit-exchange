import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';

/// The postal centroid + human label for a neighborhood.
class NeighborhoodResult {
  final String postalCode;
  final String areaLabel;
  final double lat;
  final double lng;

  const NeighborhoodResult({
    required this.postalCode,
    required this.areaLabel,
    required this.lat,
    required this.lng,
  });
}

/// Neighborhood setup logic (mock #3e, spec §5).
///
/// Privacy rules baked in:
/// - GPS is never stored; the "use my location" button only FILLS the postal
///   code field ([postalCodeFromDeviceLocation]).
/// - Neighbors only ever see the [composeAreaLabel] output — never a street.
class NeighborhoodService {
  /// Languages offered as quick chips during setup (mock #3e).
  static const List<String> quickLanguages = [
    'Türkçe',
    'English',
    'Deutsch',
    'Français',
  ];

  /// Extended list behind "+ More".
  static const List<String> moreLanguages = [
    'Español',
    'Italiano',
    'Nederlands',
    'Polski',
    'Português',
    'Русский',
    'العربية',
    'فارسی',
    '中文',
    '日本語',
  ];

  /// Builds "Moda, Kadıköy" from placemark parts. Street-level fields are
  /// deliberately not accepted.
  static String? composeAreaLabel({
    String? subLocality,
    String? locality,
    String? adminArea,
  }) {
    final parts = [subLocality, locality]
        .where((p) => p != null && p.trim().isNotEmpty)
        .cast<String>()
        .toList();
    if (parts.isEmpty && adminArea != null && adminArea.trim().isNotEmpty) {
      return adminArea.trim();
    }
    if (parts.isEmpty) return null;
    return parts.join(', ');
  }

  /// Loose plausibility check before hitting the geocoder: 3–10 chars of
  /// letters/digits with at most one internal space or hyphen.
  static bool isPlausiblePostalCode(String value) {
    final v = value.trim();
    return RegExp(r'^[A-Za-z0-9]{2,6}([ -][A-Za-z0-9]{1,4})?$').hasMatch(v);
  }

  /// Preselect setup languages from the device locale (spec §5).
  static List<String> preselectLanguages(Locale locale) {
    switch (locale.languageCode) {
      case 'tr':
        return ['Türkçe'];
      case 'de':
        return ['Deutsch'];
      case 'fr':
        return ['Français'];
      case 'en':
      default:
        return ['English'];
    }
  }

  /// Geocodes a postal code to its centroid + area label.
  /// Returns null when the code can't be resolved.
  Future<NeighborhoodResult?> resolvePostalCode(String postalCode) async {
    final code = postalCode.trim();
    if (!isPlausiblePostalCode(code)) return null;

    try {
      final locations = await locationFromAddress(code);
      if (locations.isEmpty) return null;
      final location = locations.first;

      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      final placemark = placemarks.isNotEmpty ? placemarks.first : null;

      final label = composeAreaLabel(
            subLocality: placemark?.subLocality,
            locality: placemark?.locality,
            adminArea: placemark?.administrativeArea,
          ) ??
          code;

      return NeighborhoodResult(
        postalCode: code,
        areaLabel: label,
        lat: location.latitude,
        lng: location.longitude,
      );
    } catch (_) {
      return null;
    }
  }

  /// Reads the device location ONCE to prefill the postal-code field.
  /// The coordinates are discarded immediately — never persisted (spec §5).
  Future<String?> postalCodeFromDeviceLocation() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(accuracy: LocationAccuracy.medium),
      );

      final placemarks = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      return placemarks.isNotEmpty ? placemarks.first.postalCode : null;
    } catch (_) {
      return null;
    }
  }
}

/// Riverpod handle — overridable in widget tests.
final neighborhoodServiceProvider =
    Provider<NeighborhoodService>((ref) => NeighborhoodService());
