# mDL for the MTC — Digital Driver's Licence (ISO/IEC 18013-5)

Proof of concept and implementation guide so that **Inji Certify** at the Ministry of
Transport and Communications (MTC) can also issue the Driver's Licence as a
**mobile driving licence (mDL)** conforming to ISO/IEC 18013-5, alongside the SD-JWT it
already issues today, without replacing it.

> 🇪🇸 Versión en español: [README.md](README.md) · [IMPLEMENTATION.md](IMPLEMENTATION.md)

| Document | Purpose |
|---|---|
| **this README** | Context on the standard, status of the work, and how to run the test environment |
| [IMPLEMENTATION.en.md](IMPLEMENTATION.en.md) | Phased operational guide to bring the mDL to the MTC's real infrastructure |

---

## 1. What is ISO/IEC 18013-5?

**ISO/IEC 18013-5** (published in 2021) is the international standard that defines the
**mobile driving licence (mDL)**: a driving document that lives on the holder's phone and
that any conforming reader — whether from the same authority, from another jurisdiction, or
from an authorised third party — can verify without depending on a proprietary service.

The standard specifies, end to end:

- **Data model (`mdoc`).** A CBOR document with a `docType`
  (`org.iso.18013.5.1.mDL`) and a defined set of elements: name, date of birth,
  photograph, issuing authority, and `driving_privileges` (driving categories with their
  issue and expiry dates).
- **Issuer authenticity.** The authority signs a *Mobile Security Object* (MSO) with its own
  certificate (**DSC**, Document Signer Certificate) that chains to a national root of
  trust (**IACA**, Issuing Authority CA). Any verifier that knows the IACA can check
  that the document was issued by that authority and has not been altered.
- **Selective disclosure.** Each element is signed separately by means of a digest: the
  holder decides which fields to reveal. An officer who only needs to know whether the licence
  is valid and which category it authorises has no reason to receive the date of birth or the
  home address.
- **Device binding.** The document is tied to a key stored on the holder's
  phone; copying the file to another device is of no use.
- **In-person, offline presentation.** The reader and the phone exchange data over
  **BLE or NFC**, with no internet needed on either side. Online presentation
  (OpenID4VP) is specified in ISO/IEC 18013-7.

### Why it makes sense to adopt it at the MTC and nationwide

| Benefit | What it means for the MTC |
|---|---|
| **One standard, one ecosystem** | The mDL is the format on which phone wallets, roadside readers, US and Australian licensing programmes, and European regulation are converging. Adopting it avoids inventing a proprietary format and allows reuse of existing readers, SDKs and libraries. |
| **Roadside checks without connectivity** | BLE/NFC verification works where there is no coverage — relevant on inter-provincial routes. SD-JWT/W3C do not define this channel. |
| **Privacy by design** | Selective disclosure reduces the personal data exposed at each check, a natural requirement under the Personal Data Protection Law (Law 29733). |
| **Trust anchored in the State** | The signature is validated against an IACA of the Peruvian State (MTC); it does not depend on a private provider or on querying a service at every verification. |
| **Complements, does not replace** | A new `credential_config` is added to the same Inji Certify that already issues SD-JWT: the same issuance infrastructure, identity (IdPeru/Mimoto) and wallet. |
| **Regulatory positioning** | Directive (EU) 2025/2205 on digital driving licences and the EUDI Wallet use `mdoc`. Being conformant is the technical prerequisite to any recognition discussion. |

> **Scope clarification.** Technical conformance with ISO/IEC 18013-5 **is not the same as**
> legal recognition in another country. Today there is no route through which the EU
> would automatically recognise a Peruvian mDL; that recognition depends on agreements and
> implementing acts outside the MTC's control (see [IMPLEMENTATION.en.md § 8.5](IMPLEMENTATION.en.md#85-international-interoperability--eidas--european-union)).
> What the MTC does control and can deliver is technical conformance.

---

## 2. Repository contents

```
.
├── IMPLEMENTATION.en.md       Phased operational guide (read after this README)
├── compose/                   Reproducible test environment (Docker Compose)
│   ├── docker-compose.yml       Postgres + Inji Certify 0.14.0 + nginx (HTTPS)
│   ├── certify/
│   │   ├── init-preauth.sql       Inji Certify base schema
│   │   ├── init-mdoc.sql          EC key policy + mDL credential_config
│   │   ├── render-mdoc-template.mjs  Generates the mDL Velocity template
│   │   ├── mock-fee-plugin/       Mock data plugin (reference contract)
│   │   └── patched-jars/          Bytecode fixes for Inji Certify 0.14.0
│   └── scripts/run-e2e.sh       Full OID4VCI flow + verification
├── verify/                    Standalone mdoc verifier (@owf/mdoc)
└── hsm-patch/                 Patch: EC key support in CloudHSM
```

