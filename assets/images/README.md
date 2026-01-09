# Imágenes del Splash Screen

Para configurar el splash screen de la aplicación:

## Android

Coloca tu imagen del splash screen en las siguientes carpetas con el nombre `splash_logo.png`:

- `android/app/src/main/res/mipmap-mdpi/splash_logo.png` (48x48 dp)
- `android/app/src/main/res/mipmap-hdpi/splash_logo.png` (72x72 dp)
- `android/app/src/main/res/mipmap-xhdpi/splash_logo.png` (96x96 dp)
- `android/app/src/main/res/mipmap-xxhdpi/splash_logo.png` (144x144 dp)
- `android/app/src/main/res/mipmap-xxxhdpi/splash_logo.png` (192x192 dp)

**Recomendación**: Usa una imagen cuadrada (1:1) con fondo transparente o del mismo color que el fondo del splash screen.

## iOS

Para iOS, la imagen debe agregarse en:
- `ios/Runner/Assets.xcassets/LaunchImage.imageset/`

## Tamaños recomendados

- **Android**: Mínimo 192x192 px para xxxhdpi (puedes usar la misma imagen en todas las carpetas, Android la escalará)
- **iOS**: 1024x1024 px o según los tamaños requeridos en LaunchImage.imageset

