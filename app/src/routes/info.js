import { Router } from 'express';

import { getInfo } from '../services/info.js';

export const infoRouter = Router();

infoRouter.get('/api/info', async (_req, res, next) => {
  try {
    res.set('Cache-Control', 'no-store').status(200).json(getInfo());
  } catch (error) {
    next(error);
  }
});
