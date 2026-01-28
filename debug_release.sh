#!/bin/bash

# Script para debuggear problemas en modo release
# Uso: ./debug_release.sh

echo "🔍 Iniciando diagnóstico de la app en modo release..."
echo ""

# 1. Limpiar build anterior
echo "1️⃣ Limpiando build anterior..."
flutter clean

# 2. Obtener dependencias
echo ""
echo "2️⃣ Obteniendo dependencias..."
flutter pub get

# 3. Construir APK en modo release con verbose
echo ""
echo "3️⃣ Construyendo APK en modo release..."
flutter build apk --release --verbose

# 4. Instrucciones para ver logs
echo ""
echo "✅ Build completado!"
echo ""
echo "📱 Para ver los logs en tiempo real después de instalar la app:"
echo "   adb logcat | grep -E '(flutter|AndroidRuntime|FATAL)'"
echo ""
echo "📱 Para ver todos los logs de Flutter:"
echo "   adb logcat | grep flutter"
echo ""
echo "📱 Para limpiar logs y ver solo los nuevos:"
echo "   adb logcat -c && adb logcat | grep flutter"
echo ""
