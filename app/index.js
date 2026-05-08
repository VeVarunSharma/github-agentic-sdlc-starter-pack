const express = require('express');
const pkg = require('./package.json');

const app = express();

app.get('/', (req, res) => {
  res.status(200).json({ name: pkg.name, version: pkg.version });
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok', uptime: process.uptime() });
});

// Generic error handler — return 500 without leaking stack traces.
// eslint-disable-next-line no-unused-vars
app.use((err, req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'Internal Server Error' });
});

if (require.main === module) {
  const port = process.env.PORT || 3000;
  app.listen(port, () => {
    console.log(`Server listening on port ${port}`);
  });
}

module.exports = app;
