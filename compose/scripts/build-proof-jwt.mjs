// compose/scripts/build-proof-jwt.mjs
//
// Construye un proof JWT ES256 anónimo (sin kid/iss) para el flujo
// pre-authorized_code: header {typ,alg,jwk}, sin kid/iss (OID4VCI §7.2.1.1,
// anonymous pre-auth). `aud` es el credential_issuer BASE (p. ej.
// https://localhost:8094), no el endpoint /v1/certify/issuance/credential:
// con el endpoint completo Inji Certify responde invalid_proof.
import { generateKeyPairSync, createSign } from 'node:crypto';

const [, , cNonce, audience] = process.argv;

if (!cNonce || !audience) {
  console.error('Uso: node build-proof-jwt.mjs <c_nonce> <audience>');
  process.exit(2);
}

const { publicKey, privateKey } = generateKeyPairSync('ec', { namedCurve: 'P-256' });
const jwk = publicKey.export({ format: 'jwk' });

const header = { typ: 'openid4vci-proof+jwt', alg: 'ES256', jwk };
const now = Math.floor(Date.now() / 1000);
const payload = { aud: audience, iat: now, nonce: cNonce };

const b64url = (obj) => Buffer.from(JSON.stringify(obj)).toString('base64url');
const signingInput = `${b64url(header)}.${b64url(payload)}`;

const sign = createSign('SHA256');
sign.update(signingInput);
sign.end();
const derSignature = sign.sign(privateKey);

// ECDSA DER -> raw (r||s) 64 bytes, formato que JWS ES256 exige.
function derToRaw(der) {
  let offset = 2;
  const rLen = der[offset + 1];
  offset += 2;
  let r = der.subarray(offset, offset + rLen);
  offset += rLen;
  offset += 1;
  const sLen = der[offset];
  offset += 1;
  let s = der.subarray(offset, offset + sLen);
  r = r.length > 32 ? r.subarray(r.length - 32) : Buffer.concat([Buffer.alloc(32 - r.length), r]);
  s = s.length > 32 ? s.subarray(s.length - 32) : Buffer.concat([Buffer.alloc(32 - s.length), s]);
  return Buffer.concat([r, s]);
}

const rawSignature = derToRaw(derSignature).toString('base64url');
console.log(`${signingInput}.${rawSignature}`);
