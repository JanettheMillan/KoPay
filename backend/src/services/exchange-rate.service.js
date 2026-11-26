'use strict';

const { ERROR_CODES, HttpError } = require('../errors');

/**
 * Tipo de cambio FIX USD/MXN del SIE de Banxico (HU-35, S5-06).
 *
 * - Serie SF43718 (FIX), dato "oportuno": el último publicado. En fin de
 *   semana o festivo es el del último día hábil.
 * - Caché en memoria de una hora: el FIX es diario y Banxico limita las
 *   consultas por token.
 * - Tiempo de espera de 5 s. Si Banxico falla, tarda o rechaza el token,
 *   responde `503 UNAVAILABLE` sin detalles. El token nunca sale en
 *   respuestas ni en la consola.
 */
const SERIES_ID = 'SF43718';
const BANXICO_URL = `https://www.banxico.org.mx/SieAPIRest/service/v1/series/${SERIES_ID}/datos/oportuno`;
const TIMEOUT_MS = 5_000;
const CACHE_TTL_MS = 60 * 60 * 1000;
const SOURCE = 'Banxico FIX';

const MESSAGES = Object.freeze({
  unavailable: 'El tipo de cambio no está disponible. Inténtalo más tarde.',
});

/** Fecha de Banxico `dd/mm/aaaa` a `aaaa-mm-dd`, o `null` si no es válida. */
function toIsoDate(fecha) {
  const match = /^(\d{2})\/(\d{2})\/(\d{4})$/.exec(typeof fecha === 'string' ? fecha.trim() : '');
  if (!match) return null;
  const [, day, month, year] = match;
  const iso = `${year}-${month}-${day}`;
  const date = new Date(`${iso}T00:00:00Z`);
  return date.toISOString().startsWith(iso) ? iso : null;
}

/** Valor de Banxico (`"17.2345"`, `"1,017.50"` o `"N/E"`) a número, o `null`. */
function toRate(dato) {
  if (typeof dato !== 'string') return null;
  const clean = dato.trim().replace(/,/g, '');
  if (!/^\d+(\.\d+)?$/.test(clean)) return null;
  const rate = Number(clean);
  return rate > 0 ? rate : null;
}

/**
 * Último dato publicado de la respuesta de Banxico, o `null` si la
 * respuesta no trae uno válido.
 */
function parseBanxico(body) {
  const series = body?.bmx?.series;
  const serie = Array.isArray(series) ? series.find((s) => s?.idSerie === SERIES_ID) : null;
  const datos = Array.isArray(serie?.datos) ? serie.datos : [];
  for (let i = datos.length - 1; i >= 0; i -= 1) {
    const date = toIsoDate(datos[i]?.fecha);
    const rate = toRate(datos[i]?.dato);
    if (date && rate) return { date, rate };
  }
  return null;
}

/** Error que no explica la causa: la app solo necesita saber que falló. */
class UpstreamError extends Error {}

function createExchangeRateService({
  token,
  fetchImpl = globalThis.fetch,
  now = () => new Date(),
  logger = console,
  timeoutMs = TIMEOUT_MS,
  cacheTtlMs = CACHE_TTL_MS,
} = {}) {
  let cache = null;
  let pending = null;

  async function fetchFromBanxico() {
    if (!token) throw new UpstreamError('sin BANXICO_TOKEN');
    let res;
    try {
      res = await fetchImpl(BANXICO_URL, {
        headers: { 'Bmx-Token': token, Accept: 'application/json' },
        signal: AbortSignal.timeout(timeoutMs),
      });
    } catch (err) {
      const reason = err?.name === 'TimeoutError' || err?.name === 'AbortError'
        ? `sin respuesta en ${timeoutMs / 1000} s`
        : 'error de red';
      throw new UpstreamError(reason);
    }
    // 400, 401 o 403: token inválido; 429: límite de consultas; 5xx: caída.
    if (!res.ok) throw new UpstreamError(`Banxico respondió ${res.status}`);

    let body;
    try {
      body = await res.json();
    } catch {
      throw new UpstreamError('respuesta que no es JSON');
    }
    const latest = parseBanxico(body);
    if (!latest) throw new UpstreamError('respuesta sin un dato válido');
    return { base: 'USD', quote: 'MXN', rate: latest.rate, date: latest.date, source: SOURCE };
  }

  return {
    /**
     * `{ base, quote, rate, date, source }` con el FIX más reciente.
     * Lanza `HttpError` 503 si no se pudo obtener y no hay caché vigente.
     */
    async getUsdMxn() {
      if (cache && now().getTime() - cache.fetchedAt < cacheTtlMs) return { ...cache.value };

      // Varias peticiones a la vez comparten una sola consulta a Banxico.
      pending ??= fetchFromBanxico().finally(() => {
        pending = null;
      });
      try {
        const value = await pending;
        cache = { value, fetchedAt: now().getTime() };
        return { ...value };
      } catch (err) {
        // Solo el motivo, nunca el token ni la URL con datos de la cuenta.
        logger.error(`Tipo de cambio no disponible: ${err instanceof UpstreamError ? err.message : 'error inesperado'}`);
        throw new HttpError(503, MESSAGES.unavailable, { code: ERROR_CODES.UNAVAILABLE });
      }
    },
  };
}

module.exports = {
  BANXICO_URL,
  CACHE_TTL_MS,
  MESSAGES,
  SERIES_ID,
  TIMEOUT_MS,
  createExchangeRateService,
  parseBanxico,
};
