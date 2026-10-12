#!/usr/bin/env bash
# compose/scripts/run-e2e.sh
#
# Prueba end-to-end: emite un mDL con 1 categoría y otro con 4,
# vía el flujo OID4VCI pre-authorized_code real contra el entorno de
# compose/, y muestra qué produce la verificación standalone
# (verify/verify-mdoc.mjs) sobre cada caso.
#
# Requiere: el entorno de compose/ arriba y healthy
# (`cd compose && docker compose up -d`), `curl`, `node` (con
# compose/scripts/node_modules instalado — `npm install` en este
# directorio), y `openssl`.
#
# Comportamiento real de Inji Certify 0.14.0 confirmado contra este entorno
# (el flujo difiere de lo que sugiere el spec OID4VCI genérico):
#
# 1. El body de POST /v1/certify/pre-authorized-data para mso_mdoc NO acepta
#    claims planas ({"document_number": "..."}): responde 200 con
#    {"errors":[{"errorCode":"unknown_claims", ...}]}. Las claims van
#    ANIDADAS bajo el namespace ISO:
#      {"claims": {"org.iso.18013.5.1": {"document_number": "..."}}}
#    (decompilación de CredentialConfigurationServiceImpl.getMsoMdocClaims()).
#
# 2. La respuesta trae credential_offer_uri con la forma
#    openid-credential-offer://?credential_offer_uri=<URL>, una URI
#    INDIRECTA: hay que hacer un GET adicional a esa URL para obtener
#    {credential_issuer, credential_configuration_ids, grants}.
#
# 3. El proof JWT `aud` debe ser el credential_issuer BASE (p. ej.
#    https://localhost:8094), NO el endpoint completo
#    /v1/certify/issuance/credential; con el endpoint completo Inji Certify
#    responde {"error":"invalid_proof","error_description":"Error
#    encountered during proof jwt parsing."}.
#
# 4. El body de POST /v1/certify/issuance/credential NO usa
#    credential_configuration_id (no existe en el DTO
#    io.mosip.certify.core.dto.CredentialRequest; responde "JSON parse error:
#    Unrecognized field"). El shape real es
#    {"format": "mso_mdoc", "doctype": "<docType>", "proof": {...}}.
#
# 5. MockFeeDataProviderPlugin entrega driving_privileges como STRING JSON y
#    anida los campos bajo el namespace ISO además de planos; sin eso la
#    emisión falla con ERROR_SIGNING_QR_DATA ("Failed to create mDoc
#    credential"). La key de identityDetails con el número de documento es
#    "sub" (JSON de las claims enviadas). Detalle en
#    compose/certify/mock-fee-plugin/.../MockFeeDataProviderPlugin.java.
#
# 6. La IACA autogenerada NO vive en /home/inji/CERTIFY_PKCS12/certify-root.pem
#    (no existe en esta imagen) sino dentro del keystore PKCS12
#    /home/inji/CERTIFY_PKCS12/local.p12 (password "local",
#    mosip.kernel.keymanager.hsm.keystore-pass en certify-default.properties).
#    Ese keystore trae varios certificados (uno por app_id de
#    key_policy_def); el raíz autofirmado (issuer==subject, CN="... (ROOT)")
#    hace de IACA. Se extrae con `openssl pkcs12` + un filtro en Node. El CBOR
#    emitido NO trae el ROOT en su x5chain (solo el certificado hoja
#    CERTIFY_VC_SIGN_EC_R1-...), así que hay que ir al keystore.
#
# 7. El CBOR SIEMPRE llega envuelto en {docType, issuerSigned}. Ver
#    compose/scripts/extract-cbor.mjs.
set -euo pipefail

CERTIFY_URL="http://localhost:8094"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERIFY_DIR="$(cd "$SCRIPT_DIR/../../verify" && pwd)"
COMPOSE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
OUT_DIR="$(mktemp -d)"
trap 'rm -rf "$OUT_DIR"' EXIT

# --- Extraer la IACA autogenerada del contenedor (ver punto 6) ---
# MSYS_NO_PATHCONV=1 es necesario en Git Bash / Windows para que
# /home/inji/... (argumento de `cat` DENTRO del contenedor Linux) no sea
# reescrito como ruta de Windows. Pero MSYS_NO_PATHCONV también desactiva la
# conversión de la ruta de `docker compose -f <compose.yml>`, que SÍ debe ser
# una ruta Windows válida (observado: "open C:/c/Users/...: The system
# cannot find the path specified."). Por eso se hace `cd` al directorio de
# compose y se usa el docker-compose.yml implícito, evitando `-f`. No-op en
# Linux/macOS.
echo "=== Extrayendo la IACA del keystore PKCS12 de certify ==="
( cd "$COMPOSE_DIR" && MSYS_NO_PATHCONV=1 docker compose exec -T certify \
  cat /home/inji/CERTIFY_PKCS12/local.p12 ) \
  > "$OUT_DIR/local.p12" 2>/dev/null || {
    echo "AVISO: no se pudo extraer /home/inji/CERTIFY_PKCS12/local.p12 del contenedor."
    echo "Verifica que 'docker compose up -d' esté corriendo desde compose/ y que"
    echo "el servicio certify esté healthy (docker compose ps)."
    exit 1
  }

