import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/supabase_service.dart';
import 'services/notification_service.dart';
import 'services/app_keys.dart';
import 'services/factory_realtime_orders_listener.dart';
import 'services/factory_session_service.dart';
import 'services/sync_queue_service.dart';
import 'screens/store/dashboard_page.dart';
import 'screens/factory/factory_dashboard_page.dart';
import 'screens/store/deliveries_page.dart';
import 'models/user.dart';
import 'models/sucursal.dart';

void main() async {
  // Configurar manejo de errores globales
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    if (kReleaseMode) {
      // En release, también loguear a consola
      debugPrint('ERROR: ${details.exception}');
      debugPrint('Stack: ${details.stack}');
    }
  };

  // Manejar errores de zona (async errors)
  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('ZONE ERROR: $error');
    debugPrint('Stack: $stack');
    return true;
  };

  // Configurar ErrorWidget para mostrar errores visualmente
  ErrorWidget.builder = (FlutterErrorDetails details) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Error al iniciar la aplicación',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  kDebugMode
                      ? details.toString()
                      : 'Por favor, reinicia la aplicación',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  };

  WidgetsFlutterBinding.ensureInitialized();

  try {
    // Inicializar datos de localización para intl
    try {
      await initializeDateFormatting('es', null);
    } catch (e) {
      debugPrint('Error inicializando locale español: $e');
      // Intentar inicializar locale por defecto
      try {
        await initializeDateFormatting('es_ES', null);
      } catch (e2) {
        debugPrint('Error inicializando locale es_ES: $e2');
      }
    }

    // Inicializar Supabase y base de datos local
    try {
      await SupabaseService.initialize();
      debugPrint('✅ Supabase inicializado correctamente');
    } catch (e, stackTrace) {
      debugPrint('❌ Error inicializando Supabase: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque falle, la app puede funcionar offline
    }

    // Inicializar servicio de notificaciones (no crítico)
    try {
      await NotificationService.initialize();
      debugPrint('✅ Servicio de notificaciones inicializado');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error inicializando notificaciones: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque falle
    }

    // Inicializar servicio de cola de sincronización
    try {
      await SyncQueueService.initialize();
      debugPrint('✅ SyncQueueService inicializado');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error inicializando SyncQueueService: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque falle
    }

    // Load persisted session (factory vs non-factory)
    try {
      await FactorySessionService.ensureInitialized();
      debugPrint('✅ FactorySessionService inicializado');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error inicializando FactorySessionService: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque falle
    }

    // Global listener: noisy notifications while user is inside Factory screens (no crítico)
    try {
      await FactoryRealtimeOrdersListener.start();
      debugPrint('✅ FactoryRealtimeOrdersListener iniciado');
    } catch (e, stackTrace) {
      debugPrint('⚠️ Error iniciando FactoryRealtimeOrdersListener: $e');
      debugPrint('Stack trace: $stackTrace');
      // Continuar aunque falle
    }

    // Sincronizar usuarios y sucursales en background (no bloquea el inicio de la app)
    SupabaseService.syncUsersToLocal().catchError((e) {
      debugPrint('⚠️ Error en sincronización inicial de usuarios: $e');
    });
    SupabaseService.syncSucursalesToLocal().catchError((e) {
      debugPrint('⚠️ Error en sincronización inicial de sucursales: $e');
    });

    debugPrint('✅ Inicialización completada, iniciando app...');
    runApp(const ChurrosApp());
  } catch (e, stackTrace) {
    debugPrint('❌ ERROR CRÍTICO en main(): $e');
    debugPrint('Stack trace: $stackTrace');

    // Aún así intentar iniciar la app con un error widget
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Error crítico al iniciar',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    kDebugMode
                        ? e.toString()
                        : 'Por favor, reinstala la aplicación',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ChurrosApp extends StatelessWidget {
  const ChurrosApp({super.key});

  // Helper para obtener textTheme con manejo de errores
  TextTheme _getTextTheme([TextTheme? base]) {
    try {
      return GoogleFonts.workSansTextTheme(base);
    } catch (e) {
      debugPrint('⚠️ Error cargando Google Fonts: $e');
      // Retornar textTheme por defecto si falla
      return base ?? const TextTheme();
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Churros POS',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC6D13),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F6),
        textTheme: _getTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC6D13),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF221810),
        textTheme: _getTextTheme(ThemeData.dark().textTheme),
      ),
      themeMode: ThemeMode.system,
      home: const SplashScreen(),
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToLogin();
  }

  Future<void> _navigateToLogin() async {
    // Esperar un tiempo mínimo para mostrar el splash (opcional)
    await Future.delayed(const Duration(seconds: 2));

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF221810) : Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Splash Image
            Image.asset(
              'assets/images/splash_logo.png',
              width: 200,
              height: 200,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) {
                // Si no existe la imagen, mostrar un placeholder
                return Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    color: const Color(0xFFEC6D13).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    Icons.bakery_dining,
                    size: 100,
                    color: const Color(0xFFEC6D13),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            // Loading indicator (opcional)
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFEC6D13)),
            ),
          ],
        ),
      ),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _pinController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _obscurePin = true;
  final bool _isConnected = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final userIdentifier = _emailController.text.trim();
      final accessKey = _pinController.text.trim();

      if (userIdentifier.isEmpty || accessKey.isEmpty) {
        _showError('Por favor, completa todos los campos');
        return;
      }

      final user = await SupabaseService.verifyUserCredentials(
        userIdentifier,
        accessKey,
      );

      if (user != null) {
        // Convertir a AppUser
        final appUser = AppUser.fromJson(user);

        // Persist "factory session" flag for realtime notifications
        await FactorySessionService.setFactorySession(appUser.type == 2);

        // Sincronizar sucursales ANTES de intentar obtenerlas (solo si hay conexión)
        // Si no hay conexión, usar datos locales si están disponibles
        try {
          final hasConnection = await SupabaseService.checkConnection();
          if (hasConnection) {
            await SupabaseService.syncSucursalesToLocal();
            print('✅ Sincronización de sucursales completada');
          } else {
            print('ℹ️ Sin conexión, usando datos locales de sucursales');
          }
        } catch (e) {
          print('⚠️ Error sincronizando sucursales después del login: $e');
          // Continuar aunque falle la sincronización, puede haber datos locales
        }

        // Verificar el tipo de usuario
        if (appUser.type == 2) {
          // Usuario tipo 2: Dashboard de fábrica
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Inicio de sesión exitoso'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => FactoryDashboardPage(currentUser: appUser),
              ),
            );
          }
        } else if (appUser.type == 3) {
          // Usuario tipo 3: Domicilios y Entregas
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Inicio de sesión exitoso'),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
              ),
            );
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DeliveriesPage()),
            );
          }
        } else if (appUser.type == 1) {
          // Usuario tipo 1: Dashboard de punto de venta
          // Obtener la sucursal del usuario
          Sucursal? sucursal;

          // Intentar obtener la sucursal asignada al usuario
          if (appUser.sucursalId != null) {
            print(
              '🔍 Intentando obtener sucursal con ID: ${appUser.sucursalId}',
            );
            try {
              sucursal = await SupabaseService.getSucursalById(
                appUser.sucursalId!,
              );
              if (sucursal != null) {
                print('✅ Sucursal obtenida: ${sucursal.nombre}');
              } else {
                print(
                  '⚠️ No se encontró sucursal con ID: ${appUser.sucursalId}',
                );
              }
            } catch (e, stackTrace) {
              print('❌ Error obteniendo sucursal por ID: $e');
              print('Stack trace: $stackTrace');
            }
          } else {
            print('ℹ️ Usuario no tiene sucursal asignada');
          }

          // Si no tiene sucursal asignada o no se encontró, obtener la principal
          if (sucursal == null) {
            print('🔍 Intentando obtener sucursal principal');
            try {
              sucursal = await SupabaseService.getSucursalPrincipal();
              if (sucursal != null) {
                print('✅ Sucursal principal obtenida: ${sucursal.nombre}');
              } else {
                print('⚠️ No se encontró sucursal principal activa');
              }
            } catch (e, stackTrace) {
              print('❌ Error obteniendo sucursal principal: $e');
              print('Stack trace: $stackTrace');
            }
          }

          if (sucursal != null) {
            // Login exitoso - mostrar mensaje solo después de obtener la sucursal
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: const Text('Inicio de sesión exitoso'),
                  backgroundColor: Colors.green,
                  behavior: SnackBarBehavior.floating,
                ),
              );
              // Navegar al dashboard con la información del usuario y sucursal
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder:
                      (context) => DashboardPage(
                        sucursal: sucursal!,
                        currentUser: appUser,
                      ),
                ),
              );
            }
          } else {
            // Si no hay sucursal disponible, mostrar error con más detalles
            if (mounted) {
              // Verificar si hay conexión para dar un mensaje más específico
              final hasConnection = await SupabaseService.checkConnection();
              String errorMsg;

              if (!hasConnection) {
                // Sin conexión y sin datos locales
                errorMsg =
                    appUser.sucursalId != null
                        ? 'Sin conexión a internet y no se encontraron datos locales de la sucursal asignada (ID: ${appUser.sucursalId}). Conecta a internet al menos una vez para sincronizar los datos, o contacta al administrador.'
                        : 'Sin conexión a internet y no se encontraron datos locales de sucursales. Conecta a internet al menos una vez para sincronizar los datos, o contacta al administrador.';
              } else {
                // Con conexión pero no se encontró la sucursal
                errorMsg =
                    appUser.sucursalId != null
                        ? 'No se pudo obtener la información de la sucursal asignada (ID: ${appUser.sucursalId}) ni la sucursal principal. Verifica que la sucursal exista en la base de datos o contacta al administrador.'
                        : 'No se pudo obtener la información de la sucursal principal. Verifica que exista al menos una sucursal activa en la base de datos o contacta al administrador.';
              }

              _showError(errorMsg);
            }
          }
        } else {
          // Tipo de usuario no reconocido
          if (mounted) {
            _showError(
              'No tienes permisos para acceder a esta aplicación. Contacta al administrador.',
            );
          }
        }
      } else {
        // Credenciales incorrectas
        if (mounted) {
          _showError('Credenciales incorrectas. Verifica tu usuario y PIN.');
        }
      }
    } catch (e) {
      if (mounted) {
        _showError('Error de conexión. Por favor, intenta de nuevo.');
        print('Error en login: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = const Color(0xFFEC6D13);
    final mediaQuery = MediaQuery.of(context);
    final screenSize = mediaQuery.size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final keyboardHeight = mediaQuery.viewInsets.bottom;
    final isKeyboardVisible = keyboardHeight > 0;

    // Responsive values
    final isSmallScreen = screenWidth < 600;
    final isLargeScreen = screenWidth >= 1200;
    final horizontalPadding =
        isSmallScreen ? 24.0 : (isLargeScreen ? 48.0 : 32.0);
    final maxContentWidth = isLargeScreen ? 500.0 : double.infinity;
    final iconSize = isSmallScreen ? 80.0 : 100.0;
    final titleFontSize = isSmallScreen ? 32.0 : 40.0;
    final spacing = isSmallScreen ? 24.0 : 32.0;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            // Main Content
            SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      screenHeight -
                      mediaQuery.padding.top -
                      mediaQuery.padding.bottom -
                      (isKeyboardVisible ? keyboardHeight : 0),
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxContentWidth),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          height: isKeyboardVisible ? 20 : 60,
                        ), // Space for connectivity chip
                        // Main Content Container
                        Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: horizontalPadding,
                            vertical: isKeyboardVisible ? 20 : 40,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Header / Branding
                              Column(
                                children: [
                                  Container(
                                    width: iconSize,
                                    height: iconSize,
                                    decoration: BoxDecoration(
                                      color: primaryColor.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(
                                      Icons.bakery_dining,
                                      size: iconSize * 0.5,
                                      color: primaryColor,
                                    ),
                                  ),
                                  SizedBox(height: isKeyboardVisible ? 16 : 24),
                                  Text(
                                    'Churros POS',
                                    style: TextStyle(
                                      fontSize: titleFontSize,
                                      fontWeight: FontWeight.bold,
                                      color:
                                          isDark
                                              ? Colors.white
                                              : const Color(0xFF1C1917),
                                      letterSpacing: -0.5,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Bienvenido, inicia tu turno.',
                                    style: TextStyle(
                                      fontSize: isSmallScreen ? 14 : 16,
                                      fontWeight: FontWeight.w500,
                                      color:
                                          isDark
                                              ? const Color(0xFFA8A29E)
                                              : const Color(0xFF78716C),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: isKeyboardVisible ? 20 : 40),
                              // Login Form
                              Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    // Email/User Input
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            'Correo o Usuario',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFD6D3D1)
                                                      : const Color(0xFF44403C),
                                            ),
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _emailController,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Por favor, ingresa tu correo o usuario';
                                            }
                                            return null;
                                          },
                                          style: TextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1C1917),
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'usuario@churros.com',
                                            hintStyle: TextStyle(
                                              color: const Color(0xFFA8A29E),
                                            ),
                                            prefixIcon: Icon(
                                              Icons.person_outline,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C),
                                            ),
                                            filled: true,
                                            fillColor:
                                                isDark
                                                    ? const Color(0xFF1C1917)
                                                    : Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF44403C,
                                                        )
                                                        : const Color(
                                                          0xFFE7E5E4,
                                                        ),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF44403C,
                                                        )
                                                        : const Color(
                                                          0xFFE7E5E4,
                                                        ),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 20,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: spacing),
                                    // PIN Input
                                    Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: const EdgeInsets.only(
                                            left: 4,
                                            bottom: 8,
                                          ),
                                          child: Text(
                                            'PIN de Acceso',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFD6D3D1)
                                                      : const Color(0xFF44403C),
                                            ),
                                          ),
                                        ),
                                        TextFormField(
                                          controller: _pinController,
                                          obscureText: _obscurePin,
                                          keyboardType: TextInputType.number,
                                          inputFormatters: [
                                            FilteringTextInputFormatter
                                                .digitsOnly,
                                          ],
                                          validator: (value) {
                                            if (value == null ||
                                                value.trim().isEmpty) {
                                              return 'Por favor, ingresa tu PIN';
                                            }
                                            if (value.length < 4) {
                                              return 'El PIN debe tener al menos 4 dígitos';
                                            }
                                            return null;
                                          },
                                          style: TextStyle(
                                            fontSize: 16,
                                            color:
                                                isDark
                                                    ? Colors.white
                                                    : const Color(0xFF1C1917),
                                            letterSpacing: 8,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: '••••',
                                            hintStyle: TextStyle(
                                              color: const Color(0xFFA8A29E),
                                              letterSpacing: 8,
                                            ),
                                            prefixIcon: Icon(
                                              Icons.lock_outline,
                                              color:
                                                  isDark
                                                      ? const Color(0xFFA8A29E)
                                                      : const Color(0xFF78716C),
                                            ),
                                            suffixIcon: IconButton(
                                              icon: Icon(
                                                _obscurePin
                                                    ? Icons.visibility_outlined
                                                    : Icons
                                                        .visibility_off_outlined,
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFFA8A29E,
                                                        )
                                                        : const Color(
                                                          0xFF78716C,
                                                        ),
                                                size: 20,
                                              ),
                                              onPressed: () {
                                                setState(() {
                                                  _obscurePin = !_obscurePin;
                                                });
                                              },
                                            ),
                                            filled: true,
                                            fillColor:
                                                isDark
                                                    ? const Color(0xFF1C1917)
                                                    : Colors.white,
                                            border: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF44403C,
                                                        )
                                                        : const Color(
                                                          0xFFE7E5E4,
                                                        ),
                                              ),
                                            ),
                                            enabledBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color:
                                                    isDark
                                                        ? const Color(
                                                          0xFF44403C,
                                                        )
                                                        : const Color(
                                                          0xFFE7E5E4,
                                                        ),
                                              ),
                                            ),
                                            focusedBorder: OutlineInputBorder(
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                              borderSide: BorderSide(
                                                color: primaryColor,
                                                width: 2,
                                              ),
                                            ),
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 20,
                                                ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(
                                      height: isKeyboardVisible ? 24 : 32,
                                    ),
                                    // Main Action Button
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        onPressed:
                                            _isLoading ? null : _handleLogin,
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: primaryColor,
                                          foregroundColor: Colors.white,
                                          padding: EdgeInsets.symmetric(
                                            vertical: isSmallScreen ? 18 : 20,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          elevation: 4,
                                          disabledBackgroundColor: primaryColor
                                              .withOpacity(0.6),
                                        ),
                                        child:
                                            _isLoading
                                                ? SizedBox(
                                                  height:
                                                      isSmallScreen ? 18 : 20,
                                                  width:
                                                      isSmallScreen ? 18 : 20,
                                                  child: const CircularProgressIndicator(
                                                    strokeWidth: 2,
                                                    valueColor:
                                                        AlwaysStoppedAnimation<
                                                          Color
                                                        >(Colors.white),
                                                  ),
                                                )
                                                : Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Text(
                                                      'INGRESAR',
                                                      style: TextStyle(
                                                        fontSize:
                                                            isSmallScreen
                                                                ? 15
                                                                : 16,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        letterSpacing: 1,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 8),
                                                    Icon(
                                                      Icons.arrow_forward,
                                                      size:
                                                          isSmallScreen
                                                              ? 18
                                                              : 20,
                                                    ),
                                                  ],
                                                ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Footer Area
                        if (!isKeyboardVisible)
                          Padding(
                            padding: EdgeInsets.all(isSmallScreen ? 20 : 24),
                            child: Text(
                              'v2.1.0 • ID Dispositivo: #4029',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 12,
                                fontWeight: FontWeight.w500,
                                color:
                                    isDark
                                        ? const Color(0xFF78716C)
                                        : const Color(0xFFA8A29E),
                                fontFamily: 'monospace',
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        if (isKeyboardVisible) SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // Connectivity Chip
            Positioned(
              top: isSmallScreen ? 16 : 24,
              right: horizontalPadding,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color:
                      isDark
                          ? const Color(0xFF1C1917).withOpacity(0.8)
                          : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color:
                        isDark
                            ? const Color(0xFF44403C)
                            : const Color(0xFFE7E5E4),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.wifi,
                      size: 20,
                      color:
                          _isConnected
                              ? Colors.green.shade600
                              : Colors.red.shade600,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _isConnected ? 'Conectado' : 'Desconectado',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color:
                            isDark
                                ? const Color(0xFFD6D3D1)
                                : const Color(0xFF44403C),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
