'use strict';

const { Router } = require('express');

/** Rutas de cuenta y sesión bajo `/api/auth`. */
function authRoutes({ authService }) {
  const router = Router();

  /** `POST /api/auth/register`: 201 con `{ user }`. No abre sesión. */
  router.post('/register', async (req, res) => {
    const user = await authService.register(req.body);
    res.status(201).json({ user });
  });

  return router;
}

module.exports = { authRoutes };
