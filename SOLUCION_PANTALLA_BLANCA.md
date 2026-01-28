# Solución para Pantalla en Blanco en Modo Release

## Cambios Realizados

He mejorado el manejo de errores en `main.dart` para evitar que la app se quede en blanco cuando hay errores en modo release:

### 1. **Manejo Global de Errores**
   - Agregado `FlutterError.onError` para capturar errores de Flutter
   - Agregado `PlatformDispatcher.instance.onError` para errores asíncronos
   - Agregado `ErrorWidget.builder` para mostrar errores visualmente

### 2. **Inicializaciones con Try-Catch**
   - Todas las inicializaciones ahora están envueltas en try-catch
   - Las inicializaciones no críticas (notificaciones, listeners) no bloquean el inicio
   - Se usa `debugPrint` en lugar de `print` para mejor logging

### 3. **Manejo Seguro de Google Fonts**
   - Agregado manejo de errores para Google Fonts
   - Si falla, usa fuentes por defecto del sistema

## Cómo Diagnosticar el Problema

### Opción 1: Ver Logs con ADB (Recomendado)

1. **Conecta tu teléfono** por USB y habilita depuración USB
2. **Instala la app** en el teléfono
3. **Abre una terminal** y ejecuta:

```bash
# Ver logs de Flutter en tiempo real
adb logcat | grep flutter

# O ver todos los logs relevantes
adb logcat | grep -E '(flutter|AndroidRuntime|FATAL)'

# Limpiar logs anteriores y ver solo nuevos
adb logcat -c && adb logcat | grep flutter
```

4. **Abre la app** en el teléfono y observa los logs

### Opción 2: Usar el Script de Debug

```bash
./debug_release.sh
```

Este script:
- Limpia el build anterior
- Obtiene dependencias
- Construye el APK con verbose logging
- Te da instrucciones para ver logs

### Opción 3: Build con Debugging Habilitado

Para ver errores más claros, puedes construir un APK con información de debugging:

```bash
flutter build apk --release --split-debug-info=./debug-info
```

Luego instala y revisa los logs.

## Posibles Causas del Problema

### 1. **Google Fonts sin Conexión**
   - Google Fonts necesita internet la primera vez
   - **Solución**: Ya implementada - usa fuentes por defecto si falla

### 2. **Error en Inicialización de Supabase**
   - Puede fallar si no hay conexión o credenciales incorrectas
   - **Solución**: Ya implementada - la app continúa aunque falle

### 3. **Error en Base de Datos Local (SQLite)**
   - Puede fallar si hay problemas de permisos
   - **Verificar**: Revisa los logs para ver si hay errores de SQLite

### 4. **Problemas con Assets**
   - Si falta `assets/images/splash_logo.png`, puede causar problemas
   - **Solución**: Ya hay un `errorBuilder` que maneja esto

## Próximos Pasos

1. **Reconstruye el APK**:
   ```bash
   flutter clean
   flutter pub get
   flutter build apk --release
   ```

2. **Instala y prueba** en el teléfono

3. **Revisa los logs** usando ADB para ver qué error específico está ocurriendo

4. **Si el problema persiste**, comparte los logs que veas con `adb logcat` para identificar el error exacto

## Verificación Rápida

Para verificar que los cambios funcionan, puedes:

1. Construir el APK:
   ```bash
   flutter build apk --release
   ```

2. Instalar en el teléfono:
   ```bash
   adb install build/app/outputs/flutter-apk/app-release.apk
   ```

3. Ver logs mientras abres la app:
   ```bash
   adb logcat -c && adb logcat | grep -E '(flutter|ERROR|FATAL)'
   ```

4. Abre la app y observa los logs. Deberías ver mensajes como:
   - `✅ Supabase inicializado correctamente`
   - `✅ Servicio de notificaciones inicializado`
   - `✅ Inicialización completada, iniciando app...`

Si ves errores, los logs te dirán exactamente qué está fallando.
