// lib/core/dashboard_cache.dart
// Cachés de dashboards — se limpian al hacer logout para evitar
// que un usuario vea datos del anterior en el mismo dispositivo.

final Map<String, Map<String, dynamic>> dashboardAdminCache = {};
final Map<String, Map<String, dynamic>> cajaDashboardCache  = {};
List<Map<String, dynamic>>?             cajaTiendasCache;

void clearAllDashboardCaches() {
  dashboardAdminCache.clear();
  cajaDashboardCache.clear();
  cajaTiendasCache = null;
}
