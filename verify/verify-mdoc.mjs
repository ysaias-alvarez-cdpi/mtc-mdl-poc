#!/usr/bin/env node
// verify/verify-mdoc.mjs
//
// Verificador standalone de mdocs. Usa @owf/mdoc, una implementación
// independiente de la del emisor, así que una lectura equivocada del estándar
// del lado emisor no pasaría aquí también. Acepta CUALQUIER mdoc y
// certificado por argumento. Adaptado del proyecto de código abierto
// `verifiably`.
//
// Uso:
//   node verify-mdoc.mjs <archivo.cbor> <iaca.pem> \
//     [--expected-elements=N] [--doctype=X] [--namespace=Y]

import { readFileSync } from 'node:fs';
import { X509Certificate, createHash, randomBytes, webcrypto } from 'node:crypto';
import { parseArgs } from 'node:util';

import { IssuerSigned, MdlError } from '@owf/mdoc';
import { CoseKey, SignatureAlgorithm } from '@owf/cose';

const { positionals, values } = parseArgs({
  allowPositionals: true,
  options: {
    'expected-elements': { type: 'string' },
    doctype: { type: 'string', default: 'org.iso.18013.5.1.mDL' },
    namespace: { type: 'string', default: 'org.iso.18013.5.1' },
  },
});

if (positionals.length < 2) {
  console.error('Uso: node verify-mdoc.mjs <archivo.cbor> <iaca.pem> [--expected-elements=N] [--doctype=X] [--namespace=Y]');
  process.exit(2);
}

const [cborPath, iacaPath] = positionals;
const EXPECTED_ELEMENTS = values['expected-elements'] ? parseInt(values['expected-elements'], 10) : null;
const DOCTYPE = values.doctype;
const NAMESPACE = values.namespace;
const NOW = new Date();

const mdocBytes = new Uint8Array(readFileSync(cborPath));
const iacaCert = new X509Certificate(readFileSync(iacaPath, 'utf8'));

let failures = 0;
const check = (name, ok, detail = '') => {
  console.log(`${ok ? 'PASS' : 'FAIL'}  ${name}${detail ? ` — ${detail}` : ''}`);
  if (!ok) failures += 1;
};

const derOf = (cert) => new Uint8Array(cert.raw);

const subtleAlgFor = (alg) => {
  switch (alg) {
    case SignatureAlgorithm.ES256: return { name: 'ECDSA', hash: 'SHA-256', namedCurve: 'P-256' };
    case SignatureAlgorithm.ES384: return { name: 'ECDSA', hash: 'SHA-384', namedCurve: 'P-384' };
    case SignatureAlgorithm.ES512: return { name: 'ECDSA', hash: 'SHA-512', namedCurve: 'P-521' };
    default: throw new Error(`verify-mdoc: algoritmo COSE no soportado ${alg}`);
  }
};

// MdocContext — contexto criptográfico de @owf/mdoc (adaptado de
// `verifiably`); hace el trabajo criptográfico real y no depende de qué
// CBOR/certificado se le pase.
const ctx = {
  fetch,
  crypto: {
    random: (length) => new Uint8Array(randomBytes(length)),
    digest: ({ digestAlgorithm, bytes }) =>
      new Uint8Array(createHash(digestAlgorithm.replace('-', '')).update(bytes).digest()),
    hdkf: () => { throw new Error('verify-mdoc: HKDF no implementado; no requerido para verificación de emisión'); },
  },
  cose: {
    sign1: {
      sign: () => { throw new Error('verify-mdoc: firma no implementada; este script solo verifica'); },
      verify: async ({ toBeVerified, signature, key, algorithm }) => {
        const alg = algorithm ?? key.algorithm ?? SignatureAlgorithm.ES256;
        const params = subtleAlgFor(alg);
        const imported = await webcrypto.subtle.importKey(
          'jwk', key.jwk, { name: params.name, namedCurve: params.namedCurve }, false, ['verify'],
        );
        return webcrypto.subtle.verify({ name: params.name, hash: params.hash }, imported, signature, toBeVerified);
      },
    },
    mac0: {
      generate: () => { throw new Error('verify-mdoc: MAC0 no implementado'); },
      verify: () => { throw new Error('verify-mdoc: MAC0 no implementado'); },
    },
  },
  x509: {
    getIssuerNameField: ({ certificate, field }) => {
      const cert = new X509Certificate(Buffer.from(certificate));
      return cert.issuer.split('\n').map((line) => line.split('=')).filter(([k]) => k.trim() === field).map(([, v]) => v.trim());
    },
    getPublicKey: async ({ certificate, algorithm }) => {
      const cert = new X509Certificate(Buffer.from(certificate));
      const jwk = cert.publicKey.export({ format: 'jwk' });
      const key = CoseKey.fromJwk(jwk);
      if (algorithm !== undefined && key.algorithm === undefined) {
        return CoseKey.create({ keyType: key.keyType, curve: key.curve, x: key.x, y: key.y, algorithm });
      }
      return key;
    },
    verifyCertificateChain: ({ trustedCertificates, x5chain, now = NOW }) => {
      if (!x5chain || x5chain.length === 0) throw new Error('verify-mdoc: x5chain vacío');
      const chain = x5chain.map((der) => new X509Certificate(Buffer.from(der)));
      const anchors = trustedCertificates.map((der) => new X509Certificate(Buffer.from(der)));
      for (const cert of chain) {
        if (now < new Date(cert.validFrom) || now > new Date(cert.validTo)) {
          throw new Error(`verify-mdoc: certificado ${cert.subject} no es válido en ${now.toISOString()}`);
        }
      }
      for (let i = 0; i < chain.length - 1; i += 1) {
        if (!chain[i].verify(chain[i + 1].publicKey)) {
          throw new Error(`verify-mdoc: ${chain[i].subject} no está firmado por ${chain[i + 1].subject}`);
        }
      }
      const top = chain[chain.length - 1];
      const anchor = anchors.find((a) => {
        if (a.raw.equals(top.raw)) return a.ca;
        return top.verify(a.publicKey) && a.ca;
      });
      if (!anchor) throw new Error('verify-mdoc: la cadena no termina en un certificado CA de confianza');
      if (now < new Date(anchor.validFrom) || now > new Date(anchor.validTo)) {
        throw new Error('verify-mdoc: el ancla de confianza no es válida al momento de verificar');
      }
      const out = chain.map((c) => new Uint8Array(c.raw));
      if (!anchor.raw.equals(top.raw)) out.push(new Uint8Array(anchor.raw));
      return { chain: out };
    },
    getCertificateData: ({ certificate }) => {
      const cert = new X509Certificate(Buffer.from(certificate));
      return {
        issuerName: cert.issuer, subjectName: cert.subject, serialNumber: cert.serialNumber,
        thumbprint: cert.fingerprint256, notBefore: new Date(cert.validFrom), notAfter: new Date(cert.validTo),
        pem: cert.toString(),
      };
    },
  },
};

