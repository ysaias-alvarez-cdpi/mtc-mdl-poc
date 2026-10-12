# mDL para el MTC — Licencia de Conducir digital (ISO/IEC 18013-5)

Prueba de concepto y guía de implementación para que **Inji Certify** del Ministerio de
Transportes y Comunicaciones (MTC) emita la Licencia de Conducir también como
**mobile driving licence (mDL)** conforme a ISO/IEC 18013-5, junto al SD-JWT que ya emite
hoy, sin reemplazarlo.

> 🇬🇧 English version: [README.en.md](README.en.md) · [IMPLEMENTATION.en.md](IMPLEMENTATION.en.md)

| Documento | Para qué sirve |
|---|---|
| **este README** | Contexto del estándar, estado del trabajo y cómo correr el entorno de pruebas |
| [IMPLEMENTATION.md](IMPLEMENTATION.md) | Guía operativa por fases para llevar el mDL a la infraestructura real del MTC |

---

## 1. ¿Qué es ISO/IEC 18013-5?

**ISO/IEC 18013-5** (publicada en 2021) es el estándar internacional que define la
**licencia de conducir móvil (mDL)**: un documento de conducir que vive en el teléfono del
titular y que cualquier lector conforme —sea de la misma autoridad, de otra jurisdicción o de
un tercero autorizado— puede verificar sin depender de un servicio propietario.

El estándar especifica, de punta a punta:

- **Modelo de datos (`mdoc`).** Un documento CBOR con un `docType`
  (`org.iso.18013.5.1.mDL`) y un conjunto definido de elementos: nombre, fecha de nacimiento,
  fotografía, autoridad emisora y `driving_privileges` (categorías de conducción con su fecha
  de emisión y vencimiento).
- **Autenticidad del emisor.** La autoridad firma un *Mobile Security Object* (MSO) con un
  certificado propio (**DSC**, Document Signer Certificate) que encadena a una raíz de
  confianza nacional (**IACA**, Issuing Authority CA). Cualquier verificador que conozca la
  IACA puede comprobar que el documento fue emitido por esa autoridad y no fue alterado.
- **Divulgación selectiva.** Cada elemento se firma por separado mediante un digest: el
  titular decide qué campos revela. Un agente que solo necesita saber si la licencia está
  vigente y qué categoría habilita no tiene por qué recibir la fecha de nacimiento ni el
  domicilio.
- **Vinculación al dispositivo.** El documento queda atado a una clave guardada en el
  teléfono del titular; copiar el archivo a otro dispositivo no sirve.
- **Presentación presencial y sin conexión.** El lector y el teléfono intercambian datos por
  **BLE o NFC**, sin necesidad de internet en ninguno de los dos lados. La presentación en
  línea (OpenID4VP) se especifica en ISO/IEC 18013-7.

### ¿Por qué conviene incorporarlo en el MTC y en el país?

| Beneficio | Qué significa para el MTC |
|---|---|
| **Un estándar, un ecosistema** | El mDL es el formato en el que convergen wallets de teléfono, lectores de control, programas de licencias de Estados Unidos y Australia, y la regulación europea. Adoptarlo evita inventar un formato propio y permite reutilizar lectores, SDKs y librerías ya existentes. |
| **Control en carretera sin conectividad** | La verificación por BLE/NFC funciona donde no hay cobertura — relevante en rutas interprovinciales. SD-JWT/W3C no definen este canal. |
| **Privacidad por diseño** | La divulgación selectiva reduce el dato personal expuesto en cada control, un requisito natural bajo la Ley de Protección de Datos Personales. |
| **Confianza anclada al Estado** | La firma se valida contra una IACA del Estado peruano (MTC); no depende de un proveedor privado ni de consultar un servicio en cada verificación. |
| **Complementa, no reemplaza** | Se agrega un nuevo `credential_config` en el mismo Inji Certify que ya emite SD-JWT: la misma infraestructura de emisión, identidad (IdPeru/Mimoto) y wallet. |
| **Posicionamiento regulatorio** | La Directiva (UE) 2025/2205 sobre permisos de conducción digitales y el EUDI Wallet usan `mdoc`. Ser conforme es el requisito técnico previo a cualquier conversación de reconocimiento. |

