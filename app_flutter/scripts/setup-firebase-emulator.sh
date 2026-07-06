#!/bin/bash
# Sets up Firebase emulator for local development
# Requires: npm, Java 11+
# Usage: ./scripts/setup-firebase-emulator.sh

set -euo pipefail

echo "==> Setting up Firebase Emulator..."

# Install firebase-tools if not present
if ! command -v firebase &>/dev/null; then
  echo "==> Installing firebase-tools..."
  npm install -g firebase-tools
fi

# Create firebase.json if it doesn't exist
if [ ! -f firebase.json ]; then
  echo "==> Creating firebase.json..."
  cat > firebase.json <<'JSON'
{
  "firestore": {
    "rules": "firestore.rules"
  },
  "emulators": {
    "firestore": {
      "port": 8080
    },
    "ui": {
      "enabled": true
    }
  }
}
JSON
fi

# Create empty firestore.rules if it doesn't exist
if [ ! -f firestore.rules ]; then
  echo "==> Creating firestore.rules..."
  cat > firestore.rules <<'RULES'
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
RULES
fi

echo "==> Starting Firebase Emulator on port 8080..."
firebase emulators:start --only firestore &
EMULATOR_PID=$!
echo "==> Emulator PID: $EMULATOR_PID"

# Wait for emulator to be ready
echo "==> Waiting for emulator to be ready..."
for i in $(seq 1 30); do
  if curl -s http://localhost:8080 > /dev/null 2>&1; then
    echo "==> Emulator ready!"
    break
  fi
  sleep 1
done

echo "==> Seeding test data..."
python3 scripts/seed-firebase-data.py

echo "==> Done! Emulator running on port 8080 (PID: $EMULATOR_PID)"
echo "==> Run 'kill $EMULATOR_PID' to stop the emulator"