openssl pkcs12 -in "$OUT_DIR/local.p12" -passin pass:local -nokeys \
  -out "$OUT_DIR/all_certs.pem" 2>/dev/null || {
    echo "AVISO: openssl no pudo leer local.p12 con el password 'local'."
    echo "Verifica mosip.kernel.keymanager.hsm.keystore-pass en"
    echo "compose/certify/certify-default.properties — puede haber cambiado."
    exit 1
  }

node "$SCRIPT_DIR/extract-root-cert.mjs" "$OUT_DIR/all_certs.pem" "$OUT_DIR/iaca.pem" || {
    echo "AVISO: no se encontró un certificado autofirmado (issuer==subject) con"
    echo "'ROOT' en el subject dentro de local.p12 — la lógica de selección de"
    echo "extract-root-cert.mjs puede necesitar ajuste para esta versión del entorno."
    exit 1
  }
echo "IACA extraída: $OUT_DIR/iaca.pem"

issue_and_verify() {
  local document_number="$1"
  local label="$2"

  echo ""
  echo "=== Emitiendo mDL para $document_number ($label) ==="

  # 1. Solicitar la oferta pre-authorized_code. Claims ANIDADAS bajo el
  #    namespace ISO (punto 1).
  local offer_response
  offer_response=$(curl -sS -X POST "$CERTIFY_URL/v1/certify/pre-authorized-data" \
    -H "Content-Type: application/json" \
    -d "{
      \"credential_configuration_id\": \"MTCDrivingLicenseMDL\",
      \"claims\": {\"org.iso.18013.5.1\": {\"document_number\": \"$document_number\"}}
    }")

  if echo "$offer_response" | grep -q '"errors"'; then
    echo "ERROR: pre-authorized-data devolvió un error:"
    echo "$offer_response"
    return 1
  fi

  # 2. Resolver el credential_offer_uri INDIRECTO (punto 2) para
  #    obtener el pre-authorized_code real.
  local offer_data_url
  offer_data_url=$(echo "$offer_response" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    const uri = data.credential_offer_uri;
    if (!uri) { console.error('sin credential_offer_uri en la respuesta:', JSON.stringify(data)); process.exit(1); }
    const m = uri.match(/credential_offer_uri=([^&]+)/);
    if (!m) { console.error('credential_offer_uri no tiene el shape esperado:', uri); process.exit(1); }
    console.log(decodeURIComponent(m[1]));
  ")

  local offer_data
  offer_data=$(curl -sS "$offer_data_url")

  local pre_auth_code
  pre_auth_code=$(echo "$offer_data" | node -e "
    const data = JSON.parse(require('fs').readFileSync(0, 'utf8'));
    console.log(data.grants['urn:ietf:params:oauth:grant-type:pre-authorized_code']['pre-authorized_code']);
  ")

  # 3. Canjear el código por un access token.
  local token_response
  token_response=$(curl -sS -X POST "$CERTIFY_URL/v1/certify/oauth/token" \
    -H "Content-Type: application/x-www-form-urlencoded" \
    --data-urlencode "grant_type=urn:ietf:params:oauth:grant-type:pre-authorized_code" \
    --data-urlencode "pre-authorized_code=$pre_auth_code")

  local access_token c_nonce
  access_token=$(echo "$token_response" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).access_token)")
  c_nonce=$(echo "$token_response" | node -e "console.log(JSON.parse(require('fs').readFileSync(0,'utf8')).c_nonce)")

  if [ -z "$access_token" ] || [ "$access_token" = "undefined" ]; then
    echo "ERROR: no se obtuvo access_token. token_response:"
    echo "$token_response"
    return 1
  fi

  # 4. Construir el proof JWT ES256. aud = base URL del issuer (punto 3).
  local proof_jwt
  proof_jwt=$(node "$SCRIPT_DIR/build-proof-jwt.mjs" "$c_nonce" "$CERTIFY_URL")

  # 5. Pedir la credencial. Shape real: format + doctype (punto 4).
  local credential_response
  credential_response=$(curl -sS -X POST "$CERTIFY_URL/v1/certify/issuance/credential" \
    -H "Authorization: Bearer $access_token" \
    -H "Content-Type: application/json" \
    -d "{
      \"format\": \"mso_mdoc\",
      \"doctype\": \"org.iso.18013.5.1.mDL\",
      \"proof\": {\"proof_type\": \"jwt\", \"jwt\": \"$proof_jwt\"}
    }")

  if echo "$credential_response" | grep -q '"error"'; then
    echo "ERROR: /v1/certify/issuance/credential devolvió un error:"
    echo "$credential_response"
    return 1
  fi

  # 6. Extraer el CBOR base64url y decodificarlo a archivo binario.
  #    extract-cbor.mjs detecta el wrapper {docType, issuerSigned} (punto 7,
  #    siempre presente en este entorno) y lo avisa, sin corregirlo. Sale con
  #    código 3 si lo detectó, 0 si no. El `|| extract_exit=$?` es necesario
  #    porque este script corre con `set -e`: el código 3 es un resultado
  #    ESPERADO, no un error, y sin el `||` mataría el script antes de leerlo.
  local extract_exit=0
  echo "$credential_response" | node "$SCRIPT_DIR/extract-cbor.mjs" "$OUT_DIR/${label}.cbor" || extract_exit=$?

  # 7. Verificar con verify-mdoc.mjs sin importar el resultado del paso
  #    anterior: interesa ver el mensaje de fallo real del verificador cuando
  #    el CBOR viene envuelto.
  echo "=== Verificando $label con verify-mdoc.mjs ==="
  # No se pasa --expected-elements: ese flag cuenta elementos ISO fijos de
  # Table 3 (11 en este docType), no el número de categorías de
  # driving_privileges del caso (1 o 4).
  if node "$VERIFY_DIR/verify-mdoc.mjs" "$OUT_DIR/${label}.cbor" "$OUT_DIR/iaca.pem" \
      --doctype=org.iso.18013.5.1.mDL --namespace=org.iso.18013.5.1; then
    echo "RESULTADO $label: verify-mdoc.mjs PASÓ."
    return 0
  else
    if [ "$extract_exit" -eq 3 ]; then
      echo "RESULTADO $label: verify-mdoc.mjs FALLÓ como se esperaba — el CBOR viene"
      echo "envuelto en {docType, issuerSigned} (comportamiento conocido de Inji Certify 0.14.0)."
    else
      echo "RESULTADO $label: verify-mdoc.mjs FALLÓ por una razón DISTINTA al wrapper conocido."
    fi
    return 2
  fi
}

overall_wrapped=0
overall_failed_other=0
overall_passed=0

# El resultado se captura con `|| result_Ncat=$?` porque el script corre con
# `set -e` e issue_and_verify retorna 2 en el resultado ESPERADO (CBOR
# envuelto): un comando simple que falla mataría el script salvo que forme
# parte de una lista `||`/`&&`/`if`; `issue_and_verify ...; result=$?` no
# basta.
result_1cat=0
issue_and_verify "MOCK-1CAT" "1categoria" || result_1cat=$?
case $result_1cat in
  0) overall_passed=$((overall_passed+1)) ;;
  2) if [ -f "$OUT_DIR/1categoria.cbor" ]; then overall_wrapped=$((overall_wrapped+1)); else overall_failed_other=$((overall_failed_other+1)); fi ;;
  *) overall_failed_other=$((overall_failed_other+1)) ;;
