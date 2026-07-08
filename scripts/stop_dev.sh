#!/usr/bin/env bash
set -Eeuo pipefail

ANDROID_SDK="${ANDROID_SDK:-$HOME/Android/Sdk}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK/platform-tools/adb}"
DEVICE_ID="${ANDROID_DEVICE:-emulator-5554}"

echo "Cerrando Flutter..."
pkill -f "flutter_tools.snapshot run -d $DEVICE_ID" >/dev/null 2>&1 || true

echo "Cerrando backend Uvicorn..."
pkill -f "uvicorn backend.app.main:app" >/dev/null 2>&1 || true

if [[ "${1:-}" == "--emulator" ]]; then
  echo "Cerrando emulador Android..."
  if [[ -x "$ADB_BIN" ]]; then
    "$ADB_BIN" -s "$DEVICE_ID" emu kill >/dev/null 2>&1 || true
  fi
fi

echo "Listo."
