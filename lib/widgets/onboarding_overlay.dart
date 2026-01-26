import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class OnboardingOverlay extends StatefulWidget {
  final GlobalKey storeOpeningKey;
  final GlobalKey quickSaleKey;
  final GlobalKey inventoryKey;
  final GlobalKey closingKey;

  const OnboardingOverlay({
    super.key,
    required this.storeOpeningKey,
    required this.quickSaleKey,
    required this.inventoryKey,
    required this.closingKey,
  });

  static const String _onboardingKey = 'onboarding_completed';

  /// Verifica si el onboarding ya fue completado
  static Future<bool> isCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_onboardingKey) ?? false;
  }

  /// Marca el onboarding como completado
  static Future<void> markAsCompleted() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, true);
  }

  /// Resetea el onboarding (útil para testing)
  static Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_onboardingKey, false);
  }

  @override
  State<OnboardingOverlay> createState() => _OnboardingOverlayState();
}

class _OnboardingOverlayState extends State<OnboardingOverlay>
    with SingleTickerProviderStateMixin {
  int _currentStep = 0;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  Offset? _widgetPosition;
  Size? _widgetSize;
  bool _isPositionCalculated = false;

  final List<OnboardingStep> _steps = [
    OnboardingStep(
      title: 'Paso 1: Apertura de Punto',
      description:
          'Lo primero que debes hacer es abrir el punto de venta. Presiona el botón "Apertura de Punto" para iniciar tu turno.',
      icon: Icons.storefront,
      color: Colors.blue,
    ),
    OnboardingStep(
      title: 'Paso 2: Venta Rápida',
      description:
          'Una vez abierto el punto de venta, puedes realizar ventas rápidas desde el mostrador usando este botón.',
      icon: Icons.payments,
      color: Color(0xFFEC6D13),
    ),
    OnboardingStep(
      title: 'Paso 3: Control de Inventario',
      description:
          'Usa esta opción para controlar y gestionar el inventario de productos durante tu turno.',
      icon: Icons.inventory_2,
      color: Colors.orange,
    ),
    OnboardingStep(
      title: 'Paso 4: Cierre de Día',
      description:
          'Al finalizar tu turno, presiona este botón para cerrar el día y completar todas las operaciones.',
      icon: Icons.lock_clock,
      color: Colors.grey,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );
    _animationController.forward();
    // Calcular posición después de que el widget esté construido
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _calculateWidgetPosition();
    });
  }

  void _calculateWidgetPosition() {
    final currentKey = _getCurrentKey();
    if (currentKey == null) {
      setState(() {
        _isPositionCalculated = false;
        _widgetPosition = null;
        _widgetSize = null;
      });
      return;
    }

    final RenderBox? renderBox =
        currentKey.currentContext?.findRenderObject() as RenderBox?;
    
    if (renderBox != null && renderBox.attached) {
      try {
        final position = renderBox.localToGlobal(Offset.zero);
        final size = renderBox.size;
        setState(() {
          _widgetPosition = position;
          _widgetSize = size;
          _isPositionCalculated = true;
        });
      } catch (e) {
        // Si hay error, intentar de nuevo en el siguiente frame
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _calculateWidgetPosition();
          }
        });
      }
    } else {
      // Si el widget aún no está renderizado, esperar un frame más
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateWidgetPosition();
        }
      });
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _nextStep() {
    if (_currentStep < _steps.length - 1) {
      setState(() {
        _currentStep++;
        _isPositionCalculated = false;
        _widgetPosition = null;
        _widgetSize = null;
      });
      _animationController.reset();
      _animationController.forward();
      // Recalcular posición para el nuevo paso
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateWidgetPosition();
      });
    } else {
      _completeOnboarding();
    }
  }

  void _previousStep() {
    if (_currentStep > 0) {
      setState(() {
        _currentStep--;
        _isPositionCalculated = false;
        _widgetPosition = null;
        _widgetSize = null;
      });
      _animationController.reset();
      _animationController.forward();
      // Recalcular posición para el nuevo paso
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _calculateWidgetPosition();
      });
    }
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    await OnboardingOverlay.markAsCompleted();
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  GlobalKey? _getCurrentKey() {
    switch (_currentStep) {
      case 0:
        return widget.storeOpeningKey;
      case 1:
        return widget.quickSaleKey;
      case 2:
        return widget.inventoryKey;
      case 3:
        return widget.closingKey;
      default:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentStepData = _steps[_currentStep];

    // Si aún no se ha calculado la posición, intentar calcularla
    if (!_isPositionCalculated) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _calculateWidgetPosition();
        }
      });
    }

    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Dark overlay
          GestureDetector(
            onTap: _nextStep,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              color: Colors.black.withOpacity(0.7),
            ),
          ),
          // Highlighted widget - solo mostrar si tenemos posición y tamaño
          if (_widgetPosition != null && _widgetSize != null)
            Positioned(
              left: _widgetPosition!.dx - 8,
              top: _widgetPosition!.dy - 8,
              child: Container(
                width: _widgetSize!.width + 16,
                height: _widgetSize!.height + 16,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: currentStepData.color,
                    width: 4,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentStepData.color.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    color: currentStepData.color.withOpacity(0.1),
                  ),
                ),
              ),
            ),
          // Instruction card
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: _buildInstructionCard(currentStepData, isDark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInstructionCard(OnboardingStep step, bool isDark) {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF2C2018) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: step.color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  step.icon,
                  color: step.color,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      step.title,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF1B130D),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_currentStep + 1} de ${_steps.length}',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark
                            ? const Color(0xFFA8A29E)
                            : const Color(0xFF78716C),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Description
          Text(
            step.description,
            style: TextStyle(
              fontSize: 16,
              height: 1.5,
              color: isDark
                  ? const Color(0xFFD6D3D1)
                  : const Color(0xFF44403C),
            ),
          ),
          const SizedBox(height: 24),
          // Progress indicator
          Row(
            children: List.generate(
              _steps.length,
              (index) => Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(
                    right: index < _steps.length - 1 ? 8 : 0,
                  ),
                  decoration: BoxDecoration(
                    color: index <= _currentStep
                        ? step.color
                        : (isDark
                            ? const Color(0xFF44403C)
                            : const Color(0xFFE7E5E4)),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),
          // Buttons
          Row(
            children: [
              // Skip button
              TextButton(
                onPressed: _skipOnboarding,
                child: Text(
                  'Omitir',
                  style: TextStyle(
                    color: isDark
                        ? const Color(0xFFA8A29E)
                        : const Color(0xFF78716C),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const Spacer(),
              // Previous button
              if (_currentStep > 0)
                TextButton(
                  onPressed: _previousStep,
                  child: Text(
                    'Anterior',
                    style: TextStyle(
                      color: step.color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              if (_currentStep > 0) const SizedBox(width: 12),
              // Next/Finish button
              ElevatedButton(
                onPressed: _nextStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: step.color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: Text(
                  _currentStep < _steps.length - 1 ? 'Siguiente' : 'Finalizar',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class OnboardingStep {
  final String title;
  final String description;
  final IconData icon;
  final Color color;

  OnboardingStep({
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
  });
}
