import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/material.dart';

import 'notification_service.dart';
import 'supabase_service.dart';
import 'factory_section_tracker.dart';
import 'factory_session_service.dart';
import 'app_keys.dart';

/// Global realtime listener that fires "noisy" notifications when new orders arrive
/// while the user is inside any Factory screen.
class FactoryRealtimeOrdersListener {
  FactoryRealtimeOrdersListener._();

  static bool _started = false;
  static RealtimeChannel? _factoryOrdersChannel;
  static RealtimeChannel? _clientOrdersChannel;

  static Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      // Load persisted session flag (factory vs non-factory)
      await FactorySessionService.ensureInitialized();

      _factoryOrdersChannel =
          SupabaseService.client
              .channel('factory_orders_global_listener_v1')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'pedidos_fabrica',
                callback: (payload) async {
                  // "Signed in factory" requirement: only notify if the current
                  // session is a factory session. We keep FactorySectionTracker
                  // as a secondary guard to avoid spamming if the app is used
                  // outside factory flow.
                  final isFactorySession =
                      FactorySessionService.isFactorySessionSync ||
                      await FactorySessionService.isFactorySession();
                  if (!isFactorySession) return;

                  if (!FactorySectionTracker.isInFactory) return;

                  final newOrder = payload.newRecord;
                  final sucursalNombre =
                      (newOrder['sucursal_nombre'] as String?) ?? 'Punto de Venta';

                  final productos = newOrder['productos'];
                  int? cantidadProductos;
                  if (productos is List) {
                    cantidadProductos = productos.length;
                  }

                  // In-app "push up" (snackbar)
                  rootScaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(
                        cantidadProductos != null
                            ? 'Nuevo pedido desde $sucursalNombre ($cantidadProductos productos)'
                            : 'Nuevo pedido desde $sucursalNombre',
                      ),
                      backgroundColor: const Color(0xFFEC6D13),
                      duration: const Duration(seconds: 4),
                    ),
                  );

                  // Noisy system notification (banner + sound)
                  await NotificationService.showNewFactoryOrderNotification(
                    sucursal: sucursalNombre,
                    cantidadProductos: cantidadProductos,
                    noisy: true,
                  );
                },
              )
              .subscribe();

      _clientOrdersChannel =
          SupabaseService.client
              .channel('client_orders_global_listener_v1')
              .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'pedidos_clientes',
                callback: (payload) async {
                  final isFactorySession =
                      FactorySessionService.isFactorySessionSync ||
                      await FactorySessionService.isFactorySession();
                  if (!isFactorySession) return;

                  if (!FactorySectionTracker.isInFactory) return;

                  final newOrder = payload.newRecord;
                  final clienteNombre =
                      (newOrder['cliente_nombre'] as String?) ??
                      (newOrder['nombre_cliente'] as String?) ??
                      'Cliente';

                  final productos = newOrder['productos'];
                  int? cantidadProductos;
                  if (productos is List) {
                    cantidadProductos = productos.length;
                  }

                  rootScaffoldMessengerKey.currentState?.showSnackBar(
                    SnackBar(
                      content: Text(
                        cantidadProductos != null
                            ? 'Nuevo pedido de $clienteNombre ($cantidadProductos productos)'
                            : 'Nuevo pedido de $clienteNombre',
                      ),
                      backgroundColor: Colors.green,
                      duration: const Duration(seconds: 4),
                    ),
                  );

                  await NotificationService.showNewClientOrderNotification(
                    cliente: clienteNombre,
                    cantidadProductos: cantidadProductos,
                    noisy: true,
                  );
                },
              )
              .subscribe();
    } catch (_) {
      // If something fails here, we don't want to crash the app.
    }
  }

  static Future<void> stop() async {
    _started = false;
    await _factoryOrdersChannel?.unsubscribe();
    await _clientOrdersChannel?.unsubscribe();
    _factoryOrdersChannel = null;
    _clientOrdersChannel = null;
  }
}