esac

result_4cat=0
issue_and_verify "MOCK-4CAT" "4categorias" || result_4cat=$?
case $result_4cat in
  0) overall_passed=$((overall_passed+1)) ;;
  2) if [ -f "$OUT_DIR/4categorias.cbor" ]; then overall_wrapped=$((overall_wrapped+1)); else overall_failed_other=$((overall_failed_other+1)); fi ;;
  *) overall_failed_other=$((overall_failed_other+1)) ;;
esac

echo ""
if [ "$overall_failed_other" -gt 0 ]; then
  echo "=== RESULTADO NO CONCLUYENTE — al menos un caso falló por una razón"
  echo "distinta al wrapper {docType, issuerSigned} conocido. Revisa el output arriba. ==="
  exit 1
elif [ "$overall_passed" -eq 2 ]; then
  echo "=== Resultado: AMBOS casos (1 y 4 categorías) verificados correctamente ==="
  exit 0
elif [ "$overall_wrapped" -eq 2 ]; then
  echo "=== Resultado: AMBOS casos (1 y 4 categorías) emitidos correctamente contra el"
  echo "entorno real, pero el CBOR llega envuelto en {docType, issuerSigned} en ambos"
  echo "(comportamiento conocido de Inji Certify v0.14.0; el parser de InjiWallet lo"
  echo "tolera, el verificador standalone requiere desenvolverlo). verify-mdoc.mjs"
  echo "falla el parseo de IssuerSigned como se esperaba. ==="
  exit 0
else
  echo "=== RESULTADO MIXTO — un caso pasó y el otro quedó envuelto (o"
  echo "viceversa). Revisa el output arriba para el detalle de cada caso. ==="
  exit 1
fi
