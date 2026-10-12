# Implementation guide — mDL (ISO/IEC 18013-5) in MTC production

Runbook for bringing issuance of the Driving License as a **conformant mdoc**
(`mso_mdoc`) to the MTC's real infrastructure, alongside the SD-JWT it already issues today,
without replacing it. For the context of the standard and how to run the test environment, see
the [README](README.en.md).

Each phase states what to run, in what order, and how to confirm it was done correctly. The
technical claims were verified against real source code (bytecode of the Inji Certify image,
MTC and MOSIP repositories) or by running the test environment.

**Reference repositories**

| Repository | Role |
|---|---|
| `IUGO-MTC/inji-certify` (branch `main`, v0.14.0) | Issuer — MTC fork |
| `IUGO-MTC/inji-dataprovider` | Real FEE data plugin and `credential_config` SQL |
| `IUGO-MTC/inji-hsm` | Terraform for the CloudHSM cluster |
| `inji-wallet` (MTC fork) | Wallet |
| `inji-verify` (MTC fork) | Verifier |
| [`yalvarez/inji-wallet-verification`](https://github.com/yalvarez/inji-wallet-verification) | Trust patch for `vc-verifier` (Android) and Swift port for iOS |

## Status by phase

| Phase | Status |
|---|---|
| 0. Product decisions | Pending MTC decision |
| 1. EC signing key in CloudHSM | Patch ready (`hsm-patch/`); still needs validation on hardware |
| 2. DSC certificate from the MTC CA | Procedure documented; organizational process; profile and validity to be confirmed (2.5) |
| 3. `credential_config` in Inji Certify | Validated in the test environment; SQL ready to adapt |
| 4. Real FEE data plugin | Mock validated as a contract; real implementation pending |
| 5. Wallet (iOS and Android) | **iOS: critical blocker.** Swift port tested (9/9); still needs integration. Android: trust patch ready |
| 6. Third-party verification | Gap confirmed in InjiVerify; 3 alternatives evaluated |
| 7. Conformance and pre-production checklist | Interoperability plan defined; not executed |
| 8. Maturity audit | 5 critical findings to resolve before real production |
| Annex A. Real-device test | 8 defects fixed (3 in the issuer, 5 in the wallet) |

---

## Pending items register and critical path

Everything that today prevents issuing and operating mDL in production, gathered in one place. The
**Owner** column indicates who has the access or authority to close each item according to the
repository or role involved; **the names of specific people and teams are yet to be
assigned by the MTC**. No deadlines are estimated: they depend on third parties and on the MTC's schedule.

**Type:** D = decision · E = external dependency · DEV = development · V = pending validation.

| ID | Pending item | Type | Phase | Owner (role) | Blocks | Status |
|---|---|---|---|---|---|---|
| P1 | Decide one credential per holder or one per class | D | 0.1 | MTC Product | Phase 3 | Open |
| P2 | Define the root IACA: who issues, safeguards and rotates it | D / E | 2.4 | MTC CA | P4, P11, P12 | Open |
| P3 | Confirm the profile required of the IACA and DSC and their maximum validities (2.5) | V | 2.5 | MTC CA + Certify team | P4 | Open |
| P4 | Obtain the DSC signed by the CA | E | 2.1 | MTC CA | Real issuance | Open |
| P5 | Have a **non-production** CloudHSM available to validate the patch (1.2) | D / E | 1.2 | Infrastructure (`inji-hsm`) + Product | P6 | The MTC only has the production CloudHSM; a way to obtain a non-production one must be decided |
| P6 | Validate the HSM EC patch on hardware | V | 1.2 | Certify team (`inji-certify`) | P4 | Patch written, not validated |
| P7 | Obtain a real response from the FEE service and confirm its shape | V | 4.2 | Data team (`inji-dataprovider`) | P8 | Open |
| P8 | Implement the real FEE plugin for the mDL | DEV | 4 | Data team (`inji-dataprovider`) | Real issuance | Mock ready as a contract |
| P9 | Apply fixes A.1 (`kid` with `#0`) and A.2 (`portrait`) to the production Certify | DEV | Annex A | Certify team (`inji-certify`) | Any issuance with a real wallet | Bytecode patch only in testing |
| P10 | Confirm that Mimoto is deployed and available | V | 7.2 | Infrastructure | Any mDL retrieval | Unconfirmed |
| P11 | Wallet trust store with anchor refresh | DEV | 5.2 | Wallet team (`inji-wallet`) | Trust verification | Not built |
| P12 | Define what is published to distribute trust (VICAL, IACA certificate, or both) and who signs and maintains it | D / E | 2.4 | MTC CA + Product | P11, Phase 6 | Open |
| P13 | Integrate the Swift port (React Native bridging) and replace the iOS hardcode | DEV | 5.0 | Wallet team (`inji-wallet`) | iOS launch | Port tested (9/9), not integrated |
| P14 | Publish the patched `vc-verifier` AAR and point the wallet to it | DEV | 5.1 | Wallet team (`inji-wallet`) | Trust verification (Android) | Patch ready, not built against the full module |
| P15 | Choose the third-party verification path and execute it | D / DEV | 6 | Product + verifier team (`inji-verify`) | Third-party verification | Alternatives evaluated |
| P16 | DSC rotation process with alerting, and an alarm on fallback to self-signed | DEV / D | 8.2 | Operations + MTC CA | Secure operation | Undefined |
| P17 | Real selective disclosure for mdoc in the wallet | DEV | 8.4 | Wallet team (`inji-wallet`) | Privacy | Not built |
| P18 | Connect revocation to `mso_mdoc` | DEV | 8.1 / 8.3 | Certify team (`inji-certify`) | Lifecycle | Not built |
| P19 | Confirm the Actuator configuration in production | V | 8.6 | Operations | — | Unconfirmed |
| P20 | Decide the offline scope (BLE/NFC) | D | 8.3 | MTC Product | Field checks | Open |
| P21 | Test interoperability with an independent implementation (7.1) | V | 7.1 | Certify team + verifier | Declaring conformance | Open |
| P22 | Confirm whether the MTC requires a conformance certification scheme or legal assessment | D | 7.1 | Product + MTC legal | — | Not investigated |

### Critical path

The chain that determines when a real, State-signed mDL can be issued is:

```
P5 non-production CloudHSM → P6 validate EC patch → CSR (1.4)
        → P3 certificate profile confirmed with the CA → P4 signed DSC (Phase 2)
        → DSC upload (2.2) → real issuance with P8 and P9 already applied
```

**Start from day one**, because they depend on third parties and cannot be sped up with in-house
technical work: P2 and P3 (defining the IACA and its profile with the CA), P5 (hardware), P7
(FEE sample) and P10 (Mimoto status). The rest can proceed in parallel:

- **Wallet:** P13 (iOS), P14 (Android AAR) and P17 (selective disclosure) are independent of
  the issuer chain. P13 is a launch blocker.
- **Issuer:** P8 and P9 can be built and tested with the local environment before having a
  real certificate.
- **Third-party verification:** P15 and P12 are defined while waiting for the DSC.

---

## Feasibility verdict

**It is feasible to issue mdoc with Inji Certify and launch simultaneously on Android and iOS.**
No finding invalidates the issuer architecture or the mdoc format. What remains is bounded,
has an identified solution, and is concentrated in the wallet.

**Signing key decision.** The MTC currently signs SD-JWT with Ed25519
(`CERTIFY_VC_SIGN_ED25519`). ISO/IEC 18013-5 requires ECDSA (P-256 or another NIST curve) for
`mso_mdoc`; Ed25519 is not conformant. Since SD-JWT is not yet in production, **it is
recommended to define ECDSA P-256 as the system's single signing key from the start**, used for
both formats: one HSM and certificate process instead of two.

### What works today

- **mdoc issuance from Inji Certify 0.14.0**, validated against the real image, with a real
  wallet and a physical device (Annex A).
- **The wrapped CBOR `{docType, issuerSigned}`** that Inji Certify produces is not a problem
  for InjiWallet: `vcverifier-aar:1.5.0` tolerates it by design.

### What is missing (execution with a written recipe)

| Pending item | Implication if not done |
|---|---|
| **EC key in CloudHSM.** The fork's `AWSCloudHSMKeyStoreImpl` only generates RSA; the patch is in `hsm-patch/`. | `generate-csr` for the EC key fails in the HSM. |
| **DSC certificate from the MTC CA.** 3-step procedure confirmed in code. | It is a process with its own lead time; if it is not started in parallel, it becomes the critical path. |
| **Real FEE data plugin.** The actual shape of the FEE service response has not been confirmed. | If the FEE does not deliver categories with per-category dates, the mdoc violates ISO 18013-5 Table 3. |
| **Issuer fixes** (Annex A.1 and A.2): `kid` with `#0` fragment and `portrait` as `bstr`. | No real wallet can obtain the mDL (A.1), or the photograph is mistyped (A.2). |
| **Issuer trust on Android.** `verifyCertificateChain()` returns `true` without validating. | A self-signed mdoc would be reported as valid. Patch ready; it still needs to be integrated, plus a trust store. |

### The point that is still a "no, not yet": iOS

Two verifications must be distinguished:

1. **The wallet verifying what it receives or stores:** when receiving the credential, when
   opening its detail, when restoring a backup. These are always internal self-checks.
2. **The external verifier verifying a presentation.** The wallet validates nothing in the
   presentation flow; that guarantee belongs to the verifier.

**The iOS defect is in point 1.** `verifyCredentialForIos()` returns a hardcoded success for
`mso_mdoc`, without validating signature, digests or chain. The iOS wallet does not detect a
corrupted credential or one injected into its storage. It is a defect of the official
`mosip/inji-wallet` project (present on its `main`), inherited unchanged by the MTC fork.

**Why it is not solved in TypeScript.** `mso_mdoc` is binary CBOR/COSE; the only JS
verification library in the app (`@digitalcredentials/vc`) only understands JSON-LD. On Android,
MOSIP wrote a native Kotlin library (`vc-verifier`) with a thin bridge
(`RNVCVerifierModule.java`). **For iOS the equivalent was never written.**

**Status of the Swift port.** A complete port of `vc-verifier` exists, mapped method by method
against the real Kotlin (CBOR decoding, COSE_Sign1 with CryptoKit, X.509 chain with `SecTrust`,
React Native bridge). It compiles and passes **9/9 tests** on a real GitHub Actions macOS
runner, including an end-to-end verification against a real mdoc. What remains is what no
generic CI can cover: the React Native bridging inside the real Xcode project of
the MTC's `inji-wallet`.

**Recommended decision.** Launch Android and iOS **simultaneously**, with real verification on
both. Launching only Android would leave a functionality gap between platforms that users
perceive as "the digital State does not work on iPhone". The current iOS hardcode must not
reach production under any circumstances. If the integration does not close in time, the
contingency is **fail-closed**: do not offer `mso_mdoc` on iOS until the port is integrated.

### Recommended scope

1. Issue mdoc with a unified EC P-256 key (Phases 1–4).
2. Apply the trust patch and the trust store on Android (5.1–5.2).
3. Integrate the Swift port before launch (5.0) and launch on both platforms at once.
4. Decide in parallel the third-party verification path (Phase 6).

---

## Phase 0 — Product decisions

They must be made before touching infrastructure.

### 0.1 One credential per holder or one per license class

SD-JWT currently issues 3 separate credentials (classes A/B/E). In mdoc, ISO/IEC 18013-5 models
**all of a person's current categories in a single `driving_privileges`**, within a single
credential. This guide assumes that model (`credential_config_key_id =
'MTCDrivingLicenseMDL'`, one row).

Replicating the "one row per class" pattern would generate three mdocs with one category each,
which is neither the intended use nor what a third-party verifier expects. **Action:** confirm
with product whether there is a legitimate use case for presenting a single class. If there is,
Phase 3 is adapted to 3 rows (`MTCDrivingLicenseAMDL`/`B`/`E`); the rest does not change.

### 0.2 External dependencies and delivery date

Each phase has dependencies with their own lead times: MTC CA, non-production CloudHSM
hardware, access to the wallet/verifier forks, Mimoto deployment. **Confirm which are
available before setting a date.**

### 0.3 Reproduce the local environment

It is the fastest way to learn the complete flow without risk. See
[README § Test environment](README.en.md#4-test-environment).

---

## Phase 1 — EC signing key in CloudHSM

### 1.1 The HSM blocker

The fork's `AWSCloudHSMKeyStoreImpl.java` (branch `feature/cloud-hsm`,
`certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/`) generates keys with
`generateKeyPair`, which **always builds an RSA `AlgorithmParameterSpec`** and has no branch
for EC:

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

MOSIP's business layer (`KeymanagerServiceImpl`) does know how to request `EC_SECP256R1_SIGN`
(mapped to P-256); the gap is exclusively in this class. Without the patch, `generate-csr` with
that reference fails in the HSM.

### 1.2 Apply the patch

```bash
cd /path/to/IUGO-MTC/inji-certify
git checkout feature/cloud-hsm
git log -1 -- certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/AWSCloudHSMKeyStoreImpl.java
# confirm the file has not changed since the patch was written
git apply /path/to/mtc-mdl-poc/hsm-patch/AWSCloudHSMKeyStoreImpl.java.patch
```

**Where to validate the patch.** Today the MTC only has the production CloudHSM; there is no
development one. **Do not validate the patch against the production cluster without an
explicit MTC decision**: that HSM holds the real keys. Options, for the MTC to decide:

1. **A temporary non-production cluster**, created with the `IUGO-MTC/inji-hsm` Terraform or
   restored from a backup of the existing cluster (confirm that AWS CloudHSM allows this in
   your setup), and destroyed afterwards. The HSM is billed by the hour, so the cost is that
   of a few days of testing.
2. **Test in production with safeguards**, only if the MTC approves: a test `applicationId`
   and `referenceId` different from the real ones, an agreed window, and deleting the test key
   afterwards. This carries the most risk and is not recommended as the first choice.

Before choosing, confirm with the infrastructure team which client SDK the deployment uses (the
fork uses the Cavium SDK, `com.cavium.*`, and the patch was written for it).

**Validate the patch in a non-production environment before production.** It uses the JDK's
standard `ECGenParameterSpec` because there is no public source code for a Cavium-specific EC
class. The following must be confirmed, in this order:

1. The real value of `asymmetricKeyAlgorithm` in an `EC_SECP256R1_SIGN` request (the patch
   assumes `"EC"`); log it temporarily.
2. That the key persists: repeating `generate-csr` with the same `referenceId` must return the
   **same** CSR. If it generates a new one, the key was not marked as persistent and a
   Cavium-specific EC parameter class is needed.
3. That the CSR is a genuine EC P-256 (see 1.4).

Detail on what is confirmed and what is not: [hsm-patch/README.md](hsm-patch/README.md).

### 1.3 Activate the key policy

`certify.key_policy_def` must have a row for `CERTIFY_VC_SIGN_EC_R1` before generating the key;
without it, `generate-csr` fails with a policy error (not an HSM error).

```sql
SELECT app_id FROM certify.key_policy_def WHERE app_id = 'CERTIFY_VC_SIGN_EC_R1';
```

If it does not exist (to be expected: the MTC's real SQL only defines the Ed25519 policy), apply
the `CERTIFY_VC_SIGN_EC_R1` block of [`compose/certify/init-mdoc.sql`](compose/certify/init-mdoc.sql)
(validity 1095 days, `PRE_EXPIRE_DAYS = 60`; **review that validity against 2.5**). The mapping
`'ES256': {{'CERTIFY_VC_SIGN_EC_R1', 'EC_SECP256R1_SIGN'}}` already comes in the base
`certify-default.properties`.

### 1.4 Generate the key and obtain the CSR

The `system-info` endpoints wrap their body in `{id, version, requesttime, request}`;
only `request` is mandatory.

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

**The first call generates the private key in the HSM as a side effect.** Subsequent calls with
the same `applicationId`/`referenceId` reuse the key and return the same CSR.

Verify that it is EC P-256:

```bash
openssl req -in mdl-signer.csr.pem -noout -text | grep -A2 "Public Key Algorithm"
```

It must say `id-ecPublicKey` with curve `prime256v1`. If it says `rsaEncryption`, the patch was
not applied or it fell back to the RSA path: do not continue.

---

## Phase 2 — DSC certificate from the MTC CA

**It is an organizational dependency with its own lead time. Start it in parallel with Phase 1.**

### 2.1 Deliver the CSR to the CA

Deliver `mdl-signer.csr.pem` to whoever administers the MTC root CA. The result is a
signed X.509 certificate: the **DSC** (Document Signer Certificate). Save it as
`mdl-signer.cert.pem`.

### 2.2 Upload the certificate to Inji Certify

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

Inji Certify requires the public key of the uploaded certificate to match **byte for byte** the
one generated in the HSM (`KeymanagerServiceImpl.uploadCertificate`). If it does not match, it
responds `KEY_NOT_MATCHING`, typically because the CSR was regenerated in between or the
`applicationId`/`referenceId` is different. Expected response: `{"response": {"status": "success"}}`.

### 2.3 Verify the provisioning

```bash
curl -s "https://<host-inji-certify-mtc>/v1/certify/system-info/certificate?applicationId=CERTIFY_VC_SIGN_EC_R1&referenceId=EC_SECP256R1_SIGN" \
  | jq -r '.response.certificate' | openssl x509 -noout -text
```

Confirm that the certificate matches the one uploaded, that it is `id-ecPublicKey` with curve
`secp256r1`, and that `subject`/`issuer` correspond to the real CA (not to a self-signed test
certificate).

### 2.4 Identify the root IACA

Without a known root IACA, a third-party verifier cannot anchor the chain and the mDL is not
deployable. **Document** which is the MTC's root IACA, who issues it, and through what
distribution mechanism a verifier will obtain it. It feeds Phase 5 (`trustedIacaCerts`) and any
external integration. It is an organizational definition; there is no command.

---

### 2.5 IACA and DSC certificate profile — confirm with the CA before the CSR

ISO/IEC 18013-5 (Annex B) requires a specific profile for the IACA and the DSC. **The text of the
standard is paywalled and could not be consulted for this guide**; what follows comes from
public implementer documentation and **must be confirmed against the standard** before
handing it to the CA. An incorrect profile is discovered at the end of the process, with the DSC already
signed.

**The sources consulted agree** (AWS Private CA, MATTR):

| Element | Requirement |
|---|---|
| DSC — `keyUsage` | `digitalSignature` (in the AWS example, marked critical and sole) |
| DSC — `extendedKeyUsage` | OID `1.0.18013.5.1.2` (reserved for mDL DS) |
| DSC — `authorityKeyIdentifier` | Must match the IACA's `subjectKeyIdentifier` (MATTR) |
| DSC — signed by | The IACA, directly: the mDL chain has a single level between IACA and DSC |
| IACA — `keyUsage` | `keyCertSign` and `cRLSign` |
| IACA — `basicConstraints` | `CA = TRUE` (MATTR) |
| IACA — CRL | `cRLDistributionPoints` extension present (AWS describes it as mandatory in the IACA profile) |
| IACA — `issuerAlternativeName` | Present (MATTR; AWS also includes it in the example DSC) |
| Subject | Country as ISO 3166-1 alpha-2 code (`PE`); Inji compares it with `issuing_country` (Annex A.3) |
| Algorithm | ECDSA with SHA-256 over P-256 in the AWS and MATTR examples |

**The sources disagree or do not say — confirm against ISO/IEC 18013-5:2021:**

| Element | What the sources say |
|---|---|
| Maximum IACA validity | 9 years (AWS and the UK government guidance, citing Table B.1) versus 20 years (MATTR, walt.id) |
| Maximum DSC validity | **457 days** (UK government guidance, attributed to ISO; MATTR for managed mDLs) versus 1825 days in an AWS example, without citing the standard |
| DSC longer than the credential | The UK guidance requires the DSC to outlast the mdoc it signs |
| DSC CRL and `issuerAlternativeName` content | Not clear in the sources |

**Why it matters here.** If the DSC maximum were 457 days:

- The current `CERTIFY_VC_SIGN_EC_R1` policy (1095 days, `init-mdoc.sql`) and the default
  credential validity (`P730D`) would be incompatible with the standard, and both would need
  adjusting.
- DSC rotation would stop being occasional: it would happen at least once a year, which
  aggravates critical finding #1 (8.2) and makes the P16 process indispensable.

**Open questions for the CA and the Certify team** (none is resolved in this
repository):

1. What is the exact IACA and DSC profile that the MTC CA can issue, and which one does
   the standard require?
2. The CSR generated by Inji Certify carries no extensions such as `extendedKeyUsage`: does the
   CA add them when signing? Confirm this before accepting the DSC.
3. Who publishes and maintains the CRL, and at what URL?

Sources consulted:
[AWS Private CA — DSC](https://docs.aws.amazon.com/privateca/latest/userguide/JavaApiMDL-IssueDS.md),
[AWS Security Blog](https://aws.amazon.com/blogs/security/build-a-mobile-drivers-license-solution-based-on-iso-iec-18013-5-using-aws-private-ca-and-aws-kms),
[GOV.UK Wallet — signing mdoc](https://docs.wallet.service.gov.uk/issue-credentials/sign-mdoc-credentials),
[MATTR — certificates](https://learn.mattr.global/docs/issuance/certificates/overview),
[walt.id — VICAL and IACA](https://docs.walt.id/concepts/trust-systems/iso-trust-vicals).

---

## Phase 3 — `credential_config` in Inji Certify

### 3.1 Confirm the version

```bash
docker image inspect <imagen-ecr-inji-certify> | grep -i version
```

This guide assumes v0.14.0 (branch `main` of `IUGO-MTC/inji-certify`, the production one). If it
differs, re-validate the findings before continuing. (The fork's `master` branch is at
v0.12.2 and is not the production one.)

### 3.2 Apply the `credential_config`

Adapt and apply the INSERT from [`compose/certify/init-mdoc.sql`](compose/certify/init-mdoc.sql):

- `credential_config_key_id = 'MTCDrivingLicenseMDL'`
- `credential_format = 'mso_mdoc'`, `doctype = 'org.iso.18013.5.1.mDL'`
- `key_manager_app_id = 'CERTIFY_VC_SIGN_EC_R1'`, `key_manager_ref_id = 'EC_SECP256R1_SIGN'`
- `signature_algo = 'ES256'`, `signature_crypto_suite = 'EcdsaSecp256r1Signature2019'`

If decision 0.1 was "one per class", use 3 rows.

### 3.3 Velocity template

The `vc_template` embedded in `init-mdoc.sql` must meet three conditions, verified against the
real behavior of Inji Certify:

1. Each field in bracket notation: `${rootContext['org.iso.18013.5.1'].<campo>}`, never
   `${campo}`.
2. The `driving_privileges` placeholder **without quotes**, so that Velocity substitutes it as
   a raw JSON fragment (scalar fields do carry quotes).
3. The data plugin (Phase 4) must deliver `driving_privileges` as an **already-serialized JSON
   string**, not as an array.

Regenerate with [`render-mdoc-template.mjs`](compose/certify/render-mdoc-template.mjs) if more
fields are needed. The raw template is not valid JSON until Certify substitutes
`driving_privileges`; this is the expected behavior.

### 3.4 Verification

```bash
curl -s "https://<host>/v1/certify/.well-known/openid-credential-issuer" \
  | jq '.credential_configurations_supported.MTCDrivingLicenseMDL'
```

It must return the complete configuration, including `driving_privileges` in the claims schema.

---

## Phase 4 — Real FEE data plugin

### 4.1 Contract to replicate

[`compose/certify/mock-fee-plugin/`](compose/certify/mock-fee-plugin/) is the **reference
contract**: it implements `io.mosip.certify.api.spi.DataProviderPlugin`
(`fetchData(Map<String,Object>): JSONObject`). The real plugin lives in
`IUGO-MTC/inji-dataprovider` (`MtcFeeDataProviderPlugin`) and must be extended for
`MTCDrivingLicenseMDL`, replicating:

- **Claims nested under the ISO namespace:** `{"claims": {"org.iso.18013.5.1": {...}}}`.
- **`driving_privileges` as a serialized JSON string**, not a `JSONArray`; the opposite
  produces `JSONException: Expected a ',' or '}'` in Velocity.
- **Holder identifier from `identityDetails.sub`**, with fallback to
  `individualId`/`individual_id` in case another authentication flow populates it differently.
- **`portrait` as the base64 of a JPEG.** It requires fix A.2 in the issuer so that it ends up
  encoded as `bstr`.

Do not use `certify-mtc-mock-fee.properties` in the real environment.

### 4.2 Confirm the real shape of the FEE response

**This is a data risk that has not been verified.** All the work assumes that the FEE can
deliver (or the plugin can transform its response into) an array of objects with
`vehicle_category_code`, `issue_date` and `expiry_date` per category, the shape that ISO/IEC
18013-5 Table 3 requires. The SD-JWT `credentialSubject` does not impose that structure (it
could be a string such as `"A-IIb"` without dates). **Action:** obtain a real response from the
FEE service and confirm or map against that shape before considering the phase complete.

### 4.3 Verification

Replicate the 7 tests of
[`MockFeeDataProviderPluginTest.java`](compose/certify/mock-fee-plugin/src/test/java/pe/gob/mtc/mock/MockFeeDataProviderPluginTest.java)
against the real implementation, and issue an mDL with a real test `document_number`. Pass the
CBOR through `verify/verify-mdoc.mjs` to confirm that `driving_privileges` arrives complete.

---

## Phase 5 — Wallet

MTC fork: `inji-wallet`.
It consumes `vc-verifier` as a published dependency (`io.mosip:vcverifier-aar:1.5.0`) with a
native module with no logic of its own (`RNVCVerifierModule.java` →
`CredentialsVerifier().verify(vc, format)`).

**The `{docType, issuerSigned}` wrapper requires no patch.** `MsoMdocVerifiableCredential`
reads `issuerSigned` from both the flat format and the one nested in `documents[0]`; Certify's
wrapper falls into the branch that finds it. Confirmed by running `parse()` and `verify()` of
the real library (1.5.0 and 1.6.0) against CBOR issued by the test environment.

### 5.0 CRITICAL BLOCKER — iOS does not verify mdoc

`shared/vcjs/verifyCredential.ts`, `verifyCredentialForIos()`:

```typescript
if (credentialFormat === VCFormat.mso_mdoc || credentialFormat === VCFormat.vc_sd_jwt || credentialFormat === VCFormat.dc_sd_jwt) {
  return createSuccessfulVerificationResult();
}
```

For `mso_mdoc`, it returns success without invoking any verification. An arbitrary CBOR, not
even signed, is reported as valid. The code itself marks it as provisional ("until
VcVerifier is implemented for iOS"). It is present identically in `mosip/inji-wallet` (`main`,
commit `2b37c05`, 2026-05-07).

The Swift port already exists, compiled and tested:
[`yalvarez/inji-wallet-verification` → `vc-verifier-patch/ios/`](https://github.com/yalvarez/inji-wallet-verification/tree/main/vc-verifier-patch/ios).
It invokes the same sequence as Kotlin (trust chain → country → COSE signature → digests →
docType) with `CryptoKit` and `Security`. Its README documents 3 real defects fixed during
validation: an incomplete enum case, the ISO 18013-5 CBOR tags 18/24, and a custom DER parser
for the Subject DN.

**To integrate it:**

1. Follow the validation plan in the port's README in a real Xcode environment.
2. Complete the React Native bridging (`MsoMdocVerifierReactNative/`) inside the Xcode project
   of the MTC's `inji-wallet`; it depends on the `React` framework, which Swift Package
   Manager does not resolve.
3. Replace the hardcode in `verifyCredentialForIos()` with a call to the native module.
4. Test on simulator and real device before enabling mdoc on iOS.

**Contingency (not the default plan):** if this stretch does not close in time, change the
condition so that `mso_mdoc` fails explicitly (fail-closed) and do not offer the format on iOS.

### 5.1 Patch for the trust gap (Android)

`MsoMdocVerifier.verifyCertificateChain()` returns `true` unconditionally (`iconst_1,
ireturn` in the 1.5.0 bytecode, confirmed): there is only signature integrity, not trust. A
self-signed mdoc passes `verify()`.

```bash
cd /path/to/inji/vc-verifier          # upstream project checkout
git apply /path/to/inji-wallet-verification/vc-verifier-patch/MsoMdocVerifier.kt.patch
```

The patch adds an **optional** parameter `trustedIacaCerts: List<X509Certificate>` to
`verify()`; it is compatible with current callers (if omitted, the gap stays open but is logged
as a warning). It was validated with `kotlinc` against real certificates (4 cases) and with
`git apply --check`.

**Packaging.** The fork consumes the published AAR, not the source code. It is necessary to (a)
build a custom AAR from a fork of `inji/vc-verifier` with the patch, publish it to a Maven
repository that the wallet build resolves, and (b) point `android/app/build.gradle` to that
coordinate. **Before production**, build against the complete Android module
(`./gradlew :vc-verifier:assembleRelease`): the patch has not been tested against that build.

### 5.2 Trust store in the app

The patch solves the library; where the `trustedIacaCerts` come from at runtime is the app's
responsibility. Implement in the MTC's `inji-wallet`:

1. A cached local trust store, to verify without depending on the network.
2. A periodic background refresh against a trust distribution endpoint, using the IACA from
   Phase 2.4.
3. Pass the resolved certificates to `verify(mdoc, trustedIacaCerts)` from
   `RNVCVerifierModule.java`, which currently passes none.

This piece is not included in any patch of this project.

---

## Phase 6 — Third-party verification

There are two use cases with different solutions: **online** verification (QR + backend, like
InjiVerify) and **offline in the field** (police checkpoint, BLE/NFC).

### 6.1 InjiVerify (online) — gap confirmed and bounded

In the MTC's `inji-verify`, `VCVerificationServiceImpl.java` decides the format with a binary
`if/else` on `Content-Type`:

```java
if ("application/vc+sd-jwt".equalsIgnoreCase(contentType) || "application/dc+sd-jwt".equalsIgnoreCase(contentType)) {
    format = CredentialFormat.VC_SD_JWT;
} else {
    format = CredentialFormat.LDP_VC;  // cualquier otro, incluido mdoc
}
```

A real CBOR falls into `LDP_VC` and fails when parsed as JSON-LD. `FormatDto` does not declare
`mso_mdoc` either (only `jwt`, `jwt_vc`, `ldp_vc`).

**The gap is in application code, not in the library.** The service already depends on
`vcverifier-jar:1.5.0`, which does implement `MsoMdocVerifier`/`CredentialFormat.MSO_MDOC`. Two
changes in `verify-service` close it:

1. Add the `Content-Type` → `CredentialFormat.MSO_MDOC` branch in `verify()`.
2. Declare `mso_mdoc` in `FormatDto` and in the Presentation Definition with the ISO
   18013-5 path (`$['org.iso.18013.5.1']['<campo>']`, different from SD-JWT's `$.vct`).

The UI (`verify-ui`) was not reviewed in the same detail; it probably requires a rendering
adjustment for claims from an mdoc namespace.

### 6.2 Own service on `@owf/mdoc` (online)

[`verify/verify-mdoc.mjs`](verify/verify-mdoc.mjs) is already a functional verifier (13
checks) on `@owf/mdoc`/`@owf/cose`, from the OpenWallet Foundation. Wrapping it in an HTTP
endpoint and a minimal UI avoids maintaining an InjiVerify fork; the remaining work is only the
service layer, at the cost of a new service to operate.

### 6.3 Multipaz SDK (online and offline)

[`openwallet-foundation/multipaz`](https://github.com/openwallet-foundation/multipaz) is a
Kotlin Multiplatform SDK (Android, iOS and server). Verified against its code:

- `org.multipaz.verification` (`VerificationSession`, `MdocVerifiedPresentation`) is reusable
  public API.
- It implements **both presentation protocols**: proximity (BLE/NFC, offline) and
  OpenID4VP / W3C Digital Credentials API (online).
- `org.multipaz.trustmanagement` provides a local `TrustManager`, `VicalTrustManager` (consumes
  a VICAL, the standard list of IACAs from ISO 18013-5) and `CompositeTrustManager`; it covers
  the trust store of Phase 5.2 on both platforms.
- The `multipaz-verifier` module is JVM/server, another alternative to the InjiVerify gap.
- `multipaz-identity-reader` was installed on Android without forking and pointed at custom
  trust anchors, validated against interoperability vectors from `@owf/mdoc` (Germany, France,
  Google, Ubique).

Incorporating `multipaz` into an MTC or police app gives real proximity verification without
rewriting COSE/CBOR or the trust chain. **It is the only mature option that covers the offline
case.**

### 6.4 Decision

| Priority use case | Path |
|---|---|
| Online, within the Inji ecosystem | 6.1 |
| Online, lowest total effort | 6.2 |
| Offline field checks | 6.3 (only mature option) |
| Both | 6.3 plus 6.1 or 6.2; they are not mutually exclusive |

It is a product and execution decision; it is no longer a technical unknown.

---

## Phase 7 — Conformance and pre-production checklist

### 7.1 Conformance and interoperability plan

So far the mDL has been validated with `verify/verify-mdoc.mjs` (`@owf/mdoc`), with the wallet's
`vcverifier` library, and with the real wallet. That shows the mDL is consistent with
**those implementations**, not that it conforms to ISO/IEC 18013-5 against third parties. Before
declaring it conformant:

1. **Verify with a second, independent implementation**, in addition to `@owf/mdoc`; for
   example the `multipaz-verifier` module or the `multipaz` libraries (Phase 6.3) over the
   same CBOR. (P21)
2. **Test against a third-party reader** once the corresponding presentation channel exists.
   With the current stack this is not possible by proximity: `inji-wallet` does not generate
   the ISO 18013-5 device engagement QR (Annex A, result), so a reader such as
   `multipaz-identity-reader` cannot start the session with it.
3. **Confirm with the MTC** whether a conformance certification scheme or a mandatory legal
   assessment exists for operating the digital licence. **It was not investigated.** (P22)

Until these points are closed, the correct wording toward the MTC and third parties is "mDL that
passes the checks of the listed implementations", not "ISO-conformant certified".

### 7.2 Checklist

- [ ] **Credential model decided** (0.1).
- [ ] **HSM patch validated on a non-production CloudHSM** (1.2): generates a real EC P-256 and the
      key persists across restarts.
- [ ] **Real DSC from the MTC CA uploaded** (Phase 2), not a test certificate.
- [ ] **Root IACA documented**, with its trust distribution mechanism (2.4).
- [ ] **IACA and DSC profile confirmed against ISO/IEC 18013-5** and accepted by the CA, including maximum validities (2.5).
- [ ] **`credential_config` applied and visible** in `.well-known/openid-credential-issuer` (3.4).
- [ ] **Issuer fixes applied to the production Certify** (A.1 `kid` with `#0`; A.2
      `portrait` as `bstr`) and correct DSC certificate country (A.3).
- [ ] **Real shape of the FEE response confirmed** (4.2).
- [ ] **Real FEE plugin deployed and tested end to end** (4.3), not the mock.
- [ ] **BLOCKER — iOS verification integrated before launch** (5.0): React Native
      bridging, replacement of the hardcode, and device testing. `mso_mdoc` cannot remain at
      "success without verification" in production. Contingency: fail-closed.
- [ ] **Android trust patch built against the full module** and the AAR integrated
      into the wallet (5.1).
- [ ] **Wallet trust store implemented**, with anchor refresh (5.2).
- [ ] **Third-party verification path decided and executed** (Phase 6). At least one online
      before production; the field one (6.3) if in-person checks apply.
- [ ] **Mimoto deployed and available**: without it there is no token path for a wallet
      to obtain the mDL.
- [ ] **Critical findings of Phase 8 resolved or formally accepted.**
- [ ] **Second independent implementation verified** on the same mDL (7.1).
- [ ] **Final end-to-end verification** with `verify/verify-mdoc.mjs` on an mDL issued
      by the complete pipeline, signed with the real DSC and opened in the fixed wallet.

---

## Phase 8 — Production maturity audit

Phases 1–7 cover the happy path (issuance → wallet → verification). This phase answers what the
system lacks to be a **mature** implementation, not just a functional one. 6 domains were
reviewed with real code from the fork's `inji-certify`, `inji-wallet` and `inji-verify`, the
Multipaz SDK and primary normative sources. No finding blocks Phases 1–7.

### Summary — 5 critical findings

| # | Finding | Domain | Severity |
|---|---|---|---|
| 1 | If the DSC expires without manual rotation, Inji Certify **silently falls back to a self-signed certificate** and breaks the trust chain without warning | PKI | High |
| 2 | **Selective disclosure does not work for mdoc:** the wallet always sends the complete credential, validated with a real `VPToken` (A.5) | Privacy | High |
| 3 | **Revocation excludes mdoc**; there is no version/nonce to invalidate after a data change, and the device key is a single one for all credentials | Lifecycle | High |
| 4 | The **offline channel** (BLE/NFC from ISO 18013-5) does not exist in the stack; the BLE present is a proprietary protocol | Channels | Medium-High |
| 5 | Actuator endpoints **overexposed** in Inji Certify's development `docker-compose`; they do not appear in the Helm chart. **Confirm against the MTC's real configuration** | Operations | Medium (to be confirmed) |

### 8.1 Credential lifecycle

| Question | Verdict |
|---|---|
| Expiration | Partial |
| Renewal | Unresolved |
| Re-issuance after data change | Unresolved |
| Device loss | Unresolved |

- **Expiration.** The MSO carries real `validityInfo` (`MDocProcessor.java:389-397`), with
  `validUntil` derived from `mosip.certify.data-provider-plugin.vc-expiry-duration` (default
  `P730D`, ~2 years). On iOS verification is skipped (5.0), so an expired mdoc is reported
  as valid. On Android it could not be confirmed whether `vc-verifier` validates `validUntil`.
- **Renewal.** `IarServiceImpl.java:196`: *"refresh_token and authorization_details are
  optional and not implemented yet"*. There is no proactive re-issuance or advance notice before
  expiration. Multipaz has a generic renewal mechanism; `inji-wallet` does not use
  Multipaz.
- **Re-issuance.** The MSO carries no version or nonce. If the holder changes address or
  category, the previous credential remains valid until its `validUntil`, because
  revocation is not connected to `mso_mdoc` (8.3).
- **Device loss.** The `deviceKeyInfo` binding is correct (it derives from the wallet's
  proof-of-possession key), but `inji-wallet` generates **a single key pair per
  algorithm and per installation**, shared by all credentials
  (`cryptoUtil.ts:133-159`), and `inji-certify` has no per-device revocation. Whoever
  unlocks a lost phone can present the mdoc until `validUntil`.
- **Contrast:** Multipaz's reference MSO uses **30-day** validity with frequent renewal; Inji
  Certify uses ~2 years with no renewal.

### 8.2 Trust and PKI

| Question | Verdict |
|---|---|
| Hierarchy with depth limit | Partial |
| DSC rotation without regenerating the IACA | **Unresolved (critical)** |
| VICAL — format and distribution | Resolved (in Multipaz) |
| Mass revocation upon IACA compromise | Partial |

- **Hierarchy.** Inji Certify only attaches the active DSC to the COSE header; building and
  validating the chain is the verifier's responsibility. Multipaz supports N-level chains
  (`maxPathDepth = 32`) with `basicConstraints`/`pathLen` validation; the standard design of
  ISO 18013-5 is two levels (IACA → DSC).
- **DSC rotation (critical #1).** There is no job or automatic mechanism. The repo's own
  documentation (`docs/PKI-Support-and-Integration-with-SD-JWT-VC.md:121-126`) states:
  > *"Inji Certify does not automatically manage or renew externally signed certificates. If
  > the uploaded certificate expires, the Key Manager will fallback to using a self-signed
  > certificate and regenerate the keys accordingly."*

  If the MTC does not rotate the DSC before it expires, Certify **signs with a self-signed
  certificate without blocking the service or alerting**, and breaks trust for every
  third-party verifier. The `CERTIFY_VC_SIGN_EC_R1` policy defines 1095 days of validity and 60
  of advance notice, with no process acting on them.
- **VICAL.** A signed CBOR document (COSE_Sign1, ISO 18013-5 Annex C) distributed over HTTPS and
  consumable offline (`VicalTrustManager`). The parser was tested against real VICALs from
  AAMVA (USA) and Austroads (Australia). The MTC has no VICAL of its own (consistent with
  the IACA not yet being identified, 2.4).
- **IACA compromise.** It is resolved by removing the entry from the `TrustManager` or
  republishing the VICAL, but it is manual and depends on verifiers refreshing. Multipaz does
  not query CRL/OCSP during chain validation.

### 8.3 Presentation channels

| Question | Verdict |
|---|---|
| ISO 18013-5 BLE/NFC (offline) in the wallet | **Does not exist** |
| Online OpenID4VP for mdoc in the wallet | Exists and is robust |
| InjiVerify receives an offline presentation | No |
| Multipaz: proximity extractable without the whole SDK? | Partial |

- **Offline (critical #4).** `inji-wallet` has BLE state machines
  (`machines/bleShare/`, `io.mosip:tuvali:0.5.2`), but they implement a **proprietary MOSIP
  protocol** (BLE service `'OVPMOSIP'`), not that of ISO 18013-5 (`DeviceEngagement`, GATT
  services, HKDF). `docs/mdoc-support.md:78` admits that the mdoc *"is not stored in persistent
  storage or shared via Bluetooth"*. There is no NFC. In `inji-verify` the "BLE" tab is
  disabled and the backend only understands QR → HTTP POST.
- **Online.** Presentation via OpenID4VP is complete on Android
  (`InjiOpenID4VPModule.java`) and iOS (`RNOpenID4VPModule.swift`). Limitation: device
  authentication is limited to **ES256** (`openID4VPServices.ts:162-165`).
- **Multipaz offline.** The proximity code is decoupled from OpenID4VP, but there is no
  separate artifact (`multipaz-proximity`); extracting it requires a fork with selective
  package extraction. Multipaz also includes support for external USB NFC readers, intended for
  counters or border control.

### 8.4 Privacy and minimization

| Question | Verdict |
|---|---|
| Real selective disclosure for mdoc | **Unresolved (critical)** |
| Unlinkability between presentations | Partial |
| Over-disclosure in the verifier's request | Unresolved |
| Photograph/biometric minimization | Unresolved |

- **Selective disclosure (critical #2).** `OpenID4VP.ts:112-129` (`extractCredential`):

  ```ts
  if (credentialFormat === VCFormat.mso_mdoc || credentialFormat === VCFormat.ldp_vc) {
    return vcData.verifiableCredential.credential;   // credencial COMPLETA, sin filtrar
  }
  if (credentialFormat === VCFormat.vc_sd_jwt || credentialFormat === VCFormat.dc_sd_jwt) {
    return this.processSdJwtVcForSharing(vcData, selectedDisclosures);  // sí filtra
  }
  ```

  `selectedDisclosures` is ignored for mdoc. The consent UI exists but has no effect: a
  verifier that only needs `over_18` receives the entire namespace.
- **Cascading effect.** This nullifies the unlinkability that the issuer does implement
  (`addRandomSalts()` generates 24 random bytes per element): since the full set of
  digests and `issuerAuth` travels identically to every verifier, it works as a stable
  identifier of the holder, and two verifiers can correlate that they served the same
  person.
- **Verifier side.** `inji-verify` does not support mdoc. The 5 configured Presentation
  Definitions request only `$.type`, never an individual attribute; the data model would
  support granular requests.
- **Photograph.** There is no minimization; worse, if the credential contains an image, the
  wallet requires "Share with Selfie" (`SendVPScreen.tsx:385-399`), treating the biometric as
  an authentication requirement rather than as sensitive data.
- **Positive.** The wallet's telemetry is disabled (`TelemetryUtils.js:18-44`), the local
  activity log does not persist personal data, and no content leak was found in logs.

### 8.5 International interoperability — eIDAS / European Union

**Today there is no legal or technical path by which an MTC mDL is automatically recognized in
an EU country** under eIDAS 2.0 / EUDI Wallet. Sources: Regulation (EU) 2024/1183,
Directive (EU) 2025/2205, the EUDI Wallet ARF, Commission implementing decisions.

- **The EU does not use VICAL.** Its trust model for mdoc is eIDAS Trusted Lists (ETSI TS
  119 612, XML) with a List of Trusted Lists maintained by the Commission. Publishing an MTC
  VICAL does not help with the EU, although it does help with the AAMVA / North America
  ecosystem.
- **The relevant rule is Directive (EU) 2025/2205** (driving licences, in force since
  26.11.2025). Its issuer notification mechanism (Art. 5(5)) is restricted to Member
  States. For Peru there are two medium-term hooks: Art. 13 (recognition of
  third countries with comparable road safety) and the Art. 5(7) mandate to consider
  recognition of EU licences by third-country authorities, with an implementing act
  expected for **26.11.2026**.

| | Technical interoperability | Legal recognition |
|---|---|---|
| Requires | Conformant mdoc + IACA distributed out of band | Registration in a trusted list enabled by an EU legal act |
| Decided by | The verifier operator | European Commission / Council (Art. 218 TFEU) |
| Timeline | Immediate, once the MTC's IACA exists | No open path; not plannable |

**Recommended framing:** ISO 18013-5 conformance (achievable, within the MTC's control) and
recognition in the EU (depends on treaties and Commission acts) are two separate layers;
promising the second as an automatic consequence of the first would be incorrect. Moreover, the
real order is the reverse of the digital one: the Peruvian physical licence must first be
recognized in Spain (UNECE or bilateral agreements) before it makes sense to recognize its
digital version.

### 8.6 Operations and monitoring

| Question | Verdict |
|---|---|
| Logging without personal data leakage | Partial |
| Metrics and health checks | Partial (critical finding) |
| Ledger as audit | Yes |
| Incident response — selective key shutdown | Partial |
| Availability on HSM failure | Partial (no circuit breaker) |

- **Logging.** Consistent use of `VCIssuanceUtil.abbreviateForLog()`; personal data is not
  logged. Minor gap: `clientId` is logged unabbreviated in 3 places.
- **Actuator (critical #5, to be confirmed).** In
  `docker-compose/docker-compose-injistack/config/certify-default.properties:72-73`:

  ```properties
  management.endpoint.env.show-values=ALWAYS
  management.endpoints.web.exposure.include=*
  ```

  **Real scope:** it lives only in the development `docker-compose`. It **does not appear** in
  the Helm chart (`helm/inji-certify/values.yaml` only references `/actuator/health` and
  `/actuator/prometheus`). There is no evidence that it reaches the MTC's deployment: it may be
  overridden, or live in a ConfigMap/Secret not visible from the repo. If the MTC were to deploy
  that file unchanged, `/actuator/env` would expose DB and HSM credentials. **Action:**
  confirm in the real configuration that `management.endpoints.web.exposure.include` is
  restricted to `health,info`, and `show-values` is `NEVER` or `WHEN_AUTHORIZED`.
- **Metrics.** Only generic JVM/HTTP scraping, with no business metrics (issuance rate or
  failure rate, signing latency), and `prometheusRule.enabled=false`: no alerts by default.
- **Ledger.** It records every issuance, mdoc included, although without status detail.
- **Incident response.** The schema has the fields (`key_alias.status_code`,
  `key_policy_def.is_active`), but there is no evidence that signing consults them; the
  procedure suggested in the code is manual (`DELETE FROM key_alias WHERE alias=...`).
- **HSM.** There are retries with backoff (`AWSCloudHSMKeyStoreImpl.java:73-74`, 5 × 10 s) and
  handling of the CloudHSM v5 key replication case, but no circuit breaker: each request
  pays the full retry (up to 50 s) before failing.
- **Rate limiting.** There is none in issuance or verification, beyond OID4VCI's
  proof-of-possession.

### 8.7 Prioritization before production

1. **Close the silent fallback to self-signed** (8.2): DSC rotation process with an alert
   before expiration and an alarm if Certify falls to the self-signed path.
2. **Implement real selective disclosure for mdoc** (8.4): filter `IssuerSignedItem` by
   `elementIdentifier` when building the `DeviceResponse` and wire `disclosedKeys` for mdoc in
   `VCProcessor`. It is bounded work.
3. **Confirm Actuator exposure in production** (8.6) before "fixing" it.
4. **Connect revocation to mdoc** (8.1/8.3): extend the `case "mso_mdoc"` of
   `CertifyIssuanceServiceImpl` to use the status list mechanism already built.
5. **Decide the offline scope:** if field checks are a priority, integrate
   Multipaz (Phase 6) instead of assuming that the existing BLE covers ISO 18013-5.
6. **Frame expectations about the EU** (8.5) when communicating this work.

---

## Annex A — Defects found in the real-device test

First test of the complete chain: a real `inji-wallet` on a physical Android (Galaxy S9+)
scanning a real OID4VCI offer QR, against a local Mimoto and Inji Certify
([`compose/docker-compose.yml`](compose/docker-compose.yml)). The goal was to get the
mDL issued, downloaded, verified and displayed completely, including the photograph.

**8 defects** were fixed: 3 in the issuer (Inji Certify 0.14.0) and 5 in the wallet. Each
one was diagnosed with direct evidence (bytecode with `javap`, `logcat`, CBOR decoding
with `cbor2`, replication of the OID4VCI flow with curl/Node) before spending a real scan.

| # | System | Defect | Severity |
|---|---|---|---|
| A.1 | Certify | `#0` fragment of the `kid` breaks the proof JWT | Blocker |
| A.2 | Certify | `portrait` is encoded as `tstr` instead of `bstr` | High |
| A.3 | Certify (config) | DSC certificate with country `IN` breaks `verifyCountryName` | Blocker |
| A.4 | Wallet | `portrait` without `data:` prefix | Medium |
| A.5 | Wallet | `issuerLogo` without null-guard | Low |
| A.6 | Wallet | well-known `order` without namespace: blank detail | High |
| A.7 | Wallet | `driving_privileges` (array of objects) crashes the render | High |
| A.8 | Wallet | `portrait` listed as text in the detail | Medium |

The issuer fixes (A.1, A.2) are in
[`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md); the wallet ones
(A.4–A.8) live in a local fork of `inji-wallet` and must be carried over to the MTC fork.

### A.1 `#0` fragment of the `kid` breaks the proof JWT — Certify

`MDocProcessor.createDeviceKeyInfo` trims the `did:jwk:` prefix from the `kid` but not the
`#0` fragment required by the [did:jwk spec](https://github.com/quartzjer/did-jwk/blob/main/spec.md#to-create-the-did-url),
and `#` is not valid base64url:

```
java.lang.IllegalArgumentException: Illegal base64 character 23
	at io.mosip.certify.utils.MDocProcessor.createDeviceKeyInfo(MDocProcessor.java:418)
```

Confirmed with a real proof JWT from `io.mosip.vciclient` 0.6.0 (`kid` =
`did:jwk:eyJrdHkiOiJFQyIs...#0`). **It blocks all `mso_mdoc` issuance with that wallet.**

**Fix:** replicate the `split("#")[0]` that `DIDjwkProofManager.getKeyFromHeader` already uses
correctly elsewhere in the code. In the test environment it was applied with Javassist
on `MDocProcessor.class`; **in production it must be applied in the source code of the MTC's
Inji Certify fork.**

### A.2 `portrait` as `tstr` instead of `bstr` — Certify

`MDocProcessor.preprocessForCBOR` has four branches (`byte[]`, `String`, `Map`, `List`) and
none decodes base64; every `String` ends up as a `UnicodeString` (CBOR `tstr`), while
ISO 18013-5 requires a byte string for `portrait`. It is a conclusion closed by reading
bytecode: no change of template, field name or plugin can fix it, because the
decision is made in Java, upstream of the template.

If in addition the plugin omits the field, the Velocity placeholder is left unsubstituted and is
written **literally** inside the mDL; the wallet shows it as a broken image.

**Fix (two parts):**

1. In the `Map` branch of `preprocessForCBOR`, if the parent `Map` (the complete
   `IssuerSignedItem`) has `elementIdentifier == "portrait"` and the current entry is
   `elementValue` with a non-empty `String`, decode it as base64 (standard and then urlsafe) to
   `byte[]`.
2. The data plugin must deliver the field with a real JPEG.

> **Lesson:** a first version of the patch compared `entry.getKey()` with `"portrait"`.
> That condition can never be true, because in an `IssuerSignedItem` that string appears
> as the *value* of `elementIdentifier`, not as a key. The patch had no effect, and went
> unnoticed because `verifyValueDigests` gives `match=True` whether it is `tstr` or `bstr`; only
> the wallet's Face Verification step failed, which needs real JPEG bytes. Always verify
> that `portrait` arrives as `bytes` in the decoded CBOR.

### A.3 DSC certificate with wrong country breaks `verifyCountryName` — Certify

The mDL was issued and downloaded, but the wallet always rejected it
(`verifyingCredential → handleVCVerificationFailure`). `vcverifier-aar:1.5.0` runs five
checks in order: `verifyCertificateChain` (stub), `verifyCountryName`,
`verificationOfCoseSignature`, `verifyValueDigests`, `verifyDocType`. Replicating them in Python
(`cbor2` + `cryptography`) against a real mDL, `verifyValueDigests` passed on all 11 fields and
`verifyCountryName` failed.

This check extracts the `C=` from the DSC's Subject DN (regex `C=([^,]+)`) and compares it with
the mDL's `issuing_country`. The auto-generated keystore carried `C=IN` (India), from MOSIP's
demo certificate; with `issuing_country: "PE"` it never matched.

**Cause:** `mosip.kernel.keymanager.certificate.default.country=IN` and
`mosip.kernel.keymanager.softhsm.certificate.country=IN` in
[`certify-default.properties`](compose/certify/certify-default.properties).

**Fix:** `country=PE` (and organization, unit, locality and state of MTC/Peru) in both
blocks. The change is not enough by itself: the `local.p12` must be deleted and `DELETE FROM
key_alias;` run to force regeneration. This applies to the test environment; **in production
the equivalent is for the DSC from the MTC CA (Phase 2) to have `C=PE`.**

### A.4 `portrait` without `data:` prefix — wallet

With A.1–A.3 resolved the credential was saved, but the detail failed with
`ReactImageView: Image source "/9j/4AAQSkZJRgAB..." doesn't exist`. `getFaceAttribute`
(`components/VC/common/VCUtils.tsx`) passes the raw `elementValue`. In `ldp_vc`/SD-JWT the
issuer delivers `face` as a complete data URI, but ISO 18013-5 defines `portrait` as raw
JPEG bytes; React Native's `<Image>` only interprets URIs.

**Fix:** prepend `data:image/jpeg;base64,` only in the `mso_mdoc` branch, with guard
`!faceField.startsWith('data:')`.

### A.5 `issuerLogo` without null-guard — wallet

`ReactImageView: Image source "null" doesn't exist`. `VCCardViewContent.tsx` renders
`<Image src={issuerLogo?.url}>` even when there is no URL. **Fix:** make the render conditional
on `issuerLogo?.url`.

### A.6 well-known `order` without namespace prefix — wallet

The detail opened blank: none of the 11 fields. `getFieldValue`/`getFieldName` expect
`"namespace~elementIdentifier"` entries for `mso_mdoc`, but Certify's well-known `order`
delivers flat names (`"family_name"`). Without the `~`, `field.split('~')` does not produce 2
parts and `fieldItemIterator` discards every field.

**Fix:** in `shared/openId4VCI/Utils.ts`
(`getCredentialIssuersWellKnownConfig`), normalize each `order` entry to
`namespace~field`, resolving the namespace against `claims`. In addition: a latent defect in
the fallback was fixed (`fields.concat(...)` without assignment does not mutate the array; it is
now `fields.push(...)`) and `iterateMsoMdocFor` was hardened with a shape fallback
(`issuerSigned.nameSpaces` or `nameSpaces`).

### A.7 `driving_privileges` crashes the render — wallet

```
Objects are not valid as a React child (found: object with keys
{issue_date, expiry_date, vehicle_category_code})
```

It is an array of objects per ISO 18013-5, and the `mso_mdoc` branch of `getFieldValue` passed
it raw. **Fix:** if the value is an array of objects, format it as a comma-separated list of
`vehicle_category_code`. It is the only field in the template with this shape.

### A.8 `portrait` listed as text in the detail — wallet

The "Photograph" row showed the raw base64. `IMAGE_KEYS` already excluded these fields from the
main listing, but not from the `mso_mdoc` detail. **Fix:** export `IMAGE_KEYS` and
filter in both branches that build `fields` (with `order` and fallback over `claims`).

### Result

With A.1–A.8: issuance → download (real proof JWT) → local verification (`vcverifier-aar`:
COSE_Sign1, digests, country and docType, no bypass) → persistence → complete detail, with
photograph, without errors. First complete mdoc chain on a real wallet, fixing
defects without modifying its business logic.

**Field verifier.** `org.multipaz.identityreader` turned out to be **unusable** with this
wallet: its only presentation mode is proximity via `mdoc:` QR (ISO
18013-5 device engagement), and `inji-wallet` does not generate that QR; its own is a
proprietary format ("PixelPass"). It empirically confirms critical finding #4.

### A.9 Selective disclosure: empirical validation of critical finding #2

A minimal OpenID4VP verifier was written (Node, a test tool not included in this
repository) that requests **a single field** (`family_name`) with `limit_disclosure: "preferred"`.
(`"required"`, the value that in DIF Presentation Exchange forces filtering, was rejected by the
wallet's library `inji-openid4vp-aar:0.5.0` with `invalid_request`: not even the strict value of
the spec is supported.) It used `client_id_scheme=redirect_uri` and `response_mode=direct_post.jwt`
(the only one accepted when `mso_mdoc` is present), with an X25519 / `ECDH-ES` +
`A256GCM` public key to decrypt the response.

**Result.** After accepting consent and passing Face Verification, the verifier
received and decrypted a `vp_token` whose CBOR contained **all 11 fields of the mDL**
(`family_name`, `given_name`, `birth_date`, `issue_date`, `expiry_date`, `issuing_country`,
`issuing_authority`, `document_number`, `portrait`, `driving_privileges`,
`un_distinguishing_sign`), despite requesting only one. Any verifier that asks "is this person
of legal age?" receives the entire document today.

**Suggested fix** (8.7, point 2): filter `IssuerSignedItem` by `elementIdentifier`
against the `path` of each `Field` of the `presentation_definition` when building the `DeviceResponse`.

---

## References

**Project repositories**

- [`hsm-patch/`](hsm-patch/) — EC support patch for `AWSCloudHSMKeyStoreImpl` (Phase 1).
- [`compose/certify/patched-jars/`](compose/certify/patched-jars/README.md) — bytecode fixes
  to the issuer (Annex A.1, A.2).
- [`yalvarez/inji-wallet-verification`](https://github.com/yalvarez/inji-wallet-verification) —
  `vc-verifier-patch/` patch (Phase 5.1) and Swift port `vc-verifier-patch/ios/` (Phase 5.0).

**Reference code**

- [`openwallet-foundation-labs/mdoc-ts`](https://github.com/openwallet-foundation-labs/mdoc-ts)
  (`@owf/mdoc`, `@owf/cose`) — library of `verify/verify-mdoc.mjs` (Phase 6.2).
- [`openwallet-foundation/multipaz`](https://github.com/openwallet-foundation/multipaz) and
  [`multipaz-identity-reader`](https://github.com/openwallet-foundation/multipaz-identity-reader)
  — SDK and reference app (Phase 6.3).
- `mosip/keymanager`, `mosip/hsm-ref-impl`, `mosip/inji-wallet` (public) — basis of the HSM
  patch and comparison of the iOS defect.

**Regulations**

- ISO/IEC 18013-5:2021 — Mobile driving licence (mDL); ISO/IEC 18013-7 — online
  presentation.
- [Regulation (EU) 2024/1183 — eIDAS 2.0](https://eur-lex.europa.eu/eli/reg/2024/1183/oj/eng)
  — Art. 14, 47 and 71; third-country recognition (8.5).
- [Directive (EU) 2025/2205 — driving licences](https://eur-lex.europa.eu/eli/dir/2025/2205/oj/eng)
  — Art. 5 and 13; more relevant rule than eIDAS for a third-country mDL (8.5).
- [EUDI Wallet Architecture Reference Framework](https://eudi.dev/) — the EU's trust model for
  mdoc (Trusted Lists ETSI TS 119 612).
- [Implementing Decision (EU) 2025/2164](https://eur-lex.europa.eu/eli/dec_impl/2025/2164/oj)
  — current format of eIDAS trusted lists.
