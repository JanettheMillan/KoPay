'use strict';

const { Router } = require('express');

const { HttpError } = require('../errors');
const { BEARER, authenticate } = require('../middleware/authenticate');
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

  /**
   * `POST /api/auth/refresh` (S4-02): 200 igual que el login, con tokens
   * nuevos. El refreshToken usado deja de servir.
   */
  router.post('/refresh', async (req, res) => {
    res.status(200).json(await authService.refresh(req.body));
  });

  /**
   * `POST /api/auth/logout` (S4-02): cierra la sesión del token y responde
   * 204. Con un token inválido, cerrado o sin token también responde 204:
   * el resultado para la persona es el mismo (contrato §3.4).
   */
  router.post('/logout', async (req, res) => {
    const match = BEARER.exec(req.get('authorization') ?? '');
    if (match) await sessionService.close(match[1]);
    res.status(204).end();
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
