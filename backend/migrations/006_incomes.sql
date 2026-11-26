-- S5-02 · Ingresos de cada cuenta en la API (HU-02, HU-09).
-- Reglas en docs/base-de-datos.md §3 y docs/contrato-api-acceso.md §3.13.
-- Una migración aplicada no se edita.

-- Mismas columnas que `incomes` de SQLite (arquitectura.md §5), más el
-- dueño, la versión y las fechas de cambio para la sincronización (HU-36),
-- igual que `movements` (005). Un ingreso siempre es positivo.
CREATE TABLE incomes (
  id          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  name        text          NOT NULL,
  amount      numeric(14,2) NOT NULL,
  date        timestamptz   NOT NULL,
  note        text,
  version     integer       NOT NULL DEFAULT 1,
  created_at  timestamptz   NOT NULL DEFAULT now(),
  updated_at  timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT incomes_amount_check
    CHECK (amount > 0 AND amount <= 999999999.99),
  CONSTRAINT incomes_name_check
    CHECK (name = btrim(name) AND char_length(name) BETWEEN 1 AND 60),
  CONSTRAINT incomes_note_check
    CHECK (note IS NULL OR char_length(note) <= 140),
  CONSTRAINT incomes_version_check CHECK (version >= 1)
);

-- "Los ingresos de esta cuenta en este mes" (HU-02, HU-09).
CREATE INDEX incomes_user_date_idx ON incomes (user_id, date DESC);
