#!/usr/bin/env bash
set -Eeuo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
RUN_DIR="$ROOT_DIR/.run"
mkdir -p "$RUN_DIR"

FLUTTER_BIN="${FLUTTER_BIN:-/home/chinopc/development/flutter/bin/flutter}"
ANDROID_SDK="${ANDROID_SDK:-$HOME/Android/Sdk}"
ADB_BIN="${ADB_BIN:-$ANDROID_SDK/platform-tools/adb}"
EMULATOR_BIN="${EMULATOR_BIN:-$ANDROID_SDK/emulator/emulator}"

AVD_NAME="${ANDROID_AVD:-UleamMed_Test}"
DEVICE_ID="${ANDROID_DEVICE:-emulator-5554}"
BACKEND_PORT="${BACKEND_PORT:-8000}"
API_URL="${ULEAMMED_API_URL:-http://10.0.2.2:$BACKEND_PORT}"

cd "$ROOT_DIR"

if [[ ! -x "$FLUTTER_BIN" ]]; then
  FLUTTER_BIN="flutter"
fi

if [[ ! -x "$ADB_BIN" ]]; then
  echo "No encontre adb en $ADB_BIN"
  exit 1
fi

if [[ ! -x "$EMULATOR_BIN" ]]; then
  echo "No encontre emulator en $EMULATOR_BIN"
  exit 1
fi

if [[ ! -f "$ROOT_DIR/.env" ]]; then
  echo "Falta .env en la raiz del proyecto."
  exit 1
fi

if [[ ! -x "$ROOT_DIR/.venv/bin/python" ]]; then
  echo "Falta .venv. Crea el entorno e instala backend/requirements.txt."
  exit 1
fi

echo "Verificando backend..."
if ! curl -fsS "http://127.0.0.1:$BACKEND_PORT/health" >/dev/null 2>&1; then
  echo "Levantando backend en puerto $BACKEND_PORT..."
  set -a
  # shellcheck disable=SC1091
  source "$ROOT_DIR/.env"
  set +a
  setsid "$ROOT_DIR/.venv/bin/python" -m uvicorn backend.app.main:app \
    --host 0.0.0.0 \
    --port "$BACKEND_PORT" \
    --reload \
    >"$RUN_DIR/backend.log" 2>&1 < /dev/null &
  echo "$!" > "$RUN_DIR/backend.pid"

  for _ in {1..40}; do
    if curl -fsS "http://127.0.0.1:$BACKEND_PORT/health" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

curl -fsS "http://127.0.0.1:$BACKEND_PORT/health" >/dev/null

echo "Verificando Android Emulator..."
"$ADB_BIN" start-server >/dev/null

if ! "$ADB_BIN" devices | grep -q "^$DEVICE_ID[[:space:]]*device"; then
  if ! pgrep -f "qemu-system.*-avd $AVD_NAME" >/dev/null; then
    echo "Abriendo emulador $AVD_NAME..."
    setsid "$EMULATOR_BIN" -avd "$AVD_NAME" \
      -netdelay none \
      -netspeed full \
      -no-snapshot-load \
      -no-boot-anim \
      >"$RUN_DIR/emulator.log" 2>&1 < /dev/null &
    echo "$!" > "$RUN_DIR/emulator.pid"
  fi

  "$ADB_BIN" wait-for-device
fi

echo "Esperando arranque completo de Android..."
for _ in {1..90}; do
  boot_completed="$("$ADB_BIN" -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
  if [[ "$boot_completed" == "1" ]]; then
    break
  fi
  sleep 1
done

boot_completed="$("$ADB_BIN" -s "$DEVICE_ID" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r' || true)"
if [[ "$boot_completed" != "1" ]]; then
  echo "Android no termino de arrancar. Revisa $RUN_DIR/emulator.log"
  exit 1
fi

"$ADB_BIN" -s "$DEVICE_ID" shell input keyevent 82 >/dev/null 2>&1 || true

echo "Cerrando flutter run anterior si quedo abierto..."
pkill -f "flutter_tools.snapshot run -d $DEVICE_ID" >/dev/null 2>&1 || true
sleep 1

echo "Preparando Flutter..."
cd "$ROOT_DIR/mobile"
"$FLUTTER_BIN" pub get

echo "Lanzando app en $DEVICE_ID con API $API_URL"
exec "$FLUTTER_BIN" run -d "$DEVICE_ID" --dart-define=ULEAMMED_API_URL="$API_URL"
