-- S4-19 · Códigos de recuperación de acceso (HU-32).
-- Mecanismo en docs/contrato-api-acceso.md §3.7 a §3.9. Una migración
-- aplicada no se edita: los cambios van en una migración nueva.

-- Un código de 6 dígitos por solicitud. Nunca se guarda el código, solo
-- su hash. Vale el más reciente de cada cuenta: pedir otro borra los
-- anteriores. Vence a los 15 minutos, sirve una vez y admite 5 intentos.
CREATE TABLE password_resets (
  id          uuid        PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid        NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  code_hash   text        NOT NULL,
  created_at  timestamptz NOT NULL DEFAULT now(),
  expires_at  timestamptz NOT NULL,
  attempts    integer     NOT NULL DEFAULT 0,
  used_at     timestamptz,

  CONSTRAINT password_resets_expiry_check CHECK (expires_at > created_at),
  CONSTRAINT password_resets_attempts_check CHECK (attempts BETWEEN 0 AND 5),
  CONSTRAINT password_resets_used_check
    CHECK (used_at IS NULL OR used_at >= created_at),
  -- Un hash HMAC-SHA256 en hexadecimal; un código de 6 dígitos no cabe.
  CONSTRAINT password_resets_code_hash_check CHECK (char_length(code_hash) = 64)
);

-- "¿Cuál es el código vigente de esta cuenta?"
CREATE INDEX password_resets_user_id_idx ON password_resets (user_id, created_at DESC);
