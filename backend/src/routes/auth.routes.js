'use strict';

const { Router } = require('express');

const { HttpError } = require('../errors');
const { authenticate } = require('../middleware/authenticate');
const { MESSAGES } = require('../middleware/rbac');

/** Rutas de cuenta y sesión bajo `/api/auth`. */
function authRoutes({ authService, sessionService, recoveryService }) {
  const router = Router();

  /** `POST /api/auth/register`: 201 con `{ user }`. No abre sesión. */
  router.post('/register', async (req, res) => {
    const user = await authService.register(req.body);
    res.status(201).json({ user });
  });

  /** `POST /api/auth/login`: 200 con el token y la cuenta. */
  router.post('/login', async (req, res) => {
    res.status(200).json(await authService.login(req.body));
  });

  /** `GET /api/auth/me`: la cuenta de la sesión actual. */
  router.get('/me', authenticate({ sessionService }), async (req, res) => {
    const user = await authService.currentUser(req.auth.userId);
    // La cuenta se borró después de abrir la sesión.
    if (!user) throw new HttpError(401, MESSAGES.unauthenticated);
    res.status(200).json({ user });
  });

  /** `POST /api/auth/recover`: 200, igual exista o no la cuenta (S4-19). */
  router.post('/recover', async (req, res) => {
    res.status(200).json(await recoveryService.recover(req.body));
  });

  /** `POST /api/auth/reset`: 204 y cierra todas las sesiones (S4-19). */
  router.post('/reset', async (req, res) => {
    await recoveryService.reset(req.body);
    res.status(204).end();
  });

  return router;
}

module.exports = { authRoutes };
