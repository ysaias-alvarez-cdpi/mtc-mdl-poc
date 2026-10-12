# certify-service-patched.jar

Parches de bytecode sobre `injistack/inji-certify-with-plugins:0.14.0`'s
`certify-service.jar`, aplicados con [Javassist](https://www.javassist.org/)
(no requiere ni el código fuente completo ni recompilar Certify). Dos
parches independientes, ambos sobre `MDocProcessor.class`, apilados en el
mismo jar.

## Parche 1: fragmento DID (`#0`) rompe el proof JWT del holder key

### El bug

`io.mosip.certify.utils.MDocProcessor.createDeviceKeyInfo(Object deviceInfo)`
recibe el holder key como un DID en formato `did:jwk:`, generado por
`io.mosip.certify.proof.DIDjwkProofManager.getDID(JWSHeader)` a partir del
proof JWT del wallet. Cuando el JWT trae el holder key vía `kid` con el
formato estándar `did:jwk:<base64url-JWK>#0` (el `#0` es el fragmento DID
URL fijo que exige el spec [did:jwk](https://github.com/quartzjer/did-jwk/blob/main/spec.md#to-create-the-did-url)),
`DIDjwkProofManager.getDID` devuelve ese string completo, `#0` incluido
(`getDID`, rama `header.getKeyID().startsWith(DID_JWK_PREFIX)`, retorna
`header.getKeyID()` sin tocar el fragmento).

`createDeviceKeyInfo` recorta el prefijo `did:jwk:` pero **nunca recorta
el fragmento `#0`** antes de pasar el string a
`Base64.getUrlDecoder().decode(...)` — y `#` no es un carácter base64url
válido, así que revienta con:

```
java.lang.IllegalArgumentException: Illegal base64 character 23
	at io.mosip.certify.utils.MDocProcessor.createDeviceKeyInfo(MDocProcessor.java:418)
```

Confirmado empíricamente con un proof JWT real de `io.mosip.vciclient`
0.6.0 (`inji-vci-client-aar`, la librería real de `inji-wallet`),
capturado en `certify-nginx`'s `proof_debug.log` durante la prueba
end-to-end con dispositivo real — el `kid` real era:

```
did:jwk:eyJrdHkiOiJFQyIsImtpZCI6...InVzZSI6InNpZyJ9#0
```

No es un problema de configuración de este entorno — es un bug real de
Certify 0.14.0 en el flujo `mso_mdoc` con `proof_type: jwt` cuando el
holder key llega vía `kid` (en vez de `jwk` inline en el header), que es
exactamente cómo lo arma `io.mosip.vciclient`. Bloquea TODA emisión de
`mso_mdoc` con ese wallet, no solo en este entorno.

## El fix

`DIDjwkProofManager.getKeyFromHeader` ya resuelve el mismo problema
correctamente en otro punto del código:

```java
String base64JWK = did.split("#")[0].substring(DID_JWK_PREFIX.length());
```

El parche replica ese `split("#")[0]` dentro de
`createDeviceKeyInfo`, justo antes de cada llamada a
`Base64.getUrlDecoder().decode(...)` en ese método (hay 3: el
`deviceKeyEncoded` completo, y los campos `x`/`y` del JWK — los tres se
cubren por seguridad, aunque solo el primero se vio afectado en la
práctica).

### Cómo se generó (parche 1)

1. Se extrajo `certify-service.jar` del contenedor:
   `docker cp compose-certify-1:/home/inji/certify-service.jar .`
2. Se decompiló `MDocProcessor.createDeviceKeyInfo` con `javap -c` para
   confirmar el bytecode exacto (ver `IMPLEMENTATION.md`, Anexo A.1).
3. Se escribió un programa Java pequeño (`PatchMDocProcessor.java`,
   usando la librería `javassist` — `org.javassist:javassist:3.29.2-GA`
   de Maven Central) que usa `CtMethod.instrument(ExprEditor)` para
   interceptar cada llamada a `Base64$Decoder.decode` dentro de
   `createDeviceKeyInfo` y anteponerle el recorte del fragmento `#`.
4. Se reempaquetó el jar reemplazando únicamente la entrada
   `BOOT-INF/classes/io/mosip/certify/utils/MDocProcessor.class` (el resto
   del jar, ~533 entradas, quedó sin tocar) — usando Python `zipfile` para
   la reescritura (el `jar -u` del JDK 17.0.10 usado en esta máquina no
   actualizaba in-place como se esperaba; truncaba el archivo a solo la
   entrada nueva en vez de fusionar).
5. Se verificó con `javap -c` sobre el jar final que el bytecode parchado
   esté presente, y que el conteo de entradas del jar (533) coincida con
   el original.

## Parche 2: `portrait` se codifica como CBOR `tstr`, ISO 18013-5 exige `bstr`

### El bug

Confirmado por desensamblado de bytecode contra la imagen v0.14.0:
`MDocProcessor.preprocessForCBOR(Object obj)` solo tiene cuatro ramas de
tipo — `byte[]` (se devuelve tal cual), `String` (solo se revisa si es una
fecha vía `isDateOnlyString`; si no, se devuelve tal cual), `Map` y `List`
(recursión). **Ninguna rama decodifica base64 a bytes** — cualquier
`String`, imagen o no, termina envuelto como `UnicodeString` (CBOR `tstr`)
por `convertToDataItem`, nunca como el `bstr` (byte string) que ISO
18013-5 exige para el campo `portrait`.

Esto es indistinto de si el dato de origen tiene o no una foto real: aun
con un JPEG válido en base64 en los datos del plugin, el mDL resultante
tendría `portrait` mal tipado. Sin foto (el estado del mock antes de este
parche), el síntoma visible era peor: como la plantilla Velocity
(`vc_template`) sigue declarando el campo `portrait` con el marcador
`${rootContext['org.iso.18013.5.1'].portrait}` pero el dato nunca llega
(el mock lo omite a propósito), Velocity nunca sustituye la expresión —
el string literal del marcador queda escrito dentro del mDL real, y el
wallet real (`inji-wallet`) lo muestra como una URI de imagen rota:
`ReactImageView: Image source "${rootContext['org.iso.18013.5.1'].portrait}"
doesn't exist` (confirmado empíricamente abriendo el detalle de la
credencial en la app).

### El fix

`preprocessForCBOR(Object obj)` recibe solo el *valor* de cada campo, no
su nombre — no puede distinguir "esto es portrait" de cualquier otro
string por sí solo. El nombre de campo sí está disponible un nivel más
arriba, en la rama `Map` de ese mismo método (`entry.getKey()`/
`entry.getValue()` dentro del `for` sobre `map.entrySet()`). El parche
intercepta la llamada recursiva `preprocessForCBOR(entry.getValue())` en
ese punto exacto (identificada por su número de línea en el
`LineNumberTable`, no por búsqueda de texto): si el valor es un `String`
no vacío, se decodifica como base64 estándar primero, luego base64url
como fallback, y si ninguno decodifica, cae de vuelta al comportamiento
original (`preprocessForCBOR` recursivo, sin tocar nada). El resultado
`byte[]` fluye hacia la rama `byte[]` ya existente y correcta del propio
método — sin duplicar esa lógica — y `convertToDataItem` lo envuelve
como CBOR `bstr`, conforme al spec. Ningún otro campo (`family_name`,
`document_number`, etc.) pasa por esta rama nueva.

**Condición correcta.** Un `IssuerSignedItem` real tiene el shape
`{"random": ..., "digestID": ..., "elementIdentifier": "portrait",
"elementValue": "<base64>"}`. La condición compara el `Map` **padre**
(`"portrait".equals(map.get("elementIdentifier"))`) y decodifica solo la entry cuya key es
`"elementValue"`. Comparar `entry.getKey()` con `"portrait"` nunca es verdadero y deja el
parche sin efecto sin ningún error: `verifyValueDigests` da `match=True` tanto para `tstr`
como para `bstr`. Verificar siempre que `portrait` llega como `bytes` en el CBOR decodificado.

### Cómo se generó (parche 2)

Mismo mecanismo que el parche 1 (`PatchPortrait.java`, Javassist,
`CtMethod.instrument(ExprEditor)`), apuntando esta vez a
`preprocessForCBOR` en vez de `createDeviceKeyInfo`, y usando
`MethodCall.getLineNumber()` (no el nombre de variable, que Javassist no
puede usar de forma confiable para desambiguar dos llamadas al mismo
método dentro del mismo bloque) para identificar la llamada exacta a
reemplazar. Aplicado sobre el `.class` ya parchado por el parche 1 (ambos
parches conviven en el mismo `MDocProcessor.class` final) y reempaquetado
con el mismo script Python `patch_jar.py`.

**Nota sobre `LineNumberTable` y el orden de aplicación:** el número de
línea de la llamada `preprocessForCBOR(entry.getValue())` **depende de
si el parche 1 ya se aplicó antes sobre el mismo `.class`** — Javassist
reescribe el `LineNumberTable` de *todos* los métodos de la clase al
guardarla, no solo del método tocado. Contra el jar original sin ningún
parche, esa llamada está en la línea 265; después de aplicar el parche 1
primero (el orden real que usa este flujo, ambos parches sobre el mismo
`classesDir`), la misma llamada migra a la línea 264. Apuntar a la línea
equivocada no produce ningún error — Javassist simplemente no encuentra
match y el parche queda sin aplicar en silencio. `PatchPortrait.java`
usa `cc.toBytecode()` + escritura manual (en vez de `cc.writeFile()`)
específicamente para poder verificar el tamaño del `.class` resultante
antes de persistirlo, como señal temprana de que el patch sí encontró y
reemplazó algo.

## Cómo se aplica

Montado como volumen en `docker-compose.yml`, sobre el jar original
dentro de la imagen:

```yaml
volumes:
  - ./certify/patched-jars/certify-service-patched.jar:/home/inji/certify-service.jar:ro
```

## Estado

Workaround para el entorno de pruebas. El fix real debe aplicarse en el código fuente del
fork de Inji Certify del MTC y proponerse a `mosip/inji-certify` (repo público); no se
recomienda depender de este jar parchado a mano fuera del entorno de pruebas.
