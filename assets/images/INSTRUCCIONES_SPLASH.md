# Instrucciones para Configurar el Splash Screen

## 📸 Agregar tu Imagen

Para que el splash screen funcione correctamente, necesitas agregar tu imagen en la siguiente ubicación:

### Flutter Assets (Recomendado)
Coloca tu imagen con el nombre `splash_logo.png` en:
```
assets/images/splash_logo.png
```

**Recomendaciones:**
- Formato: PNG (con fondo transparente o del color del splash)
- Tamaño: 512x512 px o mayor (cuadrada 1:1)
- El sistema la escalará automáticamente según el dispositivo

### Android Nativo (Opcional)
Si quieres usar recursos nativos de Android, también puedes colocar la imagen en:
- `android/app/src/main/res/mipmap-mdpi/splash_logo.png` (48x48 dp)
- `android/app/src/main/res/mipmap-hdpi/splash_logo.png` (72x72 dp)
- `android/app/src/main/res/mipmap-xhdpi/splash_logo.png` (96x96 dp)
- `android/app/src/main/res/mipmap-xxhdpi/splash_logo.png` (144x144 dp)
- `android/app/src/main/res/mipmap-xxxhdpi/splash_logo.png` (192x192 dp)

## ✅ Configuración Actual

- ✅ `pubspec.yaml` configurado para usar assets
- ✅ `launch_background.xml` configurado para Android
- ✅ Widget `SplashScreen` creado en `main.dart`

## 🚀 Próximos Pasos

1. Coloca tu imagen `splash_logo.png` en `assets/images/`
2. Ejecuta `flutter pub get` (si es necesario)
3. Ejecuta `flutter run` para ver el splash screen

## 📝 Nota

Si no agregas la imagen, se mostrará un icono placeholder automáticamente.

