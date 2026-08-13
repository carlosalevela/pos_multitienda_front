class Constants {
  // LOCAL: 'http://127.0.0.1:8000/api'
  // PRODUCCION: 'https://<tu-proyecto>.up.railway.app/api'
  static const String baseUrl = String.fromEnvironment(
    'API_URL',
    defaultValue: 'http://127.0.0.1:8000/api',
  );

  static const String moneda = '\$';

  // Colores del sistema
  static const int primaryColor    = 0xFF1E88E5;
  static const int secondaryColor  = 0xFF26C6DA;
  static const int backgroundColor = 0xFFF5F5F5;
  static const int successColor    = 0xFF43A047;
  static const int errorColor      = 0xFFE53935;
}