> **Precisión de alcance.** Conformidad técnica con ISO/IEC 18013-5 **no equivale** a
> reconocimiento legal en otro país. Hoy no existe una vía por la que la UE reconozca
> automáticamente un mDL peruano; ese reconocimiento depende de acuerdos y actos de ejecución
> fuera del control del MTC (ver [IMPLEMENTATION.md § 8.5](IMPLEMENTATION.md#85-interoperabilidad-internacional--eidas--unión-europea)).
> Lo que el MTC sí controla y puede entregar es la conformidad técnica.

---

## 2. Contenido del repositorio

```
.
├── IMPLEMENTATION.md          Guía operativa por fases (leer después de este README)
├── compose/                   Entorno de pruebas reproducible (Docker Compose)
│   ├── docker-compose.yml       Postgres + Inji Certify 0.14.0 + nginx (HTTPS)
│   ├── certify/
│   │   ├── init-preauth.sql       Esquema base de Inji Certify
│   │   ├── init-mdoc.sql          key policy EC + credential_config del mDL
│   │   ├── render-mdoc-template.mjs  Genera el template Velocity del mDL
│   │   ├── mock-fee-plugin/       Plugin de datos simulado (contrato de referencia)
│   │   └── patched-jars/          Correcciones de bytecode a Inji Certify 0.14.0
│   └── scripts/run-e2e.sh       Flujo OID4VCI completo + verificación
├── verify/                    Verificador standalone de mdoc (@owf/mdoc)
└── hsm-patch/                 Parche: soporte de claves EC en CloudHSM
```

---

## 3. Estado del trabajo

La emisión de mDL con Inji Certify v0.14.0 funciona de punta a punta, incluida la descarga y
visualización en una wallet `inji-wallet` real sobre un dispositivo Android. Lo que falta para
producción está acotado y tiene receta escrita en [IMPLEMENTATION.md](IMPLEMENTATION.md).

| Área | Estado |
|---|---|
| Emisión mso_mdoc desde Inji Certify 0.14.0 | ✅ Validada contra la imagen real |
| Descarga, verificación local y detalle en InjiWallet (Android) | ✅ Validada en dispositivo físico, con 2 correcciones al emisor y 5 a la wallet |
| Clave de firma EC P-256 sobre CloudHSM | ⚠️ Parche escrito; falta validarlo en hardware de desarrollo |
| Certificado DSC de la CA del MTC e IACA raíz | ⏳ Trámite organizacional |
| Plugin de datos FEE real | ⏳ Falta confirmar la forma real de la respuesta del servicio |
| Verificación en wallet iOS | 🔴 **Bloqueante:** `mso_mdoc` se reporta siempre como válido. Puerto Swift listo y probado (9/9); falta integrarlo |
| Verificación de confianza del emisor en Android | ⚠️ La librería no valida la cadena; parche listo, falta integrarlo |
| Verificación por terceros (InjiVerify) | ⚠️ No soporta `mso_mdoc`; hay 3 caminos evaluados |
| Divulgación selectiva en la wallet | 🔴 No funciona para mdoc: se envían todos los campos |
| Revocación, canal offline BLE/NFC | 🔴 No existen en el stack actual para mdoc |

### Hallazgos técnicos verificados sobre Inji Certify 0.14.0

Confirmados ejecutando la imagen real y leyendo su bytecode; son la base de los pasos de la guía.

- **El CBOR emitido va envuelto** en `{docType, issuerSigned}`. InjiWallet lo tolera por
  diseño; el verificador standalone requiere desenvolverlo.
- **Las claims se postean anidadas bajo el namespace ISO:**
  `{"claims": {"org.iso.18013.5.1": {...}}}`.
- **El identificador del titular llega en `identityDetails.sub`**, no en `individualId`.
- **`driving_privileges` debe viajar como string JSON ya serializado**, y su marcador en el
  template Velocity va sin comillas; de otro modo Velocity falla con
  `JSONException: Expected a ',' or '}'`.
- **El SPI del plugin** es `io.mosip.certify.api.spi.DataProviderPlugin`
  (`fetchData(Map<String,Object>): JSONObject`).
- **Dos defectos del emisor** impiden emitir un mDL consumible por una wallet real
  (`createDeviceKeyInfo` y la codificación de `portrait`); ambos tienen corrección de bytecode en
  [`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md) y deben aplicarse
  también al Certify de producción ([IMPLEMENTATION.md, Anexo A](IMPLEMENTATION.md#anexo-a--defectos-encontrados-en-la-prueba-con-dispositivo-real)).

---

## 4. Entorno de pruebas

Reproduce localmente la emisión completa, sin tocar infraestructura del MTC.

**Requisitos:** Docker con Compose v2, Java 21 y Maven, Node.js, OpenSSL.

```bash
# 1. Compilar el plugin de datos simulado
(cd compose/certify/mock-fee-plugin && mvn package)

# 2. Dependencias de Node
(cd verify && npm install)
(cd compose/scripts && npm install)

# 3. Certificado TLS de desarrollo (nginx sirve HTTPS: la wallet exige https://)
bash compose/scripts/gen-dev-cert.sh

# 4. Levantar el entorno y emitir
cd compose
docker compose up -d
bash scripts/run-e2e.sh
```

`run-e2e.sh` ejecuta el flujo OID4VCI *pre-authorized code* completo para dos titulares de
prueba (1 y 4 categorías de conducción), extrae la IACA del keystore del entorno, y corre el
verificador standalone sobre cada mDL emitido.

**Alcance.** Este entorno firma con el keystore PKCS12 local de la imagen y usa datos
simulados. No cubre CloudHSM, el certificado real de la CA del MTC ni el servicio FEE real;
esos pasos están en [IMPLEMENTATION.md](IMPLEMENTATION.md).

### Verificador standalone

```bash
node verify/verify-mdoc.mjs <archivo.cbor> <iaca.pem> \
  [--expected-elements=N] [--doctype=X] [--namespace=Y]
```

Usa `@owf/mdoc` y `@owf/cose` (OpenWallet Foundation), una implementación independiente de la
de Inji. Ejecuta 13 comprobaciones: estructura `IssuerSigned`, firma COSE y cadena X.509 hasta
la IACA, `docType`, `valueDigests`, elementos comprometidos, forma de `driving_privileges`,
`validityInfo` y vinculación de la device key. Comprueba **integridad y cadena**; la confianza
en la IACA la define quien lo ejecuta al elegir qué certificado raíz pasar.

---

## 5. Cómo seguir

Lea [IMPLEMENTATION.md](IMPLEMENTATION.md): empieza con el **registro de pendientes y la ruta crítica** (qué falta, quién lo cierra y qué iniciar primero), sigue con el veredicto de viabilidad y continúa
fase por fase (clave en HSM → certificado DSC → configuración de emisión → plugin de datos →
wallet → verificación por terceros), cerrando con el checklist previo a producción y una
auditoría de madurez.

## Licencia y créditos

Este repositorio documenta y extiende componentes de código abierto de [MOSIP](https://www.mosip.io)
(Inji Certify, Inji Wallet, Inji Verify, Keymanager) y usa librerías de la OpenWallet Foundation
(`@owf/mdoc`, `@owf/cose`, Multipaz). Los parches sobre código de MOSIP se distribuyen para
revisión del equipo del MTC y deben proponerse también al proyecto original.
