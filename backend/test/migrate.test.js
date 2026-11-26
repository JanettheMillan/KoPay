'use strict';

// S3-05 · Script de migraciones y salud con PostgreSQL, sin base real
// (HU-30, HU-34). Los casos con PostgreSQL están en test/db/.

const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const request = require('supertest');

const { createApp } = require('../src/app');
const { loadConfig } = require('../src/config');
const { listMigrations, runMigrations } = require('../src/data/migrate');
const { POOL_OPTIONS, createPgStore } = require('../src/data/pg-store');

/** Cliente falso que anota cada consulta y puede fallar en una. */
function fakeClient({ applied = [], failOn } = {}) {
  const calls = [];
  return {
    calls,
    async query(sql, params) {
      calls.push(sql.trim().split('\n')[0]);
      if (failOn && sql.includes(failOn)) throw new Error('sintaxis');
      if (sql.startsWith('SELECT version FROM schema_migrations')) {
        return { rows: applied.map((version) => ({ version })) };
      }
      return { rows: [], params };
    },
  };
}

const sample = [
  { version: '001', name: '001_a.sql', sql: 'CREATE TABLE a ()' },
  { version: '002', name: '002_b.sql', sql: 'CREATE TABLE b ()' },
];

describe('Lista de migraciones', () => {
  test('MIG-01 · HU-30 · lee backend/migrations en orden con la 001 de usuarios y sesiones', () => {
    const migrations = listMigrations();
    expect(migrations[0].name).toBe('001_users_roles_sessions.sql');
    expect(migrations[0].sql).toContain('CREATE TABLE users');
    expect(migrations[0].sql).toContain('CREATE TABLE sessions');
    const versions = migrations.map((m) => m.version);
    expect([...versions].sort()).toEqual(versions);
  });

  test('MIG-02 · HU-30 · rechaza nombres inválidos y números repetidos', () => {
    const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'kopay-mig-'));
    try {
      fs.writeFileSync(path.join(dir, 'usuarios.sql'), '');
      expect(() => listMigrations(dir)).toThrow('nombre inválido');
      fs.rmSync(path.join(dir, 'usuarios.sql'));
      fs.writeFileSync(path.join(dir, '001_a.sql'), '');
      fs.writeFileSync(path.join(dir, '001_b.sql'), '');
      expect(() => listMigrations(dir)).toThrow('Dos migraciones con el número 001');
    } finally {
      fs.rmSync(dir, { recursive: true, force: true });
    }
  });
});

describe('Aplicar migraciones', () => {
  test('MIG-03 · HU-30 · aplica solo las pendientes, cada una en su transacción', async () => {
    const client = fakeClient({ applied: ['001'] });
    const done = await runMigrations(client, { migrations: sample });

    expect(done).toEqual(['002_b.sql']);
    expect(client.calls).not.toContain('CREATE TABLE a ()');
    const i = client.calls.indexOf('CREATE TABLE b ()');
    expect(client.calls[i - 1]).toBe('BEGIN');
    expect(client.calls[i + 1]).toMatch(/^INSERT INTO schema_migrations/);
    expect(client.calls[i + 2]).toBe('COMMIT');
  });

  test('MIG-04 · HU-30 · si una falla, la deshace, no sigue y libera el candado', async () => {
    const client = fakeClient({ failOn: 'CREATE TABLE a' });
    await expect(runMigrations(client, { migrations: sample })).rejects.toThrow(
      'La migración 001_a.sql falló y se deshizo',
    );
    expect(client.calls).toContain('ROLLBACK');
    expect(client.calls).not.toContain('CREATE TABLE b ()');
    expect(client.calls.at(-1)).toMatch(/pg_advisory_unlock/);
  });
});

describe('Salud con PostgreSQL', () => {
  test('DB-05 · HU-34 · sin base alcanzable, /api/health responde 503 sin mostrar la conexión', async () => {
    const databaseUrl = 'postgres://kopay:secreto123@127.0.0.1:1/kopay_test';
    const store = createPgStore({ databaseUrl });
    try {
      const app = createApp({ config: loadConfig({ NODE_ENV: 'test' }), store });
      const res = await request(app).get('/api/health');

      expect(res.status).toBe(503);
      expect(res.body.status).toBe('error');
      expect(res.body.data).toEqual({ kind: 'postgres', ok: false });
      expect(res.text).not.toContain('secreto123');
      expect(res.text).not.toContain('127.0.0.1');
    } finally {
      await store.close();
    }
  });

  test('DB-06 · HU-34 · el pool usa los valores acordados en S3-04', () => {
    expect(POOL_OPTIONS).toEqual({
      max: 5,
      idleTimeoutMillis: 10000,
      connectionTimeoutMillis: 5000,
    });
    expect(() => createPgStore({})).toThrow('Falta DATABASE_URL');
  });
});