---

## 3. Status of the work

mDL issuance with Inji Certify v0.14.0 works end to end, including download and
display in a real `inji-wallet` on an Android device. What remains for
production is bounded and has a written recipe in [IMPLEMENTATION.en.md](IMPLEMENTATION.en.md).

| Area | Status |
|---|---|
| mso_mdoc issuance from Inji Certify 0.14.0 | ✅ Validated against the real image |
| Download, local verification and detail view in InjiWallet (Android) | ✅ Validated on a physical device, with 2 fixes to the issuer and 5 to the wallet |
| EC P-256 signing key on CloudHSM | ⚠️ Patch written; still to be validated on development hardware |
| DSC certificate from the MTC CA and root IACA | ⏳ Organisational process |
| Real FEE data plugin | ⏳ The actual shape of the service response still needs to be confirmed |
| Verification in the iOS wallet | 🔴 **Blocking:** `mso_mdoc` is always reported as valid. Swift port ready and tested (9/9); integration pending |
| Issuer trust verification on Android | ⚠️ The library does not validate the chain; patch ready, integration pending |
| Third-party verification (InjiVerify) | ⚠️ Does not support `mso_mdoc`; 3 paths evaluated |
| Selective disclosure in the wallet | 🔴 Does not work for mdoc: all fields are sent |
| Revocation, BLE/NFC offline channel | 🔴 Do not exist in the current stack for mdoc |

### Verified technical findings on Inji Certify 0.14.0

Confirmed by running the real image and reading its bytecode; they are the basis of the steps in the guide.

- **The emitted CBOR is wrapped** in `{docType, issuerSigned}`. InjiWallet tolerates it by
  design; the standalone verifier requires unwrapping it.
- **Claims are posted nested under the ISO namespace:**
  `{"claims": {"org.iso.18013.5.1": {...}}}`.
- **The holder identifier arrives in `identityDetails.sub`**, not in `individualId`.
- **`driving_privileges` must travel as an already-serialised JSON string**, and its marker in
  the Velocity template goes without quotes; otherwise Velocity fails with
  `JSONException: Expected a ',' or '}'`.
- **The plugin SPI** is `io.mosip.certify.api.spi.DataProviderPlugin`
  (`fetchData(Map<String,Object>): JSONObject`).
- **Two issuer defects** prevent issuing an mDL that a real wallet can consume
  (`createDeviceKeyInfo` and the encoding of `portrait`); both have a bytecode fix in
  [`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md) and must also be applied
  to the production Certify ([IMPLEMENTATION.en.md, Annex A](IMPLEMENTATION.en.md#annex-a--defects-found-in-the-real-device-test)).

---

## 4. Test environment

Reproduces the full issuance locally, without touching MTC infrastructure.

**Requirements:** Docker with Compose v2, Java 21 and Maven, Node.js, OpenSSL.

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

`run-e2e.sh` runs the complete OID4VCI *pre-authorized code* flow for two test holders
(1 and 4 driving categories), extracts the IACA from the environment's keystore, and runs the
standalone verifier on each issued mDL.

**Scope.** This environment signs with the image's local PKCS12 keystore and uses simulated
data. It does not cover CloudHSM, the real MTC CA certificate, or the real FEE service;
those steps are in [IMPLEMENTATION.en.md](IMPLEMENTATION.en.md).

### Standalone verifier

```bash
node verify/verify-mdoc.mjs <archivo.cbor> <iaca.pem> \
  [--expected-elements=N] [--doctype=X] [--namespace=Y]
```

It uses `@owf/mdoc` and `@owf/cose` (OpenWallet Foundation), an implementation independent of
Inji's. It runs 13 checks: `IssuerSigned` structure, COSE signature and X.509 chain up to
the IACA, `docType`, `valueDigests`, committed elements, shape of `driving_privileges`,
`validityInfo` and device key binding. It checks **integrity and chain**; trust
in the IACA is defined by whoever runs it, by choosing which root certificate to pass.

---

## 5. How to proceed

Read [IMPLEMENTATION.en.md](IMPLEMENTATION.en.md): it starts with the **pending-items register and critical path** (what is missing, who closes it, and what to start first), follows with the feasibility verdict and continues
phase by phase (key in HSM → DSC certificate → issuance configuration → data plugin →
wallet → third-party verification), closing with the pre-production checklist and a
maturity audit.

## Licence and credits

This repository documents and extends open-source components from [MOSIP](https://www.mosip.io)
(Inji Certify, Inji Wallet, Inji Verify, Keymanager) and uses libraries from the OpenWallet Foundation
(`@owf/mdoc`, `@owf/cose`, Multipaz). Patches to MOSIP code are distributed for
review by the MTC team and should also be proposed to the upstream project.