let issuerSigned;
try {
  issuerSigned = IssuerSigned.decode(mdocBytes);
  check('IssuerSigned decodifica bajo los esquemas de @owf/mdoc', true);
} catch (err) {
  check('IssuerSigned decodifica bajo los esquemas de @owf/mdoc', false, err.message);
  console.log('\nNo se puede continuar sin un IssuerSigned parseado.');
  process.exit(1);
}

const mso = issuerSigned.issuerAuth.mobileSecurityObject;
const assessments = [];
try {
  const result = await issuerSigned.verify(
    { now: NOW, trustedCertificates: [{ issuance: [derOf(iacaCert)] }], disableStatusValidation: true, verificationCallback: (a) => assessments.push(a) },
    ctx,
  );
  const failed = assessments.filter((a) => a.status === 'FAILED');
  for (const a of failed) console.log(`      assessment fallido [${a.category}] ${a.check}${a.reason ? `: ${a.reason}` : ''}`);
  check('verificación completa del emisor (firma, cadena, digests)', failed.length === 0, `${assessments.length} assessments, ${failed.length} fallidos`);
  check('la cadena termina en el ancla de confianza (IACA)', !!result.trustedIssuanceChain && result.trustedIssuanceChain.length >= 2,
    result.trustedIssuanceChain ? `${result.trustedIssuanceChain.length} certificados` : 'sin cadena de confianza');
} catch (err) {
  check('verificación completa del emisor (firma, cadena, digests)', false, err instanceof MdlError ? err.message : String(err));
  check('la cadena termina en el ancla de confianza (IACA)', false, 'la verificación lanzó una excepción');
}

check('docType coincide con el esperado', mso.docType === DOCTYPE, `${mso.docType} (esperado: ${DOCTYPE})`);

const digestIds = mso.valueDigests.getDigestIdsForNamespace(NAMESPACE);
check('valueDigests presentes para el namespace ISO', mso.valueDigests.getNamespaces().includes(NAMESPACE), mso.valueDigests.getNamespaces().join(', '));
if (EXPECTED_ELEMENTS !== null) {
  check(`${EXPECTED_ELEMENTS} elementos comprometidos (digests)`, digestIds.length === EXPECTED_ELEMENTS, String(digestIds.length));
} else {
  console.log(`INFO  ${digestIds.length} elementos comprometidos (digests) — sin valor esperado dado, no se compara`);
}

const items = issuerSigned.getIssuerNamespace(NAMESPACE) ?? [];
if (EXPECTED_ELEMENTS !== null) {
  check(`${EXPECTED_ELEMENTS} elementos divulgables en el namespace ISO`, items.length === EXPECTED_ELEMENTS, String(items.length));
} else {
  console.log(`INFO  ${items.length} elementos divulgables en el namespace ISO`);
}

const drivingPrivilegesItem = items.find((i) => i.elementIdentifier === 'driving_privileges');
if (drivingPrivilegesItem) {
  const value = drivingPrivilegesItem.elementValue;
  check('driving_privileges es un array real (no un string)', Array.isArray(value), typeof value);
  if (Array.isArray(value)) {
    check('driving_privileges tiene al menos 1 categoría', value.length >= 1, `${value.length} categorías`);
    check('cada categoría tiene vehicle_category_code', value.every((p) => {
      const code = typeof p.get === 'function' ? p.get('vehicle_category_code') : p.vehicle_category_code;
      return typeof code === 'string' && code.length > 0;
    }));
  }
} else {
  console.log('INFO  driving_privileges no está presente en este mdoc (Photo ID u otro docType sin ese elemento)');
}

const validity = mso.validityInfo;
check('validityInfo presente', !!validity);
check('validFrom precede a validUntil', !!validity && validity.validFrom < validity.validUntil);

check('el MSO vincula una device key', !!mso.deviceKeyInfo?.deviceKey, mso.deviceKeyInfo?.deviceKey ? `curva ${mso.deviceKeyInfo.deviceKey.curve}` : 'ausente');

console.log(failures === 0 ? '\nAll checks passed.' : `\n${failures} check(s) failed.`);
process.exit(failures === 0 ? 0 : 1);
