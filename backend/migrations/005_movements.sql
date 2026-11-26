-- S5-01 · Movimientos de cada cuenta en la API (HU-01, HU-05, HU-06).
-- Reglas en docs/base-de-datos.md §3 y docs/contrato-api-acceso.md §3.12.
-- Una migración aplicada no se edita.

-- Mismas columnas que `movements` de SQLite (arquitectura.md §5), más el
-- dueño, la versión y las fechas de cambio para la sincronización (HU-36).
-- El signo sigue a SQLite: gastos y pagos negativos, entradas positivas,
-- así que no hay CHECK de signo (base-de-datos.md §3).
CREATE TABLE movements (
  id          uuid          PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     uuid          NOT NULL REFERENCES users (id) ON DELETE CASCADE,
  amount      numeric(14,2) NOT NULL,
  description text          NOT NULL,
  category    text          NOT NULL,
  date        timestamptz   NOT NULL,
  note        text,
  type        text          NOT NULL DEFAULT 'regular',
  -- Las llaves foráneas a cards y debts las agrega S5-04 junto con esas
  -- tablas. Borrar una tarjeta o deuda conserva sus pagos (S2-15).
  card_id     uuid,
  debt_id     uuid,
  version     integer       NOT NULL DEFAULT 1,
  created_at  timestamptz   NOT NULL DEFAULT now(),
  updated_at  timestamptz   NOT NULL DEFAULT now(),

  CONSTRAINT movements_amount_check
    CHECK (amount <> 0 AND abs(amount) <= 999999999.99),
  CONSTRAINT movements_description_check
    CHECK (description = btrim(description) AND char_length(description) BETWEEN 1 AND 60),
  CONSTRAINT movements_category_check
    CHECK (category = btrim(category) AND char_length(category) BETWEEN 1 AND 30),
  CONSTRAINT movements_note_check
    CHECK (note IS NULL OR char_length(note) <= 140),
  CONSTRAINT movements_type_check
    CHECK (type IN ('regular', 'payment')),
  -- Solo un pago lleva tarjeta o deuda, y nunca las dos.
  CONSTRAINT movements_link_check
    CHECK ((type = 'payment' OR (card_id IS NULL AND debt_id IS NULL))
           AND NOT (card_id IS NOT NULL AND debt_id IS NOT NULL)),
  CONSTRAINT movements_version_check CHECK (version >= 1)
);

-- "Los movimientos de esta cuenta en este mes, del más reciente al más
-- antiguo" (HU-07, HU-08).
CREATE INDEX movements_user_date_idx ON movements (user_id, date DESC);
