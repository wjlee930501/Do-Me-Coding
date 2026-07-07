"use strict";

const { greet } = require("./util");

function main() {
  console.log(greet("host-app"));
}

if (require.main === module) {
  main();
}

module.exports = { main };
