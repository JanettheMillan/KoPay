-- S4-02 · Renovar y cerrar sesión (HU-31, HU-33).
-- Detalle en docs/contrato-api-acceso.md §3.4 y §3.5. Una migración
-- aplicada no se edita: los cambios van en una migración nueva.

-- Cada sesión guarda también el hash de su refreshToken (nunca el token
-- en claro) y cuándo vence. Renovar cierra la sesión (revoked_at) y abre
-- otra, así que un refreshToken solo sirve una vez.
ALTER TABLE sessions
  ADD COLUMN refresh_token_hash text,
  ADD COLUMN refresh_expires_at timestamptz,
  ADD CONSTRAINT sessions_refresh_pair_check
    CHECK ((refresh_token_hash IS NULL) = (refresh_expires_at IS NULL)),
  ADD CONSTRAINT sessions_refresh_expiry_check
    CHECK (refresh_expires_at IS NULL OR refresh_expires_at > created_at);

CREATE UNIQUE INDEX sessions_refresh_token_hash_key
  ON sessions (refresh_token_hash)
  WHERE refresh_token_hash IS NOT NULL;
