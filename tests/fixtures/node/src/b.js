// Seeded dependent: imports ./a (internal) and left-pad (external).
const a = require('./a');
const lp = require('left-pad');
module.exports = { a, lp };
