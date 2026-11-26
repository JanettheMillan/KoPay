'use strict';

/**
 * Rutas de `/api/incomes` (S5-02, contrato §3.13). Se registran dentro
 * del router protegido de S4-03, así que `req.ownerId` ya es el id de la
 * sesión y el contador no llega aquí.
 */
function incomeRoutes({ incomeService }) {
  return (router) => {
    router.get('/', async (req, res) => {
      res.status(200).json({ incomes: await incomeService.list(req.ownerId, req.query) });
    });

    router.get('/:id', async (req, res) => {
      res.status(200).json({ income: await incomeService.get(req.ownerId, req.params.id) });
    });

    router.post('/', async (req, res) => {
      res.status(201).json({ income: await incomeService.create(req.ownerId, req.body) });
    });

    router.put('/:id', async (req, res) => {
      res.status(200).json({ income: await incomeService.update(req.ownerId, req.params.id, req.body) });
    });

    router.delete('/:id', async (req, res) => {
      await incomeService.remove(req.ownerId, req.params.id);
      res.status(204).end();
    });
  };
}

module.exports = { incomeRoutes };
