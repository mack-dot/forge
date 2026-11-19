// benign probe: records that it ran in a process whose main script is minter.ts. Writes only a marker file.
const fs = require("node:fs");
if (process.argv.some(a => a.endsWith("minter.ts"))) fs.appendFileSync(process.env.C11_MARK, "probe ran in minter pid " + process.pid + "\n");
