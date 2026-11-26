-- S3-05 · Usuarios, roles y sesiones (HU-30 a HU-34).
-- Acuerdos en docs/base-de-datos.md (S3-04) y docs/contrato-api-acceso.md
-- (S3-13). Una migración aplicada no se edita: los cambios van en una
-- migración nueva.

-- Cuentas. El rol decide la vista (HU-37): las cuentas creadas desde la
-- app son 'user'; las de contador se crean fuera de la app (S3-14).
CREATE TABLE users (
  id            uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  name          text        NOT NULL,
  email         text        NOT NULL,
  password_hash text        NOT NULL,
  role          text        NOT NULL DEFAULT 'user',
  created_at    timestamptz NOT NULL DEFAULT now(),
  updated_at    timestamptz NOT NULL DEFAULT now(),

  CONSTRAINT users_name_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 80),
  -- El correo se guarda recortado y en minúsculas (contrato §1), así que
  -- `Ana@Mail.com` no puede crear una segunda cuenta.
  CONSTRAINT users_email_check
    CHECK (email = lower(btrim(email)) AND char_length(email) BETWEEN 3 AND 254
           AND position('@' IN email) > 1),
  CONSTRAINT users_role_check
    CHECK (role IN ('user', 'accountant')),
  -- Nunca la contraseña en texto plano: solo su hash (S3-08).
  CONSTRAINT users_password_hash_check
    CHECK (char_length(password_hash) >= 20)
);

CREATE UNIQUE INDEX users_email_key ON users (email);

-- Sesiones abiertas. Solo se guarda el hash del token; el token en claro
-- lo tiene únicamente la app. Cerrar sesión (S4-02) llena revoked_at.
CREATE TABLE sessions (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  token_hash  text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,
  revoked_at  timestamptz,

  CONSTRAINT sessions_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT sessions_revoked_check
    CHECK (revoked_at IS NULL OR revoked_at >= created_at)
);

CREATE UNIQUE INDEX sessions_token_hash_key ON sessions (token_hash);
CREATE INDEX sessions_user_id_idx ON sessions (user_id);
