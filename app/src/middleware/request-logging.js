import { randomUUID } from 'node:crypto';

import pinoHttp from 'pino-http';

const requestIdPattern = /^[A-Za-z0-9._:-]{1,128}$/;

export function createRequestLogger(logger) {
  return pinoHttp({
    logger,
    genReqId(req, res) {
      const suppliedId = req.headers['x-request-id'];
      const requestId =
        typeof suppliedId === 'string' && requestIdPattern.test(suppliedId)
          ? suppliedId
          : randomUUID();

      res.setHeader('X-Request-Id', requestId);
      return requestId;
    },
    serializers: {
      req(req) {
        return {
          id: req.id,
          method: req.method,
          url: req.url,
          remoteAddress: req.remoteAddress,
        };
      },
      res(res) {
        return {
          statusCode: res.statusCode,
        };
      },
    },
  });
}
