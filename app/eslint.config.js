const js = require('@eslint/js');

const nodeGlobals = {
  process: 'readonly',
  console: 'readonly',
  require: 'readonly',
  module: 'readonly',
  __dirname: 'readonly',
  __filename: 'readonly',
  exports: 'writable',
  Buffer: 'readonly',
  global: 'readonly',
  setTimeout: 'readonly',
  setInterval: 'readonly',
  clearTimeout: 'readonly',
  clearInterval: 'readonly',
  fetch: 'readonly',
};

module.exports = [
  {
    ignores: ['node_modules/**', 'coverage/**'],
  },
  js.configs.recommended,
  {
    languageOptions: {
      ecmaVersion: 2024,
      sourceType: 'commonjs',
      globals: nodeGlobals,
    },
  },
];
