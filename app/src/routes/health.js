import { Router } from 'express';

import { getHealth } from '../services/health.js';

export const healthRouter = Router();

healthRouter.get('/health', async (_req, res, next) => {
  try {
    res.set('Cache-Control', 'no-store').status(200).json(getHealth());
  } catch (error) {
    next(error);
  }
});
