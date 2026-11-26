// S4-17 · Roles y aislamiento entre cuentas sobre el almacén en memoria
// (HU-34, HU-37 a HU-39, HU-41). Los casos están en
// helpers/rbac-isolation-cases.js.

const { createApp } = require('../src/app');
const { createMemoryStore } = require('../src/data/store');
const { definirCasosDeAislamiento } = require('./helpers/rbac-isolation-cases');

describe('Roles y aislamiento · memoria', () => {
  definirCasosDeAislamiento(async () => {
    const store = createMemoryStore();
    return { app: createApp({ store }), store };
  });
});
