'use strict';

/**
 * Rutas de `/api/movements` (S5-01, contrato §3.12). Se registran dentro
 * del router protegido de S4-03, así que `req.ownerId` ya es el id de la
 * sesión y el contador no llega aquí.
 */
function movementRoutes({ movementService }) {
  return (router) => {
    router.get('/', async (req, res) => {
      res.status(200).json({ movements: await movementService.list(req.ownerId, req.query) });
    });

    router.get('/:id', async (req, res) => {
      res.status(200).json({ movement: await movementService.get(req.ownerId, req.params.id) });
    });

    router.post('/', async (req, res) => {
      res.status(201).json({ movement: await movementService.create(req.ownerId, req.body) });
    });

    router.put('/:id', async (req, res) => {
      res
        .status(200)
        .json({ movement: await movementService.update(req.ownerId, req.params.id, req.body) });
    });

    router.delete('/:id', async (req, res) => {
      await movementService.remove(req.ownerId, req.params.id);
      res.status(204).end();
    });
  };
}

module.exports = { movementRoutes };
