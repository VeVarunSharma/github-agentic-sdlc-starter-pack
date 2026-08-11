import { NotFoundError } from '../lib/errors.js';

export function notFoundHandler(_req, _res, next) {
  next(new NotFoundError());
}
