/// Environment configuration for the app
class Env {
  // Supabase configuration - these should be overridden in production
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://your-project.supabase.co',
  );

  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue: 'your-anon-key',
  );

  // Google Maps API Key
  static const String googleMapsApiKey = String.fromEnvironment(
    'GOOGLE_MAPS_API_KEY',
    defaultValue: '',
  );

  // App configuration
  static const String appName = 'Turtle Turning Pages';
  static const String appVersion = '1.0.0';

  // Default search radius in kilometers
  static const double defaultSearchRadius = 5.0;
  static const double minSearchRadius = 1.0;
  static const double maxSearchRadius = 100.0;
}
