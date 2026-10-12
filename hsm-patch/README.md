# Parche: soporte EC en `AWSCloudHSMKeyStoreImpl` del fork del MTC

Este directorio contiene un parche listo para aplicar contra el archivo real
`certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/AWSCloudHSMKeyStoreImpl.java`
del repo privado `IUGO-MTC/inji-certify`, rama `feature/cloud-hsm` — **no** se aplicó
directamente a ese repo. Debe revisarse y aplicarse bajo el criterio del equipo del MTC.

## Por qué existe este parche

Confirmado por lectura completa de `AWSCloudHSMKeyStoreImpl.java` real (548 líneas, commit
de un desarrollador del equipo MTC/IUGO, `feature/cloud-hsm`): el único método que genera
pares de claves nuevos dentro del HSM (`generateKeyPair`) construye siempre un
`AlgorithmParameterSpec` RSA (`buildRsaSpec`), sin ninguna rama para otros algoritmos. La
capa de negocio de MOSIP (`KeymanagerServiceImpl`, repo público `mosip/keymanager`) sí sabe
pedir explícitamente una clave `EC_SECP256R1_SIGN` (mapeada a la curva NIST P-256,
confirmado en `KeymanagerServiceImpl.java:170`) — el hueco está exclusivamente en esta clase
específica del fork del MTC, que nunca implementó el camino EC. Sin este parche (o uno
equivalente), `generate-csr` con `referenceId=EC_SECP256R1_SIGN` fallaría contra el
CloudHSM real del MTC.

## Cómo aplicar

```bash
cd /ruta/al/checkout/de/IUGO-MTC/inji-certify
git checkout feature/cloud-hsm
git apply /ruta/a/mtc-mdl-poc/hsm-patch/AWSCloudHSMKeyStoreImpl.java.patch
```

Si el patch no aplica limpio (el archivo pudo cambiar desde que se investigó, leído contra
`origin/feature/cloud-hsm`, sin hash de commit específico — confirmar con `git log -1 -- certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/AWSCloudHSMKeyStoreImpl.java`
antes de aplicar), apliquen los cambios manualmente usando este patch como referencia —
son dos cambios acotados: una rama condicional nueva en `generateKeyPair`, y dos métodos
privados nuevos (`isEcAlgorithm`, `generateEcKeyPair`).

## Qué SÍ se confirmó contra código/documentación real

- **La curva correcta es P-256 (`secp256r1`).** Confirmado en `KeymanagerServiceImpl.java`
  (repo público `mosip/keymanager`, `kernel/kernel-keymanager-service/.../service/impl/KeymanagerServiceImpl.java:170`):
  `ecRefIdsAlgoNamesMap.put(KeyReferenceIdConsts.EC_SECP256R1_SIGN.name(), ECCurves.SECP256R1.name())`.
- **El patrón de reflection para no acoplar el classpath de compilación a las clases Cavium**
  (`Class.forName` + reflection en vez de `import com.cavium....`) es el patrón real que
  este mismo archivo ya usa para RSA y AES — el parche lo replica para mantener
  consistencia de estilo, aunque para EC específicamente terminó no siendo necesario (ver
  el punto de incertidumbre principal abajo).
- **`KeyPairGenerator.getInstance("EC", <nombreDelProvider>)` con `java.security.spec.ECGenParameterSpec`
  estándar del JDK es un patrón real y documentado** para el SDK Cavium/Luna — encontrado en
  fuentes de terceros y foros técnicos sobre CloudHSM Client SDK 3/Cavium JCE (no en un repo
  de ejemplos oficial de AWS con código verificable, ver la sección de abajo), con la forma
  exacta:
  ```java
  KeyPairGenerator keyPairGen = KeyPairGenerator.getInstance("EC", "Cavium");
  keyPairGen.initialize(new ECGenParameterSpec("secp256r1"));
  KeyPair keyPair = keyPairGen.generateKeyPair();
  ```
  El parche usa `cloudHSMProvider.getName()` en vez del literal `"Cavium"`, consistente con
  cómo el resto del archivo real ya referencia el provider (nunca hardcodea el nombre).

## Lo que NO se pudo confirmar contra código fuente — el riesgo real de este parche

**Este es el punto más importante de todo el documento — léanlo antes de asumir que el
parche funciona tal cual.**

