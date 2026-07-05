/// Minimal geohash implementation for postal-centroid radius search.
///
/// Books store `geohash` of their owner's postal centroid; searching within a
/// radius queries the centroid's cell plus its 8 neighbors with `startAt`/
/// `endAt` prefix ranges (Phase G).
class Geohash {
  static const String _base32 = '0123456789bcdefghjkmnpqrstuvwxyz';

  /// Encodes [lat], [lng] to a geohash of [precision] characters.
  static String encode(double lat, double lng, {int precision = 9}) {
    var latRange = const [-90.0, 90.0];
    var lngRange = const [-180.0, 180.0];
    var isEven = true;
    var bit = 0;
    var ch = 0;
    final buffer = StringBuffer();

    while (buffer.length < precision) {
      if (isEven) {
        final mid = (lngRange[0] + lngRange[1]) / 2;
        if (lng >= mid) {
          ch |= 1 << (4 - bit);
          lngRange = [mid, lngRange[1]];
        } else {
          lngRange = [lngRange[0], mid];
        }
      } else {
        final mid = (latRange[0] + latRange[1]) / 2;
        if (lat >= mid) {
          ch |= 1 << (4 - bit);
          latRange = [mid, latRange[1]];
        } else {
          latRange = [latRange[0], mid];
        }
      }

      isEven = !isEven;
      if (bit < 4) {
        bit++;
      } else {
        buffer.write(_base32[ch]);
        bit = 0;
        ch = 0;
      }
    }

    return buffer.toString();
  }

  /// Decodes a geohash to its cell-center (lat, lng).
  static (double, double) decode(String hash) {
    var latRange = [-90.0, 90.0];
    var lngRange = [-180.0, 180.0];
    var isEven = true;

    for (final c in hash.split('')) {
      final cd = _base32.indexOf(c);
      for (var mask = 16; mask > 0; mask >>= 1) {
        if (isEven) {
          final mid = (lngRange[0] + lngRange[1]) / 2;
          if (cd & mask != 0) {
            lngRange[0] = mid;
          } else {
            lngRange[1] = mid;
          }
        } else {
          final mid = (latRange[0] + latRange[1]) / 2;
          if (cd & mask != 0) {
            latRange[0] = mid;
          } else {
            latRange[1] = mid;
          }
        }
        isEven = !isEven;
      }
    }

    return (
      (latRange[0] + latRange[1]) / 2,
      (lngRange[0] + lngRange[1]) / 2,
    );
  }

  /// The cell itself plus its 8 surrounding cells at the same precision.
  static List<String> neighborsOf(String hash) {
    final precision = hash.length;
    final (lat, lng) = decode(hash);

    // Cell sizes at this precision
    final latErr = 180.0 / (1 << (((precision * 5) / 2).floor() + 1));
    final lngErr = 360.0 / (1 << (((precision * 5) / 2).ceil() + 1));

    final cells = <String>{};
    for (final dLat in [-2 * latErr, 0.0, 2 * latErr]) {
      for (final dLng in [-2 * lngErr, 0.0, 2 * lngErr]) {
        final nLat = (lat + dLat).clamp(-90.0, 90.0);
        var nLng = lng + dLng;
        if (nLng > 180) nLng -= 360;
        if (nLng < -180) nLng += 360;
        cells.add(encode(nLat, nLng, precision: precision));
      }
    }
    return cells.toList();
  }

  /// Picks the geohash precision whose cell size comfortably covers a search
  /// radius (cell + neighbors span ≥ the radius).
  static int precisionForRadiusKm(double radiusKm) {
    // Approximate min cell dimension (km) per precision level.
    const cellKm = <int, double>{
      1: 2500,
      2: 630,
      3: 78,
      4: 20,
      5: 2.4,
      6: 0.61,
      7: 0.076,
      8: 0.019,
    };
    for (final entry in cellKm.entries.toList().reversed) {
      if (entry.value >= radiusKm) return entry.key;
    }
    return 1;
  }
}
