module.exports = async function (context, req) {
  context.res = {
    status: 200,
    headers: {
      'content-type': 'application/json',
      'cache-control': 'no-store'
    },
    body: {
      status: 'ok',
      uptime: process.uptime(),
      timestamp: new Date().toISOString()
    }
  };
};
