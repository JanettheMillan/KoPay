-- S3-06 · Relación de autorización usuario–contador (HU-37 a HU-42).
-- Esquema acordado en docs/reglas-roles-contador.md §6 (S3-14) y
-- docs/base-de-datos.md (S3-04). Una migración aplicada no se edita.

-- Un permiso por concesión. Revocar llena revoked_at y no borra la fila,
-- así queda el historial. Vigente = revoked_at IS NULL; los permisos no
-- vencen solos.
CREATE TABLE accountant_access (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  -- La persona que autoriza (rol 'user').
  user_id       uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  -- El contador autorizado (rol 'accountant').
  accountant_id uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  granted_at    timestamptz NOT NULL DEFAULT now(),
  revoked_at    timestamptz,

  CONSTRAINT accountant_access_distinct_check CHECK (user_id <> accountant_id),
  CONSTRAINT accountant_access_revoked_check
    CHECK (revoked_at IS NULL OR revoked_at >= granted_at)
);

-- Solo un permiso vigente por pareja. Uno revocado no estorba para
-- conceder otro después.
CREATE UNIQUE INDEX accountant_access_active_key
  ON accountant_access (user_id, accountant_id)
  WHERE revoked_at IS NULL;

-- Consultas del contador: "¿quién me autorizó?" (HU-39) y la comprobación
-- de cada consulta (S4-06).
CREATE INDEX accountant_access_accountant_idx
  ON accountant_access (accountant_id)
  WHERE revoked_at IS NULL;

-- La comprobación de roles al insertar la hace el servicio (S4-05):
-- PostgreSQL no puede expresarla con un CHECK entre tablas.
