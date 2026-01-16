import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'services/supabase_service.dart';
import 'screens/dashboard_page.dart';
import 'screens/factory_dashboard_page.dart';
import 'screens/deliveries_page.dart';
import 'models/user.dart';
import 'models/sucursal.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar datos de localización para intl
  try {
    await initializeDateFormatting('es', null);
  } catch (e) {
    print('Error inicializando locale español: $e');
    // Intentar inicializar locale por defecto
    try {
      await initializeDateFormatting('es_ES', null);
    } catch (e2) {
      print('Error inicializando locale es_ES: $e2');
    }
  }

  // Inicializar Supabase y base de datos local
  await SupabaseService.initialize();

  // Sincronizar usuarios en background (no bloquea el inicio de la app)
  SupabaseService.syncUsersToLocal().catchError((e) {
    print('Error en sincronización inicial: $e');
  });

  runApp(const ChurrosApp());
}

class ChurrosApp extends StatelessWidget {
  const ChurrosApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Churros POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC6D13),
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF8F7F6),
        textTheme: GoogleFonts.workSansTextTheme(),
      ),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFFEC6D13),
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF221810),
        textTheme: GoogleFonts.workSansTextTheme(ThemeData.dark().textTheme),
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

        // Login exitoso
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Inicio de sesión exitoso'),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            ),
          );

          // Verificar el tipo de usuario
          if (appUser.type == 2) {
            // Usuario tipo 2: Dashboard de fábrica
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder:
                    (context) => FactoryDashboardPage(currentUser: appUser),
              ),
            );
          } else if (appUser.type == 3) {
            // Usuario tipo 3: Domicilios y Entregas
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const DeliveriesPage()),
            );
          } else if (appUser.type == 1) {
            // Usuario tipo 1: Dashboard de punto de venta
            // Obtener la sucursal del usuario
            Sucursal? sucursal;
            if (appUser.sucursalId != null) {
              sucursal = await SupabaseService.getSucursalById(
                appUser.sucursalId!,
              );
            }

            // Si no tiene sucursal asignada o no se encontró, obtener la principal
            sucursal ??= await SupabaseService.getSucursalPrincipal();

            if (sucursal != null) {
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
            } else {
              // Si no hay sucursal disponible, mostrar error
              if (mounted) {
                _showError(
                  'No se pudo obtener la información de la sucursal. Contacta al administrador.',
                );
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
