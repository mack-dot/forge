import { execFileSync } from "node:child_process";
import { writeFileSync } from "node:fs";
const out = execFileSync("/bin/bash", ["-c", "trap '' XFSZ; ulimit -f 1; exec node -e \"const fs=require('fs');const fd=fs.openSync(process.argv[1],'w');try{console.log('wrote',fs.writeSync(fd,'x'.repeat(1000)))}catch(e){console.log('err',e.code)}try{console.log('wrote2',fs.writeSync(fd,'y'.repeat(100)))}catch(e){console.log('err2',e.code)}\" " + process.argv[2]]).toString();
console.log(out);
