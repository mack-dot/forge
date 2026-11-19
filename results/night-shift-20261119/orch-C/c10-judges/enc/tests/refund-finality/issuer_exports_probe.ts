// Loads the issuer module as untrusted code in the same process would, and prints what it can reach:
// the names that the module exports. Arguments as for the issuer. The key of this issuer instance is
// a new key in this process; the probe shows that the module hands out no key and no signing function.
// eslint-disable-next-line @typescript-eslint/no-require-imports
const issuer = require("../../ts/refund-finality/minter");
process.stdout.write(JSON.stringify({ probe: true, exportedNames: Object.keys(issuer).sort() }) + "\n");
process.stdin.destroy();
