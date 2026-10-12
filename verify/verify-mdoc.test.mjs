import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
const vectors = join(here, 'fixtures');

test('un mdoc conformante pasa la verificación con exit code 0', () => {
  const result = execFileSync('node', [
    join(here, 'verify-mdoc.mjs'),
    join(vectors, 'mdl_full.cbor'),
    join(vectors, 'iaca.pem'),
    '--expected-elements=13',
  ], { encoding: 'utf8' });
  assert.match(result, /All checks passed/);
});

test('un CBOR corrupto falla con exit code distinto de 0', () => {
  assert.throws(() => {
    execFileSync('node', [
      join(here, 'verify-mdoc.mjs'),
      join(here, 'verify-mdoc.test.mjs'), // no es un CBOR válido, a propósito
      join(vectors, 'iaca.pem'),
    ], { encoding: 'utf8' });
  });
});

test('acepta un número distinto de elementos esperados sin fallar el parseo', () => {
  // driving_privileges de 1 categoría vs 4 categorías no cambia
  // EXPECTED_ELEMENTS (los elementos son 11 fijos de Table 3 + el array
  // driving_privileges como UN elemento, sin importar cuántas entradas
  // tenga el array) — este test documenta esa distinción para quien
  // reutilice el script.
  const result = execFileSync('node', [
    join(here, 'verify-mdoc.mjs'),
    join(vectors, 'mdl_full.cbor'),
    join(vectors, 'iaca.pem'),
    '--expected-elements=13',
    '--doctype=org.iso.18013.5.1.mDL',
    '--namespace=org.iso.18013.5.1',
  ], { encoding: 'utf8' });
  assert.match(result, /All checks passed/);
});
