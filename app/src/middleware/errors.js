import { HttpError } from '../lib/errors.js';

function classifyError(error) {
  if (error instanceof HttpError) {
    return {
      status: error.status,
      code: error.code,
      message: error.message,
    };
  }

  if (error?.type === 'entity.too.large') {
    return {
      status: 413,
      code: 'payload_too_large',
      message: 'The request body exceeds the 100kb limit.',
    };
  }

  if (error?.type === 'entity.parse.failed') {
    return {
      status: 400,
      code: 'invalid_json',
      message: 'The request body is not valid JSON.',
    };
  }

  return {
    status: 500,
    code: 'internal_error',
    message: 'Internal Server Error',
  };
}

export function errorHandler(error, req, res, _next) {
  const response = classifyError(error);
  const requestId = req.id ?? res.getHeader('X-Request-Id') ?? null;

  req.log.error(
    {
      err: error,
      errorCode: response.code,
      requestId,
    },
    'Request failed',
  );

  res
    .set('Cache-Control', 'no-store')
    .status(response.status)
    .json({
      error: {
        code: response.code,
        message: response.message,
        requestId,
      },
    });
}
