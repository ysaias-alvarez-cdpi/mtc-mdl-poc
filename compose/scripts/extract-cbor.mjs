// compose/scripts/extract-cbor.mjs
//
// Extrae el CBOR base64url de la respuesta JSON de Inji Certify y lo
// escribe a un archivo binario. DETECTA si viene envuelto en
// {docType, issuerSigned} y lo AVISA, pero no lo desenvuelve: escribe el CBOR
// crudo tal cual llega, envuelto o no. El tratamiento del wrapper queda del
// lado wallet (InjiWallet lo tolera); el verificador standalone requiere el
// IssuerSigned sin envolver.
//
// Confirmado contra el entorno real: en Inji Certify v0.14.0 el CBOR SIEMPRE
// llega envuelto en {docType, issuerSigned}, tanto por decodificación del CBOR
// emitido como por decompilación de
// io.mosip.certify.credential.MDocCredential.addProof, que construye
// explícitamente ese wrapper:
//   HashMap mDocSignedCredential = new HashMap();
//   mDocSignedCredential.put("docType", mso.get("docType"));
//   mDocSignedCredential.put("issuerSigned", issuerSigned);
// No depende de los datos de entrada: es el shape que esta versión produce
// siempre para mso_mdoc.
import { writeFileSync } from 'node:fs';
import { decode } from 'cbor-x';

const [, , outPath] = process.argv;
if (!outPath) {
  console.error('Uso: node extract-cbor.mjs <ruta-salida.cbor>  (lee la respuesta JSON de Inji Certify por stdin)');
  process.exit(2);
}

let input = '';
process.stdin.on('data', (chunk) => { input += chunk; });
process.stdin.on('end', () => {
  let response;
  try {
    response = JSON.parse(input);
  } catch (err) {
    console.error('ERROR: la respuesta de Inji Certify no es JSON válido:');
    console.error(input);
    process.exit(1);
  }
  const credentialB64Url = response.credential;
  if (!credentialB64Url) {
    console.error('ERROR: la respuesta de Inji Certify no trae el campo "credential":');
    console.error(input);
    process.exit(1);
  }
  const cborBytes = Buffer.from(credentialB64Url, 'base64url');
  writeFileSync(outPath, cborBytes);
  console.log(`CBOR escrito: ${outPath} (${cborBytes.length} bytes)`);

  let wrapped = false;
  try {
    const decoded = decode(cborBytes);
    if (decoded && typeof decoded === 'object' && 'docType' in decoded && 'issuerSigned' in decoded) {
      wrapped = true;
      console.log('AVISO: el CBOR viene envuelto en {docType, issuerSigned} (comportamiento conocido de Inji Certify 0.14.0; el parser de InjiWallet lo tolera, el verificador standalone requiere desenvolverlo).');
      console.log(`  docType detectado: ${decoded.docType}`);
      console.log('verify-mdoc.mjs fallará el parseo de IssuerSigned sobre este archivo porque @owf/mdoc espera el mapa IssuerSigned directo, no el envoltorio.');
    }
  } catch (err) {
    console.log(`INFO: el CBOR no decodificó como {docType, issuerSigned} tampoco (${err.message}).`);
    console.log('verify-mdoc.mjs lo reportará con su propio mensaje de error.');
  }

  // Señal de salida para que run-e2e.sh sepa si debe intentar el
  // verificador o reportar el wrapper directamente sin correrlo.
  process.exit(wrapped ? 3 : 0);
});
