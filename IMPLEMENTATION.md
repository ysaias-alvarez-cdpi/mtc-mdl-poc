# Guía de implementación — mDL (ISO/IEC 18013-5) en producción MTC

Runbook para llevar la emisión de la Licencia de Conducir como **mdoc conforme**
(`mso_mdoc`) a la infraestructura real del MTC, junto al SD-JWT que ya emite hoy, sin
reemplazarlo. Para el contexto del estándar y cómo correr el entorno de pruebas, ver el
[README](README.md).

Cada fase indica qué ejecutar, en qué orden y cómo confirmar que quedó bien hecho. Las
afirmaciones técnicas se verificaron contra código fuente real (bytecode de la imagen de
Inji Certify, repositorios del MTC y de MOSIP) o ejecutando el entorno de pruebas.

**Repositorios de referencia**

| Repositorio | Rol |
|---|---|
| `IUGO-MTC/inji-certify` (rama `main`, v0.14.0) | Emisor — fork del MTC |
| `IUGO-MTC/inji-dataprovider` | Plugin de datos FEE real y SQL de `credential_config` |
| `IUGO-MTC/inji-hsm` | Terraform del clúster CloudHSM |
| `inji-wallet` (fork del MTC) | Wallet |
| `inji-verify` (fork del MTC) | Verificador |
| [`yalvarez/inji-wallet-verification`](https://github.com/yalvarez/inji-wallet-verification) | Parche de confianza para `vc-verifier` (Android) y puerto Swift para iOS |

## Estado por fase

| Fase | Estado |
|---|---|
| 0. Decisiones de producto | Pendiente de decisión del MTC |
| 1. Clave de firma EC en CloudHSM | Parche listo (`hsm-patch/`); falta validarlo en hardware |
| 2. Certificado DSC de la CA del MTC | Procedimiento documentado; trámite organizacional; perfil y validez por confirmar (2.5) |
| 3. `credential_config` en Inji Certify | Validado en el entorno de pruebas; SQL listo para adaptar |
| 4. Plugin de datos FEE real | Mock validado como contrato; implementación real pendiente |
| 5. Wallet (iOS y Android) | **iOS: bloqueante crítico.** Puerto Swift probado (9/9); falta integrarlo. Android: parche de confianza listo |
| 6. Verificación por terceros | Gap confirmado en InjiVerify; 3 alternativas evaluadas |
| 7. Conformidad y checklist pre-producción | Plan de interoperabilidad definido; sin ejecutar |
| 8. Auditoría de madurez | 5 hallazgos críticos a resolver antes de producción real |
| Anexo A. Prueba en dispositivo real | 8 defectos corregidos (3 en el emisor, 5 en la wallet) |

---

## Registro de pendientes y ruta crítica

Todo lo que hoy impide emitir y operar mDL en producción, reunido en un solo lugar. La
columna **Responsable** indica quién tiene el acceso o la autoridad para cerrarlo según el
repositorio o rol involucrado; **los nombres de personas y equipos concretos están por
asignar por el MTC**. Los plazos no se estiman: dependen de terceros y de la agenda del MTC.

**Tipo:** D = decisión · E = dependencia externa · DEV = desarrollo · V = validación pendiente.

| ID | Pendiente | Tipo | Fase | Responsable (rol) | Bloquea | Estado |
|---|---|---|---|---|---|---|
| P1 | Decidir una credencial por titular o una por clase | D | 0.1 | Producto MTC | Fase 3 | Abierto |
| P2 | Definir la IACA raíz: quién la emite, custodia y rota | D / E | 2.4 | CA del MTC | P4, P11, P12 | Abierto |
| P3 | Confirmar el perfil exigido a IACA y DSC y sus validez máximas (2.5) | V | 2.5 | CA del MTC + equipo Certify | P4 | Abierto |
| P4 | Obtener el DSC firmado por la CA | E | 2.1 | CA del MTC | Emisión real | Abierto |
| P5 | Disponer de un CloudHSM **no productivo** para validar el parche (1.2) | D / E | 1.2 | Infraestructura (`inji-hsm`) + Producto | P6 | El MTC solo tiene el CloudHSM de producción; hay que decidir cómo obtener uno no productivo |
| P6 | Validar el parche EC del HSM en hardware | V | 1.2 | Equipo Certify (`inji-certify`) | P4 | Parche escrito, sin validar |
| P7 | Obtener una respuesta real del servicio FEE y confirmar su forma | V | 4.2 | Equipo de datos (`inji-dataprovider`) | P8 | Abierto |
| P8 | Implementar el plugin FEE real para el mDL | DEV | 4 | Equipo de datos (`inji-dataprovider`) | Emisión real | Mock listo como contrato |
| P9 | Aplicar al Certify de producción las correcciones A.1 (`kid` con `#0`) y A.2 (`portrait`) | DEV | Anexo A | Equipo Certify (`inji-certify`) | Toda emisión con wallet real | Parche de bytecode solo en pruebas |
| P10 | Confirmar que Mimoto está desplegado y disponible | V | 7.2 | Infraestructura | Toda obtención del mDL | Sin confirmar |
| P11 | Trust store de la wallet con refresco de anchors | DEV | 5.2 | Equipo wallet (`inji-wallet`) | Verificación de confianza | Sin construir |
| P12 | Definir qué se publica para distribuir confianza (VICAL, certificado IACA o ambos) y quién lo firma y mantiene | D / E | 2.4 | CA del MTC + Producto | P11, Fase 6 | Abierto |
| P13 | Integrar el puerto Swift (bridging React Native) y reemplazar el hardcode de iOS | DEV | 5.0 | Equipo wallet (`inji-wallet`) | Lanzamiento iOS | Puerto probado (9/9), sin integrar |
| P14 | Publicar el AAR parcheado de `vc-verifier` y apuntar la wallet a él | DEV | 5.1 | Equipo wallet (`inji-wallet`) | Verificación de confianza (Android) | Parche listo, sin compilar contra el módulo completo |
| P15 | Elegir el camino de verificación por terceros y ejecutarlo | D / DEV | 6 | Producto + equipo verificador (`inji-verify`) | Verificación de terceros | Alternativas evaluadas |
| P16 | Proceso de rotación del DSC con alerta, y alarma ante el fallback a autofirmado | DEV / D | 8.2 | Operación + CA del MTC | Operación segura | Sin definir |
| P17 | Divulgación selectiva real para mdoc en la wallet | DEV | 8.4 | Equipo wallet (`inji-wallet`) | Privacidad | Sin construir |
| P18 | Conectar la revocación a `mso_mdoc` | DEV | 8.1 / 8.3 | Equipo Certify (`inji-certify`) | Ciclo de vida | Sin construir |
| P19 | Confirmar la configuración de Actuator en producción | V | 8.6 | Operación | — | Sin confirmar |
| P20 | Decidir el alcance sin conexión (BLE/NFC) | D | 8.3 | Producto MTC | Control en campo | Abierto |
| P21 | Probar la interoperabilidad con una implementación independiente (7.1) | V | 7.1 | Equipo Certify + verificador | Declarar conformidad | Abierto |
| P22 | Confirmar si el MTC exige un esquema de certificación de conformidad o evaluación legal | D | 7.1 | Producto + área legal MTC | — | No investigado |

### Ruta crítica

La cadena que determina cuándo se puede emitir un mDL real y firmado por el Estado es:

```
P5 CloudHSM no productivo → P6 validar parche EC → CSR (1.4)
        → P3 perfil de certificado confirmado con la CA → P4 DSC firmado (Fase 2)
        → upload del DSC (2.2) → emisión real con P8 y P9 ya aplicados
```

**Iniciar desde el primer día**, porque dependen de terceros y no se aceleran con trabajo
técnico propio: P2 y P3 (definición de la IACA y su perfil con la CA), P5 (hardware), P7
(muestra del FEE) y P10 (estado de Mimoto). El resto puede avanzar en paralelo:

- **Wallet:** P13 (iOS), P14 (AAR Android) y P17 (divulgación selectiva) son independientes de
  la cadena del emisor. P13 es bloqueante para el lanzamiento.
- **Emisor:** P8 y P9 pueden construirse y probarse con el entorno local antes de tener
  certificado real.
- **Verificación de terceros:** P15 y P12 se definen mientras se espera el DSC.

---

## Veredicto de viabilidad

**Es viable emitir mdoc con Inji Certify y lanzar de forma simultánea en Android e iOS.**
Ningún hallazgo invalida la arquitectura del emisor ni el formato mdoc. Lo pendiente está
acotado, tiene solución identificada y se concentra en la wallet.

**Decisión de clave de firma.** El MTC firma hoy SD-JWT con Ed25519
(`CERTIFY_VC_SIGN_ED25519`). ISO/IEC 18013-5 exige ECDSA (P-256 u otra curva NIST) para
`mso_mdoc`; Ed25519 no es conforme. Como SD-JWT aún no está en producción, **se recomienda
definir ECDSA P-256 como la única clave de firma del sistema desde el inicio**, usada para
ambos formatos: un solo trámite de HSM y certificado en lugar de dos.

### Qué funciona hoy

- **Emisión de mdoc desde Inji Certify 0.14.0**, validada contra la imagen real, con wallet
  real y dispositivo físico (Anexo A).
- **El CBOR envuelto `{docType, issuerSigned}`** que produce Inji Certify no es problema para
  InjiWallet: `vcverifier-aar:1.5.0` lo tolera por diseño.

### Qué falta (ejecución con receta escrita)

| Pendiente | Implicación si no se hace |
|---|---|
| **Clave EC en CloudHSM.** `AWSCloudHSMKeyStoreImpl` del fork solo genera RSA; el parche está en `hsm-patch/`. | `generate-csr` para la clave EC falla en el HSM. |
| **Certificado DSC de la CA del MTC.** Procedimiento de 3 pasos confirmado en código. | Es un trámite con plazo propio; si no se inicia en paralelo, es el camino crítico. |
| **Plugin de datos FEE real.** La forma real de la respuesta del servicio FEE no se ha confirmado. | Si el FEE no entrega categorías con fechas por categoría, el mdoc incumple ISO 18013-5 Tabla 3. |
| **Correcciones del emisor** (Anexo A.1 y A.2): `kid` con fragmento `#0` y `portrait` como `bstr`. | Ninguna wallet real puede obtener el mDL (A.1), o la fotografía queda mal tipada (A.2). |
| **Confianza del emisor en Android.** `verifyCertificateChain()` retorna `true` sin validar. | Un mdoc autofirmado se reportaría como válido. Parche listo; falta integrarlo y un trust store. |

### El punto que aún es un "no, todavía no": iOS

Hay que distinguir dos verificaciones:

1. **La wallet verificando lo que recibe o guarda:** al recibir la credencial, al abrir su
   detalle, al restaurar un backup. Son siempre autochequeos internos.
2. **El verificador externo verificando una presentación.** La wallet no valida nada en el
   flujo de presentación; esa garantía es del verificador.

**El defecto de iOS está en el punto 1.** `verifyCredentialForIos()` retorna éxito
hardcodeado para `mso_mdoc`, sin validar firma, digests ni cadena. La wallet iOS no detecta
una credencial corrupta ni una inyectada en su almacenamiento. Es un defecto del proyecto
oficial `mosip/inji-wallet` (presente en su `main`), heredado sin cambios por el fork del
MTC.

**Por qué no se resuelve en TypeScript.** `mso_mdoc` es CBOR/COSE binario; la única librería
JS de verificación de la app (`@digitalcredentials/vc`) solo entiende JSON-LD. En Android,
MOSIP escribió una librería nativa en Kotlin (`vc-verifier`) con un puente delgado
(`RNVCVerifierModule.java`). **Para iOS nunca se escribió el equivalente.**

**Estado del puerto Swift.** Existe un puerto completo de `vc-verifier`, mapeado método a
método contra el Kotlin real (decodificación CBOR, COSE_Sign1 con CryptoKit, cadena X.509 con
`SecTrust`, puente React Native). Compila y pasa **9/9 tests** en un runner macOS real de
GitHub Actions, incluida una verificación de punta a punta contra un mdoc real. Falta lo que
ningún CI genérico puede cubrir: el bridging React Native dentro del proyecto Xcode real de
`inji-wallet` del MTC.

**Decisión recomendada.** Lanzar Android e iOS **simultáneamente**, con verificación real en
ambas. Lanzar solo Android dejaría una brecha de funcionalidad entre plataformas que el
usuario percibe como "el Estado digital no funciona en iPhone". El hardcode actual de iOS no
debe llegar a producción bajo ninguna circunstancia. Si la integración no cierra a tiempo, la
contingencia es **fail-closed**: no ofrecer `mso_mdoc` en iOS hasta integrar el puerto.

### Alcance recomendado

1. Emitir mdoc con clave EC P-256 unificada (Fases 1–4).
2. Aplicar el parche de confianza y el trust store en Android (5.1–5.2).
3. Integrar el puerto Swift antes del lanzamiento (5.0) y lanzar en ambas plataformas a la vez.
4. Decidir en paralelo el camino de verificación por terceros (Fase 6).

---

## Fase 0 — Decisiones de producto

Deben tomarse antes de tocar infraestructura.

### 0.1 Una credencial por titular o una por clase de licencia

SD-JWT emite hoy 3 credenciales separadas (clases A/B/E). En mdoc, ISO/IEC 18013-5 modela
**todas las categorías vigentes de una persona en un único `driving_privileges`**, dentro de
una sola credencial. Esta guía asume ese modelo (`credential_config_key_id =
'MTCDrivingLicenseMDL'`, una fila).

Replicar el patrón "una fila por clase" generaría tres mdoc con una categoría cada uno, que no
es el uso previsto ni lo que un verificador de terceros espera. **Acción:** confirmar con
producto si existe un caso de uso legítimo para presentar una sola clase. Si existe, la Fase 3
se adapta a 3 filas (`MTCDrivingLicenseAMDL`/`B`/`E`); el resto no cambia.

### 0.2 Dependencias externas y fecha de entrega

Cada fase tiene dependencias con plazo propio: CA del MTC, un CloudHSM no productivo,
acceso a los forks de wallet/verificador, despliegue de Mimoto. **Confirmar cuáles están
disponibles antes de fijar una fecha.**

### 0.3 Reproducir el entorno local

Es la forma más rápida de conocer el flujo completo sin riesgo. Ver
[README § Entorno de pruebas](README.md#4-entorno-de-pruebas).

---

## Fase 1 — Clave de firma EC en CloudHSM

### 1.1 El bloqueante del HSM

`AWSCloudHSMKeyStoreImpl.java` del fork (rama `feature/cloud-hsm`,
`certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/`) genera claves con
`generateKeyPair`, que **siempre construye un `AlgorithmParameterSpec` RSA** y no tiene rama
para EC:

```java
private static final String RSA_SPEC_CLASS = "com.cavium.key.parameter.CaviumRSAKeyGenParameterSpec";
...
private KeyPair generateKeyPair(String keyAlias) {
    KeyPairGenerator generator = KeyPairGenerator.getInstance(asymmetricKeyAlgorithm);
    AlgorithmParameterSpec rsaSpec = buildRsaSpec(keyAlias);
    generator.initialize(rsaSpec);
    return generator.generateKeyPair();
}
```

La capa de negocio de MOSIP (`KeymanagerServiceImpl`) sí sabe pedir `EC_SECP256R1_SIGN`
(mapeado a P-256); el hueco está exclusivamente en esta clase. Sin el parche,
`generate-csr` con esa referencia falla en el HSM.

### 1.2 Aplicar el parche

```bash
cd /ruta/a/IUGO-MTC/inji-certify
git checkout feature/cloud-hsm
git log -1 -- certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/AWSCloudHSMKeyStoreImpl.java
# confirmar que el archivo no cambió desde que se escribió el parche
git apply /ruta/a/mtc-mdl-poc/hsm-patch/AWSCloudHSMKeyStoreImpl.java.patch
```

**Dónde validar el parche.** Hoy el MTC solo tiene el CloudHSM de producción; no existe uno
de desarrollo. **No validar el parche contra el clúster de producción sin una decisión
explícita del MTC**: ese HSM es el que custodia las claves reales. Opciones, a decidir por el
MTC:

1. **Clúster no productivo temporal**, creado con el Terraform de `IUGO-MTC/inji-hsm` o
   restaurado desde un backup del clúster existente (confirmar que AWS CloudHSM lo permite en
   su configuración), y destruido al terminar. El HSM se factura por hora, de modo que el costo
   es el de unos días de prueba.
2. **Probar en producción con salvaguardas**, solo si el MTC lo aprueba: un `applicationId`
   y `referenceId` de prueba distintos de los reales, una ventana acordada, y borrar la clave
   de prueba al terminar. Es la opción con más riesgo y no se recomienda como primera.

Antes de elegir, confirmar con el equipo de infraestructura qué SDK de cliente usa el
despliegue (el fork usa el SDK Cavium, `com.cavium.*`, y el parche se escribió para él).

**Valide el parche en un entorno no productivo antes de producción.** Usa el
`ECGenParameterSpec` estándar del JDK porque no existe código fuente público de una clase
Cavium específica para EC. Debe confirmarse, en este orden:

1. El valor real de `asymmetricKeyAlgorithm` en una petición `EC_SECP256R1_SIGN` (el parche
   asume `"EC"`); loguearlo temporalmente.
2. Que la clave persiste: repetir `generate-csr` con el mismo `referenceId` debe devolver el
   **mismo** CSR. Si genera uno nuevo, la clave no quedó marcada como persistente y hace falta
   una clase de parámetros EC propia de Cavium.
3. Que el CSR es EC P-256 genuino (ver 1.4).

Detalle de lo confirmado y lo no confirmado: [hsm-patch/README.md](hsm-patch/README.md).

### 1.3 Activar la política de la clave

`certify.key_policy_def` debe tener una fila para `CERTIFY_VC_SIGN_EC_R1` antes de generar la
clave; sin ella, `generate-csr` falla con un error de política (no de HSM).

```sql
SELECT app_id FROM certify.key_policy_def WHERE app_id = 'CERTIFY_VC_SIGN_EC_R1';
```

Si no existe (lo esperable: el SQL real del MTC solo define la política Ed25519), aplicar el
bloque `CERTIFY_VC_SIGN_EC_R1` de [`compose/certify/init-mdoc.sql`](compose/certify/init-mdoc.sql)
(validez 1095 días, `PRE_EXPIRE_DAYS = 60`; **revisar esa validez contra 2.5**). El mapeo
`'ES256': {{'CERTIFY_VC_SIGN_EC_R1', 'EC_SECP256R1_SIGN'}}` ya viene en el
`certify-default.properties` base.

### 1.4 Generar la clave y obtener el CSR

Los endpoints de `system-info` envuelven su cuerpo en `{id, version, requesttime, request}`;
solo `request` es obligatorio.

```bash
curl -X POST "https://<host-inji-certify-mtc>/v1/certify/system-info/generate-csr" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token-admin>" \
  -d '{
    "id": "mosip.certify.generatecsr",
    "version": "1.0",
    "requesttime": "2026-01-01T00:00:00.000Z",
    "request": {
      "applicationId": "CERTIFY_VC_SIGN_EC_R1",
      "referenceId": "EC_SECP256R1_SIGN",
      "commonName": "mDL Signer MTC",
      "organizationUnit": "Direccion General de Transporte Terrestre",
      "organization": "Ministerio de Transportes y Comunicaciones",
      "location": "Lima",
      "state": "Lima",
      "country": "PE"
    }
  }' | tee generate-csr-response.json

jq -r '.response.certSignRequest' generate-csr-response.json > mdl-signer.csr.pem
```

**La primera llamada genera la clave privada en el HSM como efecto colateral.** Las
siguientes con el mismo `applicationId`/`referenceId` reutilizan la clave y devuelven el mismo
CSR.

Verificar que es EC P-256:

```bash
openssl req -in mdl-signer.csr.pem -noout -text | grep -A2 "Public Key Algorithm"
```

Debe decir `id-ecPublicKey` con curva `prime256v1`. Si dice `rsaEncryption`, el parche no se
aplicó o cayó al camino RSA: no continuar.

---

## Fase 2 — Certificado DSC de la CA del MTC

**Es una dependencia organizacional con plazo propio. Iniciarla en paralelo con la Fase 1.**

### 2.1 Entregar el CSR a la CA

Entregar `mdl-signer.csr.pem` a quien administre la CA raíz del MTC. El resultado es un
certificado X.509 firmado: el **DSC** (Document Signer Certificate). Guardarlo como
`mdl-signer.cert.pem`.

### 2.2 Subir el certificado a Inji Certify

```bash
CERT_PEM_ESCAPED=$(python3 -c "import json; print(json.dumps(open('mdl-signer.cert.pem').read()))")

curl -X POST "https://<host-inji-certify-mtc>/v1/certify/system-info/uploadCertificate" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <token-admin>" \
  -d '{
    "id": "mosip.certify.uploadcertificate",
    "version": "1.0",
    "requesttime": "2026-01-01T00:00:00.000Z",
    "request": {
      "applicationId": "CERTIFY_VC_SIGN_EC_R1",
      "referenceId": "EC_SECP256R1_SIGN",
      "certificateData": '"$CERT_PEM_ESCAPED"'
    }
  }'
```

Inji Certify exige que la clave pública del certificado subido coincida **byte a byte** con la
generada en el HSM (`KeymanagerServiceImpl.uploadCertificate`). Si no coincide responde
`KEY_NOT_MATCHING`, típicamente porque el CSR se regeneró entre medias o el
`applicationId`/`referenceId` es otro. Respuesta esperada: `{"response": {"status": "success"}}`.

### 2.3 Verificar el aprovisionamiento

```bash
curl -s "https://<host-inji-certify-mtc>/v1/certify/system-info/certificate?applicationId=CERTIFY_VC_SIGN_EC_R1&referenceId=EC_SECP256R1_SIGN" \
  | jq -r '.response.certificate' | openssl x509 -noout -text
```

Confirmar que el certificado coincide con el subido, que es `id-ecPublicKey` con curva
`secp256r1`, y que `subject`/`issuer` corresponden a la CA real (no a un certificado de prueba
autofirmado).

### 2.4 Identificar la IACA raíz

Sin una IACA raíz conocida, un verificador de terceros no puede anclar la cadena y el mDL no
es desplegable. **Documentar** cuál es la IACA raíz del MTC, quién la emite y por qué
mecanismo de distribución la obtendrá un verificador. Alimenta la Fase 5 (`trustedIacaCerts`)
y cualquier integración externa. Es una definición organizacional; no hay comando.

---

### 2.5 Perfil de certificados IACA y DSC — confirmar con la CA antes del CSR

ISO/IEC 18013-5 (Anexo B) exige un perfil concreto para la IACA y el DSC. **El texto de la
norma es de pago y no se pudo consultar para esta guía**; lo siguiente proviene de
documentación pública de implementadores y **debe confirmarse contra la norma** antes de
entregarlo a la CA. Un perfil incorrecto se descubre al final del proceso, con el DSC ya
firmado.

**Coinciden las fuentes consultadas** (AWS Private CA, MATTR):

| Elemento | Requisito |
|---|---|
| DSC — `keyUsage` | `digitalSignature` (en el ejemplo de AWS, marcado crítico y único) |
| DSC — `extendedKeyUsage` | OID `1.0.18013.5.1.2` (reservado para DS de mDL) |
| DSC — `authorityKeyIdentifier` | Debe coincidir con el `subjectKeyIdentifier` de la IACA (MATTR) |
| DSC — firmado por | La IACA, de forma directa: la cadena mDL tiene un solo nivel entre IACA y DSC |
| IACA — `keyUsage` | `keyCertSign` y `cRLSign` |
| IACA — `basicConstraints` | `CA = TRUE` (MATTR) |
| IACA — CRL | Extensión `cRLDistributionPoints` presente (AWS la describe como obligatoria en el perfil de la IACA) |
| IACA — `issuerAlternativeName` | Presente (MATTR; AWS lo incluye también en el DSC de ejemplo) |
| Subject | País en código ISO 3166-1 alfa-2 (`PE`); Inji lo compara con `issuing_country` (Anexo A.3) |
| Algoritmo | ECDSA con SHA-256 sobre P-256 en los ejemplos de AWS y MATTR |

**Las fuentes discrepan o no lo dicen — confirmar contra ISO/IEC 18013-5:2021:**

| Elemento | Qué dicen las fuentes |
|---|---|
| Validez máxima de la IACA | 9 años (AWS y la guía del gobierno del Reino Unido, citando la Tabla B.1) frente a 20 años (MATTR, walt.id) |
| Validez máxima del DSC | **457 días** (guía del gobierno del Reino Unido, atribuida a ISO; MATTR para mDL gestionados) frente a 1825 días en un ejemplo de AWS, sin citar la norma |
| DSC más largo que la credencial | La guía del Reino Unido exige que el DSC dure más que el mdoc que firma |
| CRL del DSC y contenido de `issuerAlternativeName` | No estaba claro en las fuentes |

**Por qué importa aquí.** Si el máximo del DSC fuera de 457 días:

- La política actual de `CERTIFY_VC_SIGN_EC_R1` (1095 días, `init-mdoc.sql`) y la vigencia por
  defecto de la credencial (`P730D`) serían incompatibles con la norma, y habría que ajustar
  ambas.
- La rotación del DSC dejaría de ser ocasional: ocurriría al menos una vez al año, lo que
  agrava el hallazgo crítico #1 (8.2) y vuelve indispensable el proceso P16.

**Preguntas abiertas para la CA y el equipo de Certify** (ninguna está resuelta en este
repositorio):

1. ¿Cuál es el perfil exacto de IACA y DSC que la CA del MTC puede emitir, y cuál exige la
   norma?
2. El CSR que genera Inji Certify no lleva extensiones como `extendedKeyUsage`: ¿las agrega la
   CA al firmar? Confirmarlo antes de aceptar el DSC.
3. ¿Quién publica y mantiene la CRL, y en qué URL?

Fuentes consultadas:
[AWS Private CA — DSC](https://docs.aws.amazon.com/privateca/latest/userguide/JavaApiMDL-IssueDS.md),
[AWS Security Blog](https://aws.amazon.com/blogs/security/build-a-mobile-drivers-license-solution-based-on-iso-iec-18013-5-using-aws-private-ca-and-aws-kms),
[GOV.UK Wallet — firmar mdoc](https://docs.wallet.service.gov.uk/issue-credentials/sign-mdoc-credentials),
[MATTR — certificados](https://learn.mattr.global/docs/issuance/certificates/overview),
[walt.id — VICAL e IACA](https://docs.walt.id/concepts/trust-systems/iso-trust-vicals).

---

## Fase 3 — `credential_config` en Inji Certify

### 3.1 Confirmar la versión

```bash
docker image inspect <imagen-ecr-inji-certify> | grep -i version
```

Esta guía asume v0.14.0 (rama `main` de `IUGO-MTC/inji-certify`, la de producción). Si
difiere, revalidar los hallazgos antes de continuar. (La rama `master` del fork está en
v0.12.2 y no es la de producción.)

### 3.2 Aplicar el `credential_config`

Adaptar y aplicar el INSERT de [`compose/certify/init-mdoc.sql`](compose/certify/init-mdoc.sql):

- `credential_config_key_id = 'MTCDrivingLicenseMDL'`
- `credential_format = 'mso_mdoc'`, `doctype = 'org.iso.18013.5.1.mDL'`
- `key_manager_app_id = 'CERTIFY_VC_SIGN_EC_R1'`, `key_manager_ref_id = 'EC_SECP256R1_SIGN'`
- `signature_algo = 'ES256'`, `signature_crypto_suite = 'EcdsaSecp256r1Signature2019'`

Si la decisión 0.1 fue "una por clase", usar 3 filas.

### 3.3 Template Velocity

El `vc_template` embebido en `init-mdoc.sql` debe cumplir tres condiciones, verificadas contra
el comportamiento real de Inji Certify:

1. Cada campo en notación bracket: `${rootContext['org.iso.18013.5.1'].<campo>}`, nunca
   `${campo}`.
2. El marcador de `driving_privileges` **sin comillas**, para que Velocity lo sustituya como
   fragmento JSON crudo (los campos escalares sí llevan comillas).
3. El plugin de datos (Fase 4) debe entregar `driving_privileges` como **string JSON ya
   serializado**, no como array.

Regenerar con [`render-mdoc-template.mjs`](compose/certify/render-mdoc-template.mjs) si se
necesitan más campos. El template crudo no es JSON válido hasta que Certify sustituye
`driving_privileges`; es el comportamiento esperado.

### 3.4 Verificación

```bash
curl -s "https://<host>/v1/certify/.well-known/openid-credential-issuer" \
  | jq '.credential_configurations_supported.MTCDrivingLicenseMDL'
```

Debe devolver la configuración completa, incluido `driving_privileges` en el esquema de claims.

---

## Fase 4 — Plugin de datos FEE real

### 4.1 Contrato a replicar

[`compose/certify/mock-fee-plugin/`](compose/certify/mock-fee-plugin/) es el **contrato de
referencia**: implementa `io.mosip.certify.api.spi.DataProviderPlugin`
(`fetchData(Map<String,Object>): JSONObject`). El plugin real vive en
`IUGO-MTC/inji-dataprovider` (`MtcFeeDataProviderPlugin`) y debe extenderse para
`MTCDrivingLicenseMDL`, replicando:

- **Claims anidadas bajo el namespace ISO:** `{"claims": {"org.iso.18013.5.1": {...}}}`.
- **`driving_privileges` como string JSON serializado**, no `JSONArray`; lo contrario produce
  `JSONException: Expected a ',' or '}'` en Velocity.
- **Identificador del titular desde `identityDetails.sub`**, con fallback a
  `individualId`/`individual_id` por si otro flujo de autenticación lo puebla distinto.
- **`portrait` como base64 de un JPEG.** Requiere la corrección A.2 en el emisor para quedar
  codificado como `bstr`.

No usar `certify-mtc-mock-fee.properties` en el entorno real.

### 4.2 Confirmar la forma real de la respuesta del FEE

**Este es un riesgo de datos que no se ha verificado.** Todo el trabajo asume que el FEE
puede entregar (o el plugin puede transformar su respuesta a) un array de objetos con
`vehicle_category_code`, `issue_date` y `expiry_date` por categoría, forma que exige ISO/IEC
18013-5 Tabla 3. El `credentialSubject` de SD-JWT no impone esa estructura (podría ser un
string como `"A-IIb"` sin fechas). **Acción:** obtener una respuesta real del servicio FEE y
confirmar o mapear contra esa forma antes de dar la fase por completa.

### 4.3 Verificación

Replicar los 7 tests de
[`MockFeeDataProviderPluginTest.java`](compose/certify/mock-fee-plugin/src/test/java/pe/gob/mtc/mock/MockFeeDataProviderPluginTest.java)
contra la implementación real, y emitir un mDL con un `document_number` real de prueba. Pasar
el CBOR por `verify/verify-mdoc.mjs` para confirmar que `driving_privileges` llega completo.

---

## Fase 5 — Wallet

Fork del MTC: `inji-wallet`.
Consume `vc-verifier` como dependencia publicada (`io.mosip:vcverifier-aar:1.5.0`) con un
módulo nativo sin lógica propia (`RNVCVerifierModule.java` →
`CredentialsVerifier().verify(vc, format)`).

**El wrapper `{docType, issuerSigned}` no requiere ningún parche.** `MsoMdocVerifiableCredential`
lee `issuerSigned` tanto del formato plano como del anidado en `documents[0]`; el wrapper de
Certify cae en la rama que lo encuentra. Confirmado ejecutando `parse()` y `verify()` de la
librería real (1.5.0 y 1.6.0) contra CBOR emitidos por el entorno de pruebas.

### 5.0 BLOQUEANTE CRÍTICO — iOS no verifica mdoc

`shared/vcjs/verifyCredential.ts`, `verifyCredentialForIos()`:

```typescript
if (credentialFormat === VCFormat.mso_mdoc || credentialFormat === VCFormat.vc_sd_jwt || credentialFormat === VCFormat.dc_sd_jwt) {
  return createSuccessfulVerificationResult();
}
```

Para `mso_mdoc`, retorna éxito sin invocar ninguna verificación. Un CBOR arbitrario, sin
firma siquiera, se reporta como válido. El propio código lo marca como provisional ("until
VcVerifier is implemented for iOS"). Está presente igual en `mosip/inji-wallet` (`main`,
commit `2b37c05`, 2026-05-07).

El puerto Swift ya existe, compilado y probado:
[`yalvarez/inji-wallet-verification` → `vc-verifier-patch/ios/`](https://github.com/yalvarez/inji-wallet-verification/tree/main/vc-verifier-patch/ios).
Invoca la misma secuencia que Kotlin (cadena de confianza → país → firma COSE → digests →
docType) con `CryptoKit` y `Security`. Su README documenta 3 defectos reales corregidos
durante la validación: un caso de enum incompleto, los CBOR tags 18/24 de ISO 18013-5, y un
parser DER propio del Subject DN.

**Para integrarlo:**

1. Seguir el plan de validación del README del puerto en un entorno Xcode real.
2. Completar el bridging React Native (`MsoMdocVerifierReactNative/`) dentro del proyecto Xcode
   de `inji-wallet` del MTC; depende del framework `React`, que Swift Package Manager no
   resuelve.
3. Reemplazar el hardcode de `verifyCredentialForIos()` por una llamada al módulo nativo.
4. Probar en simulador y dispositivo real antes de habilitar mdoc en iOS.

**Contingencia (no plan por defecto):** si el tramo no cierra a tiempo, cambiar la condición
para que `mso_mdoc` falle de forma explícita (fail-closed) y no ofrecer el formato en iOS.

### 5.1 Parche del hueco de confianza (Android)

`MsoMdocVerifier.verifyCertificateChain()` retorna `true` incondicionalmente (en `iconst_1,
ireturn` en el bytecode de 1.5.0, confirmado): solo hay integridad de firma, no confianza. Un
mdoc autofirmado pasa `verify()`.

```bash
cd /ruta/a/inji/vc-verifier          # checkout del proyecto upstream
git apply /ruta/a/inji-wallet-verification/vc-verifier-patch/MsoMdocVerifier.kt.patch
```

El parche agrega un parámetro **opcional** `trustedIacaCerts: List<X509Certificate>` a
`verify()`; es compatible con los callers actuales (si se omite, el hueco sigue abierto pero
queda registrado como advertencia). Se validó con `kotlinc` contra certificados reales (4
casos) y con `git apply --check`.

**Empaquetado.** El fork consume el AAR publicado, no el código fuente. Hay que (a) compilar
un AAR propio desde un fork de `inji/vc-verifier` con el parche, publicarlo en un repositorio
Maven que el build de la wallet resuelva, y (b) apuntar `android/app/build.gradle` a esa
coordenada. **Antes de producción**, compilar contra el módulo Android completo
(`./gradlew :vc-verifier:assembleRelease`): el parche no se ha probado contra ese build.

### 5.2 Trust store en la app

El parche resuelve la librería; de dónde salen los `trustedIacaCerts` en ejecución es
responsabilidad de la app. Implementar en `inji-wallet` del MTC:

1. Un trust store local cacheado, para verificar sin depender de red.
2. Un refresco periódico en segundo plano contra un endpoint de distribución de confianza,
   usando la IACA de la Fase 2.4.
3. Pasar los certificados resueltos a `verify(mdoc, trustedIacaCerts)` desde
   `RNVCVerifierModule.java`, que hoy no pasa ninguno.

Esta pieza no está incluida en ningún parche de este proyecto.

---

## Fase 6 — Verificación por terceros

Son dos casos de uso con soluciones distintas: verificación **en línea** (QR + backend, como
InjiVerify) y **sin conexión en campo** (control policial, BLE/NFC).

### 6.1 InjiVerify (en línea) — gap confirmado y acotado

En `inji-verify` del MTC, `VCVerificationServiceImpl.java` decide el formato con un
`if/else` binario por `Content-Type`:

```java
if ("application/vc+sd-jwt".equalsIgnoreCase(contentType) || "application/dc+sd-jwt".equalsIgnoreCase(contentType)) {
    format = CredentialFormat.VC_SD_JWT;
} else {
    format = CredentialFormat.LDP_VC;  // cualquier otro, incluido mdoc
}
```

Un CBOR real cae en `LDP_VC` y falla al parsearse como JSON-LD. `FormatDto` tampoco declara
`mso_mdoc` (solo `jwt`, `jwt_vc`, `ldp_vc`).

**El gap es de código de aplicación, no de la librería.** El servicio ya depende de
`vcverifier-jar:1.5.0`, que sí implementa `MsoMdocVerifier`/`CredentialFormat.MSO_MDOC`. Dos
cambios en `verify-service` lo cierran:

1. Agregar la rama `Content-Type` → `CredentialFormat.MSO_MDOC` en `verify()`.
2. Declarar `mso_mdoc` en `FormatDto` y en el Presentation Definition con el path de ISO
   18013-5 (`$['org.iso.18013.5.1']['<campo>']`, distinto del `$.vct` de SD-JWT).

La UI (`verify-ui`) no se revisó con el mismo detalle; probablemente requiera un ajuste de
renderizado para claims de un namespace mdoc.

### 6.2 Servicio propio sobre `@owf/mdoc` (en línea)

[`verify/verify-mdoc.mjs`](verify/verify-mdoc.mjs) ya es un verificador funcional (13
comprobaciones) sobre `@owf/mdoc`/`@owf/cose`, de la OpenWallet Foundation. Envolverlo en un
endpoint HTTP y una UI mínima evita mantener un fork de InjiVerify; el trabajo pendiente es
solo la capa de servicio, a costa de un servicio nuevo que operar.

### 6.3 SDK Multipaz (en línea y sin conexión)

[`openwallet-foundation/multipaz`](https://github.com/openwallet-foundation/multipaz) es un SDK
Kotlin Multiplatform (Android, iOS y servidor). Verificado contra su código:

- `org.multipaz.verification` (`VerificationSession`, `MdocVerifiedPresentation`) es API pública
  reutilizable.
- Implementa **ambos protocolos de presentación**: proximidad (BLE/NFC, sin conexión) y
  OpenID4VP / W3C Digital Credentials API (en línea).
- `org.multipaz.trustmanagement` trae `TrustManager` local, `VicalTrustManager` (consume una
  VICAL, la lista estándar de IACAs de ISO 18013-5) y `CompositeTrustManager`; cubre el trust
  store de la Fase 5.2 en ambas plataformas.
- El módulo `multipaz-verifier` es JVM/servidor, otra alternativa al gap de InjiVerify.
- `multipaz-identity-reader` se instaló en Android sin forkear y se apuntó a trust anchors
  propios, validado contra vectores de interoperabilidad de `@owf/mdoc` (Alemania, Francia,
  Google, Ubique).

Incorporar `multipaz` en una app del MTC o de la policía da verificación real por proximidad
sin reescribir COSE/CBOR ni la cadena de confianza. **Es la única opción madura que cubre el
caso sin conexión.**

### 6.4 Decisión

| Caso de uso prioritario | Camino |
|---|---|
| En línea, dentro del ecosistema Inji | 6.1 |
| En línea, menor esfuerzo total | 6.2 |
| Control en campo sin conexión | 6.3 (única opción madura) |
| Ambos | 6.3 más 6.1 o 6.2; no son excluyentes |

Es una decisión de producto y ejecución; ya no es una incógnita técnica.

---

## Fase 7 — Conformidad y checklist pre-producción

### 7.1 Plan de conformidad e interoperabilidad

Hasta ahora el mDL se validó con `verify/verify-mdoc.mjs` (`@owf/mdoc`), con la librería
`vcverifier` de la wallet y con la wallet real. Eso demuestra que el mDL es coherente con
**esas implementaciones**, no que sea conforme con ISO/IEC 18013-5 frente a terceros. Antes de
declararlo conforme:

1. **Verificar con una segunda implementación independiente**, además de `@owf/mdoc`; por
   ejemplo el módulo `multipaz-verifier` o las librerías de `multipaz` (Fase 6.3) sobre el
   mismo CBOR. (P21)
2. **Probar contra un lector de terceros** cuando exista el canal de presentación
   correspondiente. Con el stack actual no es posible por proximidad: `inji-wallet` no genera
   el QR de device engagement de ISO 18013-5 (Anexo A, resultado), así que un lector como
   `multipaz-identity-reader` no puede iniciar la sesión con ella.
3. **Confirmar con el MTC** si existe un esquema de certificación de conformidad o una
   evaluación legal obligatoria para operar la licencia digital. **No se investigó.** (P22)

Mientras no se cierren estos puntos, el lenguaje correcto hacia el MTC y terceros es "mDL que
pasa las verificaciones de las implementaciones listadas", no "certificado conforme a ISO".

### 7.2 Checklist


- [ ] **Modelo de credencial decidido** (0.1).
- [ ] **Parche HSM validado en un CloudHSM no productivo** (1.2): genera EC P-256 real y la clave
      persiste entre reinicios.
- [ ] **DSC real de la CA del MTC subido** (Fase 2), no un certificado de prueba.
- [ ] **IACA raíz documentada**, con su mecanismo de distribución de confianza (2.4).
- [ ] **Perfil de IACA y DSC confirmado contra ISO/IEC 18013-5** y aceptado por la CA, incluidas las validez máximas (2.5).
- [ ] **`credential_config` aplicado y visible** en `.well-known/openid-credential-issuer` (3.4).
- [ ] **Correcciones del emisor aplicadas al Certify de producción** (A.1 `kid` con `#0`; A.2
      `portrait` como `bstr`) y país del certificado DSC correcto (A.3).
- [ ] **Forma real de la respuesta del FEE confirmada** (4.2).
- [ ] **Plugin FEE real desplegado y probado de punta a punta** (4.3), no el mock.
- [ ] **BLOQUEANTE — verificación iOS integrada antes del lanzamiento** (5.0): bridging React
      Native, reemplazo del hardcode y prueba en dispositivo. `mso_mdoc` no puede quedar en
      "éxito sin verificación" en producción. Contingencia: fail-closed.
- [ ] **Parche de confianza Android compilado contra el módulo completo** y el AAR integrado
      en la wallet (5.1).
- [ ] **Trust store de la wallet implementado**, con refresco de anchors (5.2).
- [ ] **Camino de verificación por terceros decidido y ejecutado** (Fase 6). Al menos uno en
      línea antes de producción; el de campo (6.3) si aplica control presencial.
- [ ] **Mimoto desplegado y disponible**: sin él no hay camino de token para que una wallet
      obtenga el mDL.
- [ ] **Hallazgos críticos de la Fase 8 resueltos o aceptados formalmente.**
- [ ] **Segunda implementación independiente verificada** sobre el mismo mDL (7.1).
- [ ] **Verificación final de punta a punta** con `verify/verify-mdoc.mjs` sobre un mDL emitido
      por el pipeline completo, firmado con el DSC real y abierto en la wallet corregida.

---

## Fase 8 — Auditoría de madurez de producción

Las Fases 1–7 cubren el camino feliz (emisión → wallet → verificación). Esta fase responde qué
le falta al sistema para ser una implementación **madura**, no solo funcional. Se revisaron 6
dominios con código real de `inji-certify`, `inji-wallet` e `inji-verify` del fork, el SDK
Multipaz y fuentes normativas primarias. Ningún hallazgo bloquea las Fases 1–7.

### Resumen — 5 hallazgos críticos

| # | Hallazgo | Dominio | Severidad |
|---|---|---|---|
| 1 | Si el DSC expira sin rotación manual, Inji Certify **cae en silencio a un certificado autofirmado** y rompe la cadena de confianza sin aviso | PKI | Alta |
| 2 | **La divulgación selectiva no funciona para mdoc:** la wallet envía siempre la credencial completa, validado con un `VPToken` real (A.5) | Privacidad | Alta |
| 3 | La **revocación excluye a mdoc**; no hay versión/nonce para invalidar tras un cambio de datos, y la device key es una sola para todas las credenciales | Ciclo de vida | Alta |
| 4 | El **canal sin conexión** (BLE/NFC de ISO 18013-5) no existe en el stack; el BLE presente es un protocolo propietario | Canales | Media-Alta |
| 5 | Endpoints Actuator **sobreexpuestos** en el `docker-compose` de desarrollo de Inji Certify; no aparecen en el Helm chart. **Confirmar contra la configuración real del MTC** | Operación | Media (a confirmar) |

### 8.1 Ciclo de vida de la credencial

| Pregunta | Veredicto |
|---|---|
| Expiración | Parcial |
| Renovación | No resuelto |
| Re-emisión tras cambio de datos | No resuelto |
| Pérdida de dispositivo | No resuelto |

- **Expiración.** El MSO lleva `validityInfo` real (`MDocProcessor.java:389-397`), con
  `validUntil` derivado de `mosip.certify.data-provider-plugin.vc-expiry-duration` (por defecto
  `P730D`, ~2 años). En iOS la verificación se omite (5.0), así que un mdoc vencido se reporta
  como válido. En Android no se pudo confirmar si `vc-verifier` valida `validUntil`.
- **Renovación.** `IarServiceImpl.java:196`: *"refresh_token and authorization_details are
  optional and not implemented yet"*. No hay re-emisión proactiva ni aviso previo al
  vencimiento. Multipaz tiene un mecanismo genérico de renovación; `inji-wallet` no usa
  Multipaz.
- **Re-emisión.** El MSO no lleva versión ni nonce. Si el titular cambia de domicilio o de
  categoría, la credencial anterior sigue siendo válida hasta su `validUntil`, porque la
  revocación no está conectada a `mso_mdoc` (8.3).
- **Pérdida de dispositivo.** El binding `deviceKeyInfo` es correcto (deriva de la clave de
  proof-of-possession de la wallet), pero `inji-wallet` genera **un único par de claves por
  algoritmo y por instalación**, compartido por todas las credenciales
  (`cryptoUtil.ts:133-159`), y `inji-certify` no tiene revocación por dispositivo. Quien
  desbloquee un teléfono perdido puede presentar el mdoc hasta `validUntil`.
- **Contraste:** el MSO de referencia de Multipaz usa validez de **30 días** con renovación
  frecuente; Inji Certify usa ~2 años sin renovación.

### 8.2 Confianza y PKI

| Pregunta | Veredicto |
|---|---|
| Jerarquía con límite de profundidad | Parcial |
| Rotación de DSC sin regenerar la IACA | **No resuelto (crítico)** |
| VICAL — formato y distribución | Resuelto (en Multipaz) |
| Revocación masiva por compromiso de IACA | Parcial |

- **Jerarquía.** Inji Certify solo adjunta el DSC activo al header COSE; construir y validar
  la cadena es responsabilidad del verificador. Multipaz soporta cadenas de N niveles
  (`maxPathDepth = 32`) con validación de `basicConstraints`/`pathLen`; el diseño estándar de
  ISO 18013-5 es de dos niveles (IACA → DSC).
- **Rotación de DSC (crítico #1).** No existe job ni mecanismo automático. La documentación del
  propio repo (`docs/PKI-Support-and-Integration-with-SD-JWT-VC.md:121-126`) declara:
  > *"Inji Certify does not automatically manage or renew externally signed certificates. If
  > the uploaded certificate expires, the Key Manager will fallback to using a self-signed
  > certificate and regenerate the keys accordingly."*

  Si el MTC no rota el DSC antes de expirar, Certify **firma con un certificado autofirmado sin
  bloquear el servicio ni alertar**, y rompe la confianza para todo verificador de terceros.
  La política `CERTIFY_VC_SIGN_EC_R1` define 1095 días de validez y 60 de preaviso, sin proceso
  que actúe sobre ellos.
- **VICAL.** Documento CBOR firmado (COSE_Sign1, ISO 18013-5 Anexo C) distribuido por HTTPS y
  consumible sin conexión (`VicalTrustManager`). El parser se probó contra VICALs reales de
  AAMVA (EE. UU.) y Austroads (Australia). El MTC no tiene una VICAL propia (consistente con
  que la IACA aún no está identificada, 2.4).
- **Compromiso de IACA.** Se resuelve retirando la entrada del `TrustManager` o republicando la
  VICAL, pero es manual y depende de que los verificadores refresquen. Multipaz no consulta
  CRL/OCSP en la validación de cadena.

### 8.3 Canales de presentación

| Pregunta | Veredicto |
|---|---|
| BLE/NFC de ISO 18013-5 (sin conexión) en la wallet | **No existe** |
| OpenID4VP en línea para mdoc en la wallet | Existe y es robusto |
| InjiVerify recibe una presentación sin conexión | No |
| Multipaz: ¿proximidad extraíble sin todo el SDK? | Parcial |

- **Sin conexión (crítico #4).** `inji-wallet` tiene máquinas de estado BLE
  (`machines/bleShare/`, `io.mosip:tuvali:0.5.2`), pero implementan un **protocolo propietario
  de MOSIP** (servicio BLE `'OVPMOSIP'`), no el de ISO 18013-5 (`DeviceEngagement`, servicios
  GATT, HKDF). `docs/mdoc-support.md:78` admite que el mdoc *"is not stored in persistent
  storage or shared via Bluetooth"*. No hay NFC. En `inji-verify` la pestaña "BLE" está
  deshabilitada y el backend solo entiende QR → HTTP POST.
- **En línea.** La presentación por OpenID4VP está completa en Android
  (`InjiOpenID4VPModule.java`) e iOS (`RNOpenID4VPModule.swift`). Limitación: la autenticación
  del dispositivo está limitada a **ES256** (`openID4VPServices.ts:162-165`).
- **Multipaz offline.** El código de proximidad está desacoplado de OpenID4VP, pero no existe
  un artefacto separado (`multipaz-proximity`); extraerlo requiere un fork con extracción
  selectiva de paquetes. Multipaz incluye además soporte de lectores NFC USB externos, pensado
  para mostradores o control fronterizo.

### 8.4 Privacidad y minimización

| Pregunta | Veredicto |
|---|---|
| Divulgación selectiva real para mdoc | **No resuelto (crítico)** |
| Unlinkability entre presentaciones | Parcial |
| Sobre-divulgación en la petición del verificador | No resuelto |
| Minimización de fotografía/biometría | No resuelto |

- **Divulgación selectiva (crítico #2).** `OpenID4VP.ts:112-129` (`extractCredential`):

  ```ts
  if (credentialFormat === VCFormat.mso_mdoc || credentialFormat === VCFormat.ldp_vc) {
    return vcData.verifiableCredential.credential;   // credencial COMPLETA, sin filtrar
  }
  if (credentialFormat === VCFormat.vc_sd_jwt || credentialFormat === VCFormat.dc_sd_jwt) {
    return this.processSdJwtVcForSharing(vcData, selectedDisclosures);  // sí filtra
  }
  ```

  `selectedDisclosures` se ignora para mdoc. La UI de consentimiento existe pero no tiene
  efecto: un verificador que solo necesita `over_18` recibe todo el namespace.
- **Efecto en cascada.** Esto anula la unlinkability que el emisor sí implementa
  (`addRandomSalts()` genera 24 bytes aleatorios por elemento): como el conjunto completo de
  digests e `issuerAuth` viaja idéntico a cada verificador, funciona como identificador
  estable del portador, y dos verificadores pueden correlacionar que atendieron a la misma
  persona.
- **Lado verificador.** `inji-verify` no soporta mdoc. Los 5 Presentation Definition
  configurados piden solo `$.type`, nunca un atributo individual; el modelo de datos sí
  soportaría peticiones granulares.
- **Fotografía.** No hay minimización; peor, si la credencial contiene imagen, la wallet exige
  "Share with Selfie" (`SendVPScreen.tsx:385-399`), tratando la biometría como requisito de
  autenticación en lugar de dato sensible.
- **Positivo.** La telemetría de la wallet está desactivada (`TelemetryUtils.js:18-44`), el
  activity log local no persiste datos personales y no se halló fuga de contenido en logs.

### 8.5 Interoperabilidad internacional — eIDAS / Unión Europea

**Hoy no existe vía legal ni técnica por la que un mDL del MTC sea reconocido automáticamente
en un país de la UE** bajo eIDAS 2.0 / EUDI Wallet. Fuentes: Reglamento (UE) 2024/1183,
Directiva (UE) 2025/2205, ARF del EUDI Wallet, decisiones de ejecución de la Comisión.

- **La UE no usa VICAL.** Su modelo de confianza para mdoc son Trusted Lists eIDAS (ETSI TS
  119 612, XML) con una List of Trusted Lists mantenida por la Comisión. Publicar una VICAL del
  MTC no ayuda con la UE, aunque sí con el ecosistema AAMVA / Norteamérica.
- **La norma relevante es la Directiva (UE) 2025/2205** (permisos de conducción, en vigor desde
  el 26.11.2025). Su mecanismo de notificación de emisores (Art. 5(5)) está restringido a
  Estados miembros. Para Perú hay dos ganchos a mediano plazo: el Art. 13 (reconocimiento de
  terceros países con seguridad vial comparable) y el mandato del Art. 5(7) de considerar el
  reconocimiento de permisos de la UE por autoridades de terceros países, con acto de
  ejecución previsto para el **26.11.2026**.

| | Interoperabilidad técnica | Reconocimiento legal |
|---|---|---|
| Requiere | mdoc conforme + IACA distribuida fuera de banda | Inscripción en una trusted list habilitada por acto jurídico de la UE |
| Decide | El operador del verificador | Comisión Europea / Consejo (Art. 218 TFUE) |
| Plazo | Inmediato, una vez exista la IACA del MTC | Sin camino abierto; no planificable |

**Encuadre recomendado:** la conformidad ISO 18013-5 (alcanzable, del MTC) y el reconocimiento
en la UE (depende de tratados y actos de la Comisión) son dos capas separadas; prometer la
segunda como consecuencia automática de la primera sería incorrecto. Además, el orden real es
inverso al digital: el permiso físico peruano debe reconocerse primero en España (convenios
UNECE o bilaterales) antes de que su versión digital tenga sentido reconocer.

### 8.6 Operación y monitoreo

| Pregunta | Veredicto |
|---|---|
| Logging sin fuga de datos personales | Parcial |
| Métricas y health checks | Parcial (hallazgo crítico) |
| Ledger como auditoría | Sí |
| Respuesta a incidentes — apagado selectivo de clave | Parcial |
| Disponibilidad ante fallo del HSM | Parcial (sin circuit breaker) |

- **Logging.** Uso consistente de `VCIssuanceUtil.abbreviateForLog()`; los datos personales no
  se registran. Gap menor: `clientId` se registra sin abreviar en 3 puntos.
- **Actuator (crítico #5, a confirmar).** En
  `docker-compose/docker-compose-injistack/config/certify-default.properties:72-73`:

  ```properties
  management.endpoint.env.show-values=ALWAYS
  management.endpoints.web.exposure.include=*
  ```

  **Alcance real:** vive solo en el `docker-compose` de desarrollo. **No aparece** en el Helm
  chart (`helm/inji-certify/values.yaml` solo referencia `/actuator/health` y
  `/actuator/prometheus`). No hay evidencia de que llegue al despliegue del MTC: puede estar
  sobrescrito, o vivir en un ConfigMap/Secret no visible desde el repo. Si el MTC desplegara
  ese archivo sin cambios, `/actuator/env` expondría credenciales de BD y HSM. **Acción:**
  confirmar en la configuración real que `management.endpoints.web.exposure.include` esté
  restringido a `health,info`, y `show-values` en `NEVER` o `WHEN_AUTHORIZED`.
- **Métricas.** Solo scrape genérico de JVM/HTTP, sin métricas de negocio (tasa de emisión o
  fallo, latencia de firma), y `prometheusRule.enabled=false`: sin alertas por defecto.
- **Ledger.** Registra toda emisión, mdoc incluido, aunque sin detalle de estado.
- **Respuesta a incidentes.** El esquema tiene los campos (`key_alias.status_code`,
  `key_policy_def.is_active`), pero no hay evidencia de que la firma los consulte; el
  procedimiento sugerido en el código es manual (`DELETE FROM key_alias WHERE alias=...`).
- **HSM.** Hay reintentos con backoff (`AWSCloudHSMKeyStoreImpl.java:73-74`, 5 × 10 s) y manejo
  del caso de replicación de claves de CloudHSM v5, pero no un circuit breaker: cada petición
  paga el retry completo (hasta 50 s) antes de fallar.
- **Rate limiting.** No hay en emisión ni verificación, más allá del proof-of-possession de
  OID4VCI.

### 8.7 Priorización antes de producción

1. **Cerrar el fallback silencioso a autofirmado** (8.2): proceso de rotación de DSC con alerta
   previa al vencimiento y alarma si Certify cae al camino autofirmado.
2. **Implementar divulgación selectiva real para mdoc** (8.4): filtrar `IssuerSignedItem` por
   `elementIdentifier` al armar el `DeviceResponse` y conectar `disclosedKeys` para mdoc en
   `VCProcessor`. Es trabajo acotado.
3. **Confirmar la exposición de Actuator en producción** (8.6) antes de "arreglarla".
4. **Conectar la revocación a mdoc** (8.1/8.3): extender el `case "mso_mdoc"` de
   `CertifyIssuanceServiceImpl` para usar el mecanismo de status list ya construido.
5. **Decidir el alcance sin conexión:** si el control en campo es prioritario, integrar
   Multipaz (Fase 6) en lugar de asumir que el BLE existente cubre ISO 18013-5.
6. **Encuadrar expectativas sobre la UE** (8.5) al comunicar este trabajo.

---

## Anexo A — Defectos encontrados en la prueba con dispositivo real

Primera prueba de la cadena completa: `inji-wallet` real en un Android físico (Galaxy S9+)
escaneando un QR de oferta OID4VCI real, contra un Mimoto e Inji Certify locales
([`compose/docker-compose.yml`](compose/docker-compose.yml)). El objetivo fue llegar a que el
mDL se emitiera, descargara, verificara y se mostrara completo, incluida la fotografía.

Se corrigieron **8 defectos**: 3 en el emisor (Inji Certify 0.14.0) y 5 en la wallet. Cada
uno se diagnosticó con evidencia directa (bytecode con `javap`, `logcat`, decodificación de
CBOR con `cbor2`, réplica del flujo OID4VCI con curl/Node) antes de gastar un escaneo real.

| # | Sistema | Defecto | Severidad |
|---|---|---|---|
| A.1 | Certify | Fragmento `#0` del `kid` rompe el proof JWT | Bloqueante |
| A.2 | Certify | `portrait` se codifica como `tstr` en vez de `bstr` | Alta |
| A.3 | Certify (config) | Certificado DSC con país `IN` rompe `verifyCountryName` | Bloqueante |
| A.4 | Wallet | `portrait` sin prefijo `data:` | Media |
| A.5 | Wallet | `issuerLogo` sin null-guard | Baja |
| A.6 | Wallet | `order` del well-known sin namespace: detalle en blanco | Alta |
| A.7 | Wallet | `driving_privileges` (array de objetos) crashea el render | Alta |
| A.8 | Wallet | `portrait` listado como texto en el detalle | Media |

Las correcciones del emisor (A.1, A.2) están en
[`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md); las de la wallet
(A.4–A.8) viven en un fork local de `inji-wallet` y deben llevarse al fork del MTC.

### A.1 Fragmento `#0` del `kid` rompe el proof JWT — Certify

`MDocProcessor.createDeviceKeyInfo` recorta el prefijo `did:jwk:` del `kid` pero no el
fragmento `#0` que exige el [spec did:jwk](https://github.com/quartzjer/did-jwk/blob/main/spec.md#to-create-the-did-url),
y `#` no es base64url válido:

```
java.lang.IllegalArgumentException: Illegal base64 character 23
	at io.mosip.certify.utils.MDocProcessor.createDeviceKeyInfo(MDocProcessor.java:418)
```

Confirmado con un proof JWT real de `io.mosip.vciclient` 0.6.0 (`kid` =
`did:jwk:eyJrdHkiOiJFQyIs...#0`). **Bloquea toda emisión `mso_mdoc` con esa wallet.**

**Corrección:** replicar el `split("#")[0]` que `DIDjwkProofManager.getKeyFromHeader` ya usa
correctamente en otro punto del código. En el entorno de pruebas se aplicó con Javassist
sobre `MDocProcessor.class`; **en producción debe aplicarse en el código fuente del fork de
Inji Certify del MTC.**

### A.2 `portrait` como `tstr` en vez de `bstr` — Certify

`MDocProcessor.preprocessForCBOR` tiene cuatro ramas (`byte[]`, `String`, `Map`, `List`) y
ninguna decodifica base64; todo `String` termina como `UnicodeString` (CBOR `tstr`), mientras
ISO 18013-5 exige un byte string para `portrait`. Es una conclusión cerrada por lectura de
bytecode: ningún cambio de template, nombre de campo o plugin puede corregirlo, porque la
decisión se toma en Java, corriente arriba del template.

Si además el plugin omite el campo, el marcador Velocity queda sin sustituir y se escribe
**literal** dentro del mDL; la wallet lo muestra como una imagen rota.

**Corrección (dos partes):**

1. En la rama `Map` de `preprocessForCBOR`, si el `Map` padre (el `IssuerSignedItem`
   completo) tiene `elementIdentifier == "portrait"` y la entrada actual es `elementValue`
   con un `String` no vacío, decodificarlo como base64 (estándar y luego urlsafe) a `byte[]`.
2. El plugin de datos debe entregar el campo con un JPEG real.

> **Lección:** una primera versión del parche comparaba `entry.getKey()` con `"portrait"`.
> Esa condición nunca puede ser verdadera, porque en un `IssuerSignedItem` esa cadena aparece
> como *valor* de `elementIdentifier`, no como clave. El parche quedó sin efecto, y pasó
> desapercibido porque `verifyValueDigests` da `match=True` sea `tstr` o `bstr`; solo falló el
> paso de Face Verification de la wallet, que necesita bytes JPEG reales. Verificar siempre
> que `portrait` llega como `bytes` en el CBOR decodificado.

### A.3 Certificado DSC con país incorrecto rompe `verifyCountryName` — Certify

El mDL se emitía y descargaba, pero la wallet siempre lo rechazaba
(`verifyingCredential → handleVCVerificationFailure`). `vcverifier-aar:1.5.0` ejecuta cinco
comprobaciones en orden: `verifyCertificateChain` (stub), `verifyCountryName`,
`verificationOfCoseSignature`, `verifyValueDigests`, `verifyDocType`. Replicándolas en Python
(`cbor2` + `cryptography`) contra un mDL real, `verifyValueDigests` pasaba en los 11 campos y
fallaba `verifyCountryName`.

Esta comprobación extrae el `C=` del Subject DN del DSC (regex `C=([^,]+)`) y lo compara con
`issuing_country` del mDL. El keystore autogenerado traía `C=IN` (India), del certificado
demo de MOSIP; con `issuing_country: "PE"` nunca coincidía.

**Causa:** `mosip.kernel.keymanager.certificate.default.country=IN` y
`mosip.kernel.keymanager.softhsm.certificate.country=IN` en
[`certify-default.properties`](compose/certify/certify-default.properties).

**Corrección:** `country=PE` (y organización, unidad, localidad y estado de MTC/Perú) en ambos
bloques. El cambio no basta por sí solo: hay que borrar el `local.p12` y `DELETE FROM
key_alias;` para forzar la regeneración. Esto aplica al entorno de pruebas; **en producción lo
equivalente es que el DSC de la CA del MTC (Fase 2) tenga `C=PE`.**

### A.4 `portrait` sin prefijo `data:` — wallet

Con A.1–A.3 resueltos la credencial se guardó, pero el detalle fallaba con
`ReactImageView: Image source "/9j/4AAQSkZJRgAB..." doesn't exist`. `getFaceAttribute`
(`components/VC/common/VCUtils.tsx`) pasa el `elementValue` crudo. En `ldp_vc`/SD-JWT el
emisor entrega `face` como data URI completa, pero ISO 18013-5 define `portrait` como bytes
JPEG crudos; `<Image>` de React Native solo interpreta URIs.

**Corrección:** anteponer `data:image/jpeg;base64,` solo en la rama `mso_mdoc`, con guard
`!faceField.startsWith('data:')`.

### A.5 `issuerLogo` sin null-guard — wallet

`ReactImageView: Image source "null" doesn't exist`. `VCCardViewContent.tsx` renderiza
`<Image src={issuerLogo?.url}>` aunque no haya URL. **Corrección:** condicionar el render a
`issuerLogo?.url`.

### A.6 `order` del well-known sin prefijo de namespace — wallet

El detalle abría en blanco: ninguno de los 11 campos. `getFieldValue`/`getFieldName` esperan
entradas `"namespace~elementIdentifier"` para `mso_mdoc`, pero el `order` del well-known de
Certify entrega nombres planos (`"family_name"`). Sin el `~`, `field.split('~')` no produce 2
partes y `fieldItemIterator` descarta cada campo.

**Corrección:** en `shared/openId4VCI/Utils.ts`
(`getCredentialIssuersWellKnownConfig`), normalizar cada entrada de `order` a
`namespace~field` resolviendo el namespace contra `claims`. Además: se corrigió un defecto
latente en el fallback (`fields.concat(...)` sin asignar no muta el array; ahora
`fields.push(...)`) y se blindó `iterateMsoMdocFor` con un fallback de forma
(`issuerSigned.nameSpaces` o `nameSpaces`).

### A.7 `driving_privileges` crashea el render — wallet

```
Objects are not valid as a React child (found: object with keys
{issue_date, expiry_date, vehicle_category_code})
```

Es un array de objetos por ISO 18013-5, y la rama `mso_mdoc` de `getFieldValue` lo pasaba
crudo. **Corrección:** si el valor es un array de objetos, formatearlo como lista separada por
comas de `vehicle_category_code`. Es el único campo del template con esta forma.

### A.8 `portrait` listado como texto en el detalle — wallet

La fila "Fotografía" mostraba el base64 crudo. `IMAGE_KEYS` ya excluía estos campos del
listado principal, pero no del detalle de `mso_mdoc`. **Corrección:** exportar `IMAGE_KEYS` y
filtrar en ambas ramas de construcción de `fields` (con `order` y fallback sobre `claims`).

### Resultado

Con A.1–A.8: emisión → descarga (proof JWT real) → verificación local (`vcverifier-aar`:
COSE_Sign1, digests, país y docType, sin bypass) → persistencia → detalle completo, con
fotografía, sin errores. Primera cadena mdoc completa sobre una wallet real, corrigiendo
defectos sin modificar su lógica de negocio.

**Verificador de campo.** `org.multipaz.identityreader` resultó **inutilizable** con esta
wallet: su único modo de presentación es proximidad por QR `mdoc:` (device engagement de ISO
18013-5), e `inji-wallet` no genera ese QR; el suyo es un formato propietario ("PixelPass").
Confirma empíricamente el hallazgo crítico #4.

### A.9 Divulgación selectiva: validación empírica del hallazgo crítico #2

Se escribió un verificador OpenID4VP mínimo (Node, herramienta de prueba no incluida en este
repositorio) que pide **un único campo** (`family_name`) con `limit_disclosure: "preferred"`.
(`"required"`, el valor que en DIF Presentation Exchange obliga a filtrar, fue rechazado por la
librería de la wallet `inji-openid4vp-aar:0.5.0` con `invalid_request`: ni el valor estricto del
spec está soportado.) Usó `client_id_scheme=redirect_uri` y `response_mode=direct_post.jwt`
(el único aceptado cuando hay `mso_mdoc`), con una clave pública X25519 / `ECDH-ES` +
`A256GCM` para descifrar la respuesta.

**Resultado.** Tras aceptar el consentimiento y pasar la Face Verification, el verificador
recibió y descifró un `vp_token` cuyo CBOR contenía **los 11 campos del mDL**
(`family_name`, `given_name`, `birth_date`, `issue_date`, `expiry_date`, `issuing_country`,
`issuing_authority`, `document_number`, `portrait`, `driving_privileges`,
`un_distinguishing_sign`), pese a pedir solo uno. Cualquier verificador que pida "¿es mayor de
edad?" recibe hoy el documento completo.

**Corrección sugerida** (8.7, punto 2): filtrar `IssuerSignedItem` por `elementIdentifier`
contra los `path` de cada `Field` del `presentation_definition` al armar el `DeviceResponse`.

---

## Referencias

**Repositorios del proyecto**

- [`hsm-patch/`](hsm-patch/) — parche de soporte EC para `AWSCloudHSMKeyStoreImpl` (Fase 1).
- [`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md) — correcciones de
  bytecode al emisor (Anexo A.1, A.2).
- [`yalvarez/inji-wallet-verification`](https://github.com/yalvarez/inji-wallet-verification) —
  parche `vc-verifier-patch/` (Fase 5.1) y puerto Swift `vc-verifier-patch/ios/` (Fase 5.0).

**Código de referencia**

- [`openwallet-foundation-labs/mdoc-ts`](https://github.com/openwallet-foundation-labs/mdoc-ts)
  (`@owf/mdoc`, `@owf/cose`) — librería de `verify/verify-mdoc.mjs` (Fase 6.2).
- [`openwallet-foundation/multipaz`](https://github.com/openwallet-foundation/multipaz) y
  [`multipaz-identity-reader`](https://github.com/openwallet-foundation/multipaz-identity-reader)
  — SDK y app de referencia (Fase 6.3).
- `mosip/keymanager`, `mosip/hsm-ref-impl`, `mosip/inji-wallet` (públicos) — base del parche
  HSM y comparación del defecto de iOS.

**Normativa**

- ISO/IEC 18013-5:2021 — Licencia de conducir móvil (mDL); ISO/IEC 18013-7 — presentación en
  línea.
- [Reglamento (UE) 2024/1183 — eIDAS 2.0](https://eur-lex.europa.eu/eli/reg/2024/1183/oj/eng)
  — Art. 14, 47 y 71; reconocimiento de terceros países (8.5).
- [Directiva (UE) 2025/2205 — permisos de conducción](https://eur-lex.europa.eu/eli/dir/2025/2205/oj/eng)
  — Art. 5 y 13; norma más relevante que eIDAS para un mDL de un tercer país (8.5).
- [EUDI Wallet Architecture Reference Framework](https://eudi.dev/) — modelo de confianza de la
  UE para mdoc (Trusted Lists ETSI TS 119 612).
- [Decisión de Ejecución (UE) 2025/2164](https://eur-lex.europa.eu/eli/dec_impl/2025/2164/oj)
  — formato vigente de trusted lists eIDAS.
