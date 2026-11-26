'use strict';

/**
 * Pruebas que necesitan PostgreSQL (S3-05): `npm run test:db`.
 * `npm test` las excluye para que corra sin base.
 */
module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/test/db/**/*.test.js'],
};
