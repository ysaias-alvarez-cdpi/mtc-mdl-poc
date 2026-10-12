// compose/scripts/extract-root-cert.mjs
//
// Extrae el certificado autofirmado (issuer == subject) cuyo subject
// contiene "ROOT" de un bundle PEM con múltiples certificados — el bundle
// que `openssl pkcs12 -nokeys` produce a partir del keystore PKCS12 que
// Inji Certify genera en su primer boot (/home/inji/CERTIFY_PKCS12/local.p12,
// password "local", ver compose/scripts/run-e2e.sh para el detalle
// completo de por qué esta es la única forma confiable de obtener la IACA
// en este entorno — no existe un certify-root.pem suelto en esta versión
// de la imagen, y el propio CBOR emitido solo trae el certificado HOJA en
// su x5chain, no el ROOT).
//
// Uso: node extract-root-cert.mjs <bundle.pem> <salida-iaca.pem>
import { readFileSync, writeFileSync } from 'node:fs';
import { X509Certificate } from 'node:crypto';

const [, , bundlePath, outPath] = process.argv;
if (!bundlePath || !outPath) {
  console.error('Uso: node extract-root-cert.mjs <bundle.pem> <salida-iaca.pem>');
  process.exit(2);
}

const content = readFileSync(bundlePath, 'utf8');
const blocks = content
  .split(/(?=-----BEGIN CERTIFICATE-----)/)
  .filter((b) => b.includes('BEGIN CERTIFICATE'));

if (blocks.length === 0) {
  console.error(`ERROR: ningún bloque "BEGIN CERTIFICATE" encontrado en ${bundlePath}`);
  process.exit(1);
}

let found = null;
for (const block of blocks) {
  const end = block.indexOf('-----END CERTIFICATE-----');
  if (end === -1) continue;
  const certText = block.slice(0, end + '-----END CERTIFICATE-----'.length);
  let cert;
  try {
    cert = new X509Certificate(certText);
  } catch {
    continue;
  }
  if (cert.subject === cert.issuer && cert.subject.includes('ROOT') && cert.ca) {
    found = { certText, cert };
    break;
  }
}

if (!found) {
  console.error(`ERROR: ningún certificado autofirmado con "ROOT" en el subject y ca=true`);
  console.error(`encontrado entre los ${blocks.length} certificados de ${bundlePath}.`);
  console.error('Subjects vistos:');
  for (const block of blocks) {
    const end = block.indexOf('-----END CERTIFICATE-----');
    if (end === -1) continue;
    try {
      const cert = new X509Certificate(block.slice(0, end + 26));
      console.error(`  - ${cert.subject.replace(/\n/g, ', ')}`);
    } catch { /* ignore unparseable block */ }
  }
  process.exit(1);
}

writeFileSync(outPath, `${found.certText}\n`);
console.log(`IACA escrita: ${outPath}`);
console.log(`  subject: ${found.cert.subject.replace(/\n/g, ', ')}`);
