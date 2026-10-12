// compose/certify/mock-fee-plugin/src/test/java/pe/gob/mtc/mock/MockFeeDataProviderPluginTest.java
//
// Prueba fetchData(Map<String,Object>) -> JSONObject (SPI DataProviderPlugin)
// directamente y aserta sobre el JSONObject resultante.
//
// Restricciones de Inji Certify 0.14.0 que estos tests fijan (ver el
// encabezado de MockFeeDataProviderPlugin):
//
// 1. driving_privileges viaja como STRING JSON, no JSONArray real: los tests
//    lo parsean con `new JSONArray(subject.getString("driving_privileges"))`.
// 2. El JSONObject anida los campos bajo la key del namespace ISO
//    ("org.iso.18013.5.1") Y los repite planos en el nivel superior; los
//    tests verifican ambas copias.
// 3. La key de identityDetails es "sub", con el document_number embebido en
//    su valor JSON ({"org.iso.18013.5.1":{"document_number":"..."}}). Un test
//    cubre el fallback a individualId/individual_id por si otro flujo puebla
//    identityDetails de esa forma.
package pe.gob.mtc.mock;

import org.json.JSONArray;
import org.json.JSONObject;
import org.junit.jupiter.api.Test;

import java.util.Map;

import static org.junit.jupiter.api.Assertions.*;

class MockFeeDataProviderPluginTest {

    private static final String NAMESPACE = "org.iso.18013.5.1";

    private static Map<String, Object> subWithDocumentNumber(String documentNumber) {
        return Map.of("sub", "{\"" + NAMESPACE + "\":{\"document_number\":\"" + documentNumber + "\"}}");
    }

    @Test
    void oneCategoryDocumentReturnsOnePrivilege() throws Exception {
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(subWithDocumentNumber("MOCK-1CAT"));

        assertTrue(subject.get("driving_privileges") instanceof String,
            "driving_privileges debe viajar como String JSON — ver comentario en fetchData");
        JSONArray privileges = new JSONArray(subject.getString("driving_privileges"));
        assertEquals(1, privileges.length());
        JSONObject first = privileges.getJSONObject(0);
        assertEquals("A-I", first.getString("vehicle_category_code"));
        assertNotNull(first.getString("issue_date"));
        assertNotNull(first.getString("expiry_date"));
    }

    @Test
    void fourCategoryDocumentReturnsFourPrivileges() throws Exception {
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(subWithDocumentNumber("MOCK-4CAT"));

        JSONArray privileges = new JSONArray(subject.getString("driving_privileges"));
        assertEquals(4, privileges.length());
    }

    @Test
    void credentialSubjectHasPortrait() throws Exception {
        // portrait se incluye siempre: sin él, el marcador
        // ${rootContext[...].portrait} de la plantilla Velocity queda sin
        // sustituir y el wallet lo muestra como una URI de imagen rota. El
        // parche de certify/patched-jars decodifica este valor a bytes crudos
        // antes de escribirlo como CBOR bstr.
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(subWithDocumentNumber("MOCK-1CAT"));

        assertTrue(subject.has("portrait"), "falta portrait (plano)");
        assertTrue(subject.getJSONObject(NAMESPACE).has("portrait"), "falta portrait (anidado)");
        String portrait = subject.getString("portrait");
        assertFalse(portrait.isEmpty());
        // Confirma que es base64 válido decodificable — lo mismo que el
        // parche de MDocProcessor intentará hacer.
        assertDoesNotThrow(() -> java.util.Base64.getDecoder().decode(portrait));
    }

    @Test
    void fetchDataEchoesDocumentNumberFromSubClaims() throws Exception {
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(subWithDocumentNumber("MOCK-4CAT"));

        assertEquals("MOCK-4CAT", subject.getString("document_number"));
    }

    @Test
    void fetchDataFallsBackToIndividualIdWhenSubMissing() throws Exception {
        // Cobertura del fallback a suposiciones de otros flujos (p.ej.
        // auth-code con identity system) — ver el comentario de clase.
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(Map.of("individualId", "MOCK-4CAT"));

        assertEquals("MOCK-4CAT", subject.getString("document_number"));
        assertEquals(4, new JSONArray(subject.getString("driving_privileges")).length());
    }

    @Test
    void fetchDataFallsBackToDefaultWhenIdentityDetailsMissingKnownKeys() throws Exception {
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(Map.of("someUnrelatedKey", "irrelevant"));

        // Con ninguna key reconocida presente, cae al default determinístico
        // (1 categoría) — documentado en resolveDocumentNumber().
        assertEquals("MOCK-1CAT", subject.getString("document_number"));
        assertEquals(1, new JSONArray(subject.getString("driving_privileges")).length());
    }

    @Test
    void allExpectedCredentialConfigFieldsArePresentBothFlatAndNested() throws Exception {
        // Confirma que fetchData produce exactamente las keys que
        // compose/certify/init-mdoc.sql (credential_subject/mso_mdoc_claims)
        // espera — tanto planas (jsonObject.toMap() aplanado por
        // CertifyIssuanceServiceImpl) como anidadas bajo el namespace (lo
        // que Velocity's rootContext lee). portrait incluido — ver
        // credentialSubjectHasPortrait() y el comentario en fetchData().
        var plugin = new MockFeeDataProviderPlugin();
        JSONObject subject = plugin.fetchData(subWithDocumentNumber("MOCK-1CAT"));

        assertTrue(subject.has(NAMESPACE), "falta la key anidada del namespace: " + NAMESPACE);
        JSONObject nested = subject.getJSONObject(NAMESPACE);

        for (String field : new String[] {
                "family_name", "given_name", "birth_date", "issue_date", "expiry_date",
                "issuing_country", "issuing_authority", "document_number", "portrait",
                "driving_privileges", "un_distinguishing_sign"}) {
            assertTrue(subject.has(field), "falta el campo esperado (plano): " + field);
            assertTrue(nested.has(field), "falta el campo esperado (anidado): " + field);
        }
    }
}
