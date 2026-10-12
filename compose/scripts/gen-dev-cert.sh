#!/usr/bin/env bash
# Genera el certificado TLS autofirmado de desarrollo que usa nginx
# (compose/certify-nginx/certs/). Idempotente: no sobrescribe si ya existe.
set -euo pipefail

CERT_DIR="$(cd "$(dirname "$0")/.." && pwd)/certify-nginx/certs"
mkdir -p "$CERT_DIR"

if [ -f "$CERT_DIR/localhost-cert.pem" ] && [ -f "$CERT_DIR/localhost-key.pem" ]; then
  echo "Ya existe un certificado en $CERT_DIR — no se regenera."
  exit 0
fi

# MSYS_NO_PATHCONV evita que Git Bash en Windows reescriba "/CN=localhost" como ruta.
MSYS_NO_PATHCONV=1 openssl req -x509 -newkey rsa:2048 \
  -keyout "$CERT_DIR/localhost-key.pem" -out "$CERT_DIR/localhost-cert.pem" \
  -days 3650 -nodes -subj "/CN=localhost" \
  -addext "subjectAltName=DNS:localhost,IP:127.0.0.1"
echo "Certificado generado en $CERT_DIR"
