// Test listener on 127.0.0.1: counts connections; exits after argv[2] ms; prints the count.
let n = 0; const srv = require('net').createServer((c) => { n++; c.destroy(); }).listen(0, '127.0.0.1', () => { require('fs').writeFileSync(process.argv[3], String(srv.address().port)); });
setTimeout(() => { console.log(JSON.stringify({ connections: n })); process.exit(0); }, Number(process.argv[2]));
