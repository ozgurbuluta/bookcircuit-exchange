/// Environment configuration for the app
class Env {
  // App configuration
  static const String appName = 'Turtle Turning Pages';
  static const String appVersion = '1.0.0';

  // Default search radius in kilometers
  static const double defaultSearchRadius = 5.0;
  static const double minSearchRadius = 1.0;
  static const double maxSearchRadius = 100.0;

  // Google Maps API Key (for maps features)
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );
}
