-- compose/certify/init-mdoc.sql
--
-- Seed SQL para que Inji Certify pueda firmar mso_mdoc con ECDSA P-256.
-- Replica el patrón de saveMdocSchema del proyecto de código abierto
-- `verifiably`, escrito a mano en SQL.
--
-- PRECONDICIÓN: correr esto SOLO si certify.key_policy_def no tiene ya una
-- fila CERTIFY_VC_SIGN_EC_R1. En un Inji Certify que solo ha emitido SD-JWT
-- (Ed25519), esta fila típicamente NO existe — confirmarlo primero con:
--   SELECT app_id FROM certify.key_policy_def WHERE app_id = 'CERTIFY_VC_SIGN_EC_R1';

INSERT INTO certify.key_policy_def(
    APP_ID, KEY_VALIDITY_DURATION, PRE_EXPIRE_DAYS, ACCESS_ALLOWED, IS_ACTIVE, CR_BY, CR_DTIMES
) VALUES (
    'CERTIFY_VC_SIGN_EC_R1', 1095, 60, 'NA', true, 'mtc-mdl-poc', now()
)
ON CONFLICT (APP_ID) DO NOTHING;

-- Continúa compose/certify/init-mdoc.sql

INSERT INTO certify.credential_config (
    credential_config_key_id, config_id, status, vc_template,
    doctype, sd_jwt_vct, context, credential_type, credential_format,
    did_url, key_manager_app_id, key_manager_ref_id,
    signature_algo, signature_crypto_suite, sd_claim,
    display, display_order, scope,
    cryptographic_binding_methods_supported,
    credential_signing_alg_values_supported,
    proof_types_supported,
    credential_subject, sd_jwt_claims, mso_mdoc_claims,
    plugin_configurations, cr_dtimes, upd_dtimes
) VALUES (
    'MTCDrivingLicenseMDL', 'MTCDrivingLicenseMDL', 'active',
    -- vc_template: base64 de un JSON con marcadores bracket-notation.
    -- Generado por compose/certify/render-mdoc-template.mjs a partir de la
    -- lista de campos — no editar el base64 a mano: un solo carácter mal
    -- puesto produce ERROR_SIGNING_QR_DATA en silencio.
    'ewogICJuYW1lU3BhY2VzIjogewogICAgIm9yZy5pc28uMTgwMTMuNS4xIjogWwogICAgICB7ImRpZ2VzdElEIjogMCwgImVsZW1lbnRJZGVudGlmaWVyIjogImZhbWlseV9uYW1lIiwgImVsZW1lbnRWYWx1ZSI6ICIke3Jvb3RDb250ZXh0WydvcmcuaXNvLjE4MDEzLjUuMSddLmZhbWlseV9uYW1lfSJ9LAogICAgICB7ImRpZ2VzdElEIjogMSwgImVsZW1lbnRJZGVudGlmaWVyIjogImdpdmVuX25hbWUiLCAiZWxlbWVudFZhbHVlIjogIiR7cm9vdENvbnRleHRbJ29yZy5pc28uMTgwMTMuNS4xJ10uZ2l2ZW5fbmFtZX0ifSwKICAgICAgeyJkaWdlc3RJRCI6IDIsICJlbGVtZW50SWRlbnRpZmllciI6ICJiaXJ0aF9kYXRlIiwgImVsZW1lbnRWYWx1ZSI6ICIke3Jvb3RDb250ZXh0WydvcmcuaXNvLjE4MDEzLjUuMSddLmJpcnRoX2RhdGV9In0sCiAgICAgIHsiZGlnZXN0SUQiOiAzLCAiZWxlbWVudElkZW50aWZpZXIiOiAiaXNzdWVfZGF0ZSIsICJlbGVtZW50VmFsdWUiOiAiJHtyb290Q29udGV4dFsnb3JnLmlzby4xODAxMy41LjEnXS5pc3N1ZV9kYXRlfSJ9LAogICAgICB7ImRpZ2VzdElEIjogNCwgImVsZW1lbnRJZGVudGlmaWVyIjogImV4cGlyeV9kYXRlIiwgImVsZW1lbnRWYWx1ZSI6ICIke3Jvb3RDb250ZXh0WydvcmcuaXNvLjE4MDEzLjUuMSddLmV4cGlyeV9kYXRlfSJ9LAogICAgICB7ImRpZ2VzdElEIjogNSwgImVsZW1lbnRJZGVudGlmaWVyIjogImlzc3VpbmdfY291bnRyeSIsICJlbGVtZW50VmFsdWUiOiAiJHtyb290Q29udGV4dFsnb3JnLmlzby4xODAxMy41LjEnXS5pc3N1aW5nX2NvdW50cnl9In0sCiAgICAgIHsiZGlnZXN0SUQiOiA2LCAiZWxlbWVudElkZW50aWZpZXIiOiAiaXNzdWluZ19hdXRob3JpdHkiLCAiZWxlbWVudFZhbHVlIjogIiR7cm9vdENvbnRleHRbJ29yZy5pc28uMTgwMTMuNS4xJ10uaXNzdWluZ19hdXRob3JpdHl9In0sCiAgICAgIHsiZGlnZXN0SUQiOiA3LCAiZWxlbWVudElkZW50aWZpZXIiOiAiZG9jdW1lbnRfbnVtYmVyIiwgImVsZW1lbnRWYWx1ZSI6ICIke3Jvb3RDb250ZXh0WydvcmcuaXNvLjE4MDEzLjUuMSddLmRvY3VtZW50X251bWJlcn0ifSwKICAgICAgeyJkaWdlc3RJRCI6IDgsICJlbGVtZW50SWRlbnRpZmllciI6ICJwb3J0cmFpdCIsICJlbGVtZW50VmFsdWUiOiAiJHtyb290Q29udGV4dFsnb3JnLmlzby4xODAxMy41LjEnXS5wb3J0cmFpdH0ifSwKICAgICAgeyJkaWdlc3RJRCI6IDksICJlbGVtZW50SWRlbnRpZmllciI6ICJkcml2aW5nX3ByaXZpbGVnZXMiLCAiZWxlbWVudFZhbHVlIjogJHtyb290Q29udGV4dFsnb3JnLmlzby4xODAxMy41LjEnXS5kcml2aW5nX3ByaXZpbGVnZXN9fSwKICAgICAgeyJkaWdlc3RJRCI6IDEwLCAiZWxlbWVudElkZW50aWZpZXIiOiAidW5fZGlzdGluZ3Vpc2hpbmdfc2lnbiIsICJlbGVtZW50VmFsdWUiOiAiJHtyb290Q29udGV4dFsnb3JnLmlzby4xODAxMy41LjEnXS51bl9kaXN0aW5ndWlzaGluZ19zaWdufSJ9CiAgICBdCiAgfSwKICAiZG9jVHlwZSI6ICIke19kb2N0eXBlfSIsCiAgInZhbGlkaXR5SW5mbyI6IHsidmFsaWRGcm9tIjogIiR7X3ZhbGlkRnJvbX0iLCAidmFsaWRVbnRpbCI6ICIke192YWxpZFVudGlsfSJ9Cn0=',
    'org.iso.18013.5.1.mDL', NULL, NULL, NULL, 'mso_mdoc',
    NULL, 'CERTIFY_VC_SIGN_EC_R1', 'EC_SECP256R1_SIGN',
    'ES256', 'EcdsaSecp256r1Signature2019', NULL,
    '[{"name":"Licencia de Conducir MTC (mDL)","locale":"es","background_color":"#12107c","text_color":"#FFFFFF","logo":{"url":"https://mosip.github.io/inji-config/logos/agro-vertias-logo.png","alt_text":"MTC Logo"},"background_image":{"uri":"https://mosip.github.io/inji-config/logos/agro-vertias-logo.png"}}]'::JSONB,
    ARRAY['family_name','given_name','birth_date','issue_date','expiry_date',
          'issuing_country','issuing_authority','document_number','portrait',
          'driving_privileges','un_distinguishing_sign'],
    'mtc_driving_license_mdl',
    ARRAY['cose_key'],
    ARRAY['ES256'],
    '{"jwt":{"proof_signing_alg_values_supported":["ES256"]}}'::JSONB,
    NULL, NULL,
    -- mso_mdoc_claims: mapa de campo -> display, anidado bajo el namespace
    -- ISO. Confirmado contra mdocCredentialConfigValues (db.go:415-422).
    '{"org.iso.18013.5.1":{
        "family_name":{"display":[{"name":"Apellidos","locale":"es"}]},
        "given_name":{"display":[{"name":"Nombres","locale":"es"}]},
        "birth_date":{"display":[{"name":"Fecha de nacimiento","locale":"es"}]},
        "issue_date":{"display":[{"name":"Fecha de emisión","locale":"es"}]},
        "expiry_date":{"display":[{"name":"Fecha de vencimiento","locale":"es"}]},
        "issuing_country":{"display":[{"name":"País emisor","locale":"es"}]},
        "issuing_authority":{"display":[{"name":"Autoridad emisora","locale":"es"}]},
        "document_number":{"display":[{"name":"Número de licencia","locale":"es"}]},
        "portrait":{"display":[{"name":"Fotografía","locale":"es"}]},
        "driving_privileges":{"display":[{"name":"Categorías de conducción","locale":"es"}]},
        "un_distinguishing_sign":{"display":[{"name":"Signo distintivo","locale":"es"}]}
    }}'::JSONB,
    NULL, NOW(), NULL
)
ON CONFLICT (credential_config_key_id) DO UPDATE SET
    vc_template            = EXCLUDED.vc_template,
    doctype                = EXCLUDED.doctype,
    credential_format      = EXCLUDED.credential_format,
    key_manager_app_id     = EXCLUDED.key_manager_app_id,
    key_manager_ref_id     = EXCLUDED.key_manager_ref_id,
    signature_algo         = EXCLUDED.signature_algo,
    signature_crypto_suite = EXCLUDED.signature_crypto_suite,
    display                = EXCLUDED.display,
    display_order          = EXCLUDED.display_order,
    mso_mdoc_claims         = EXCLUDED.mso_mdoc_claims,
    upd_dtimes             = NOW();
