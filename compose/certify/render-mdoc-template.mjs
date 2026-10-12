// compose/certify/render-mdoc-template.mjs
//
// Port a Node standalone de mdocVCTemplate del proyecto de código abierto
// `verifiably` (escrito en Go) — el MTC no corre Go, así que este script es
// la forma portable de regenerar el vc_template si la lista de campos
// cambia. Produce el mismo base64 que la función Go para la misma lista.

const NAMESPACE = 'org.iso.18013.5.1';
const DRIVING_PRIVILEGES_FIELD = 'driving_privileges';

// Orden fijo: el digestID es el índice en este array, así que el orden
// importa para reproducibilidad pero no para corrección (Inji Certify no
// impone un orden específico de digestID).
const FIELDS = [
  'family_name', 'given_name', 'birth_date', 'issue_date', 'expiry_date',
  'issuing_country', 'issuing_authority', 'document_number', 'portrait',
  'driving_privileges', 'un_distinguishing_sign',
];

function renderTemplate(namespace, fields) {
  const itemLines = fields.map((name, digestID) => {
    const accessor = `rootContext['${namespace}'].${name}`;
    const elementValue = name === DRIVING_PRIVILEGES_FIELD
      ? `\${${accessor}}`
      : `"\${${accessor}}"`;
    return `      {"digestID": ${digestID}, "elementIdentifier": "${name}", "elementValue": ${elementValue}}`;
  });
  const out = '{\n' +
    '  "nameSpaces": {\n' +
    `    "${namespace}": [\n` +
    itemLines.join(',\n') + '\n' +
    '    ]\n' +
    '  },\n' +
    '  "docType": "${_doctype}",\n' +
    '  "validityInfo": {"validFrom": "${_validFrom}", "validUntil": "${_validUntil}"}\n' +
    '}';
  return Buffer.from(out, 'utf8').toString('base64');
}

const b64 = renderTemplate(NAMESPACE, FIELDS);
console.log(b64);
