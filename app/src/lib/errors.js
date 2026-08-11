export class HttpError extends Error {
  constructor(status, code, message) {
    super(message);
    this.name = 'HttpError';
    this.status = status;
    this.code = code;
  }
}

export class NotFoundError extends HttpError {
  constructor() {
    super(404, 'not_found', 'The requested resource was not found.');
    this.name = 'NotFoundError';
  }
}
