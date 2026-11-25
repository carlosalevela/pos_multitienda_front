import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'providers/auth_provider.dart';
import 'services/barcode_service.dart';
import 'services/update_service.dart';
import 'screens/login/login_screen.dart';
import 'screens/home/home_screen.dart';
import 'core/constants.dart';
import 'providers/pos_provider.dart';
import 'providers/inventario_provider.dart';
import 'providers/reportes_provider.dart';
import 'providers/caja_provider.dart';
import 'providers/contabilidad_provider.dart';
import 'providers/tienda_provider.dart';
import 'providers/cliente_provider.dart';
import 'providers/proveedores_provider.dart';
import 'providers/devoluciones_provider.dart';
import 'providers/empresa_provider.dart';
import 'providers/config_provider.dart';
import 'providers/notificaciones_provider.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

/// Inicializa SharedPreferences con recuperación automática si el archivo
/// de preferencias está corrupto (FormatException al parsearlo).
Future<void> _initPrefs() async {
  try {
    await SharedPreferences.getInstance();
  } on FormatException {
    // Archivo corrupto — eliminar y reinicializar
    try {
      final dir = await getApplicationSupportDirectory();
      final file = File('${dir.path}/shared_preferences.json');
      if (await file.exists()) await file.delete();
    } catch (_) {}
    try {
      await SharedPreferences.getInstance();
    } catch (_) {}
  } catch (_) {}
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _initPrefs();
  // Mantener barra de estado visible con iconos oscuros
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark,
  ));
  BarcodeService.instance.init();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => PosProvider()),
        ChangeNotifierProvider(create: (_) => InventarioProvider()),
        ChangeNotifierProvider(create: (_) => ReportesProvider()),
        ChangeNotifierProvider(create: (_) => CajaProvider()),
        ChangeNotifierProvider(create: (_) => ContabilidadProvider()),
        ChangeNotifierProvider(create: (_) => TiendaProvider()),
        ChangeNotifierProvider(create: (_) => ClienteProvider()),
        ChangeNotifierProvider(create: (_) => ProveedoresProvider()),
        ChangeNotifierProvider(create: (_) => DevolucionesProvider()),
        ChangeNotifierProvider(create: (_) => EmpresaProvider()),
        ChangeNotifierProvider(create: (_) => ConfigProvider()),
        ChangeNotifierProvider(create: (_) => NotificacionesProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title:        'POS Multitienda',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('es', 'CO'),
        Locale('en', 'US'),
      ],
      locale: const Locale('es', 'CO'),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(Constants.primaryColor),
        ),
        useMaterial3: true,
      ),
      // SafeArea global con fondo blanco: evita el borde negro en el área de la barra de estado
      builder: (context, child) => ColoredBox(
        color: Colors.white,
        child: SafeArea(child: child!),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  /// Tienda para la que ya se pidió la config en esta sesión.
  int? _configPedidaPara;

  @override
  void initState() {
    super.initState();
    // Verificar si hay sesión guardada
    Future.microtask(() =>
      context.read<AuthProvider>().checkSession()
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.isLoggedIn) {
      // Al cerrar sesión se permite volver a pedirla en el próximo login.
      _configPedidaPara = null;
      return const LoginScreen();
    }

    // La config de la tienda —y con ella las cuentas bancarias— se carga aquí,
    // al entrar, y no solo al abrir el POS. Antes, cualquier pantalla que
    // necesitara cuentas (abonar, bonos, caja) las veía vacías hasta que el
    // usuario pasara por el POS.
    final tiendaId = auth.tiendaId;
    if (tiendaId > 0 && _configPedidaPara != tiendaId) {
      _configPedidaPara = tiendaId;
      final empresaId = int.tryParse(auth.empresaId);
      final config = context.read<ConfigProvider>();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        config.asegurarCargada(tiendaId, empresaId: empresaId);
      });
    }

    return const HomeScreen();
  }
}