1. **No existe código fuente público verificable de una clase `Cavium*KeyGenParameterSpec`
   específica para EC**, a diferencia de RSA (`CaviumRSAKeyGenParameterSpec`) y AES
   (`CaviumAESKeyGenParameterSpec`), que sí están confirmadas porque el propio archivo real
   del MTC las referencia por nombre completo. Se investigó:
   - `gh search code "CaviumECKeyGenParameterSpec"` y `"CaviumECGenParameterSpec"` — sin
     resultados en ningún repo público indexado por GitHub code search.
   - El repo oficial de ejemplos de AWS (`aws-samples/aws-cloudhsm-jce-examples`) — **usa
     un SDK completamente distinto** (`com.amazonaws.cloudhsm.jce.provider.CloudHsmProvider`
     + `KeyAttributesMap`/`EcParams`, confirmado leyendo `AsymmetricKeys.java` y
     `ECOperationsRunner.java` completos), no el SDK legacy Cavium
     (`com.cavium.provider.CaviumProvider`) que el archivo real del MTC usa. Son dos SDKs de
     CloudHSM distintos e incompatibles en su API Java — no se puede asumir que el patrón
     de uno aplica al otro sin verificarlo.
   - Una búsqueda web (no código fuente, foros/documentación de terceros) sugiere que en el
     SDK Cavium, a diferencia de RSA/AES, EC **no necesita** una clase de parámetros propia
     — el patrón estándar `KeyPairGenerator.getInstance("EC", "Cavium")` +
     `ECGenParameterSpec` del JDK basta. Esto es plausible (RSA/AES sí necesitan atributos
     HSM-específicos como `extractable`/`persistent` en su constructor, que el
     `ECGenParameterSpec` estándar no tiene espacio para expresar — consistente con por qué
     Cavium necesitó clases propias para esos dos algoritmos y potencialmente no para EC),
     pero **no está confirmado contra código fuente real**, solo contra fuentes de
     terceros no verificadas con el mismo rigor que el resto.

2. **Si el patrón de arriba es incorrecto** (si Cavium sí requiere una clase de parámetros EC
   propia con atributos `extractable`/`persistent`, análoga a `CaviumRSAKeyGenParameterSpec`,
   que este documento no pudo localizar), la clave EC generada por este parche **podría no
   quedar marcada como `KEY_PERSISTENT = true`** (la constante que el resto del archivo usa
   para RSA/AES) — lo que significaría que la clave no persiste correctamente en el HSM
   entre reinicios del pod. Este es el riesgo concreto de aplicar el parche tal cual sin
   verificarlo primero contra hardware real.

3. **El valor exacto del string que `KeymanagerServiceImpl` pasa como
   `asymmetricKeyAlgorithm`** para una petición `EC_SECP256R1_SIGN` no se confirmó
   empíricamente (no hay acceso a un CloudHSM real ni a logs reales de una petición
   `generate-csr` con esa referencia). El parche asume que es el string `"EC"` — razonable
   por convención estándar de JCE (`KeyPairGenerator.getInstance("EC")`), pero es una
   suposición, no una confirmación. **Antes de aplicar en un ambiente real, agreguen un log
   temporal** (`LOGGER.info(..., "asymmetricKeyAlgorithm real: " + asymmetricKeyAlgorithm)`)
   al inicio de `generateKeyPair` y disparen un `generate-csr` de prueba contra un
   CloudHSM no productivo (nunca contra producción) para confirmar el valor real antes de
   confiar en `isEcAlgorithm`.

## Cómo validar este parche cuando haya acceso a un CloudHSM real de prueba

1. Aplicar el parche contra una rama de prueba del fork (nunca directo a `feature/cloud-hsm`
   sin revisión).
2. Compilar y desplegar contra un CloudHSM **no productivo**, nunca el cluster de producción
   del MTC directamente.
3. Confirmar primero el valor real de `asymmetricKeyAlgorithm` (punto 3 de arriba) con el log
   temporal.
4. Disparar `POST /system-info/generate-csr` con
   `{"applicationId": "CERTIFY_VC_SIGN_EC_R1", "referenceId": "EC_SECP256R1_SIGN"}` (ver
   `IMPLEMENTATION.md` del repo, Fases 1 y 2, para el flujo completo de 3 pasos).
5. Si el CSR PEM resultante decodifica correctamente y su clave pública es genuinamente
   EC P-256 (no RSA — verificable con
   `openssl req -in csr.pem -noout -text | grep -A2 "Public Key Algorithm"`), el parche
   funciona en la ruta feliz.
6. Confirmar la persistencia: reiniciar el pod de Inji Certify y repetir `generate-csr` con
   el mismo `referenceId` — debe devolver el **mismo** CSR (misma clave), no generar una
   nueva. Si genera una nueva cada vez, la clave no está persistiendo en el HSM
   correctamente — señal de que el punto 2 de la sección anterior es real y hace falta la
   clase de parámetros EC propia de Cavium después de todo.

## Fuentes

- `IUGO-MTC/inji-certify`, rama `feature/cloud-hsm`,
  `certify-service/src/main/java/io/mosip/kernel/keymanager/hsm/impl/AWSCloudHSMKeyStoreImpl.java`
  (repo privado, código real leído completo — 548 líneas).
- `mosip/keymanager` (público),
  `kernel/kernel-keymanager-service/src/main/java/io/mosip/kernel/keymanagerservice/service/impl/KeymanagerServiceImpl.java`
  — confirma el mapeo `EC_SECP256R1_SIGN → SECP256R1`.
- `aws-samples/aws-cloudhsm-jce-examples` (público) — confirma que el SDK5 moderno de AWS
  (`com.amazonaws.cloudhsm.jce.*`) es una API distinta del SDK Cavium legacy
  (`com.cavium.*`) que el fork del MTC usa; no aporta el patrón EC real para Cavium.
- Búsqueda web (no código fuente verificado) sobre el patrón
  `KeyPairGenerator.getInstance("EC", "Cavium")` + `ECGenParameterSpec` estándar — la base
  del punto de mayor incertidumbre de este parche.
