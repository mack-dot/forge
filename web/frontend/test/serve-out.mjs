// Development and test helper: serves the static export (`out/`) on 127.0.0.1.
// Node standard library only. Not a production server.
import http from "node:http";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".json": "application/json",
  ".txt": "text/plain; charset=utf-8",
  ".svg": "image/svg+xml",
  ".ico": "image/x-icon",
  ".woff2": "font/woff2",
};

export function serveOut(port = 3000, root = path.join(path.dirname(fileURLToPath(import.meta.url)), "..", "out")) {
  const server = http.createServer(async (req, res) => {
    try {
      let rel = decodeURIComponent(new URL(req.url ?? "/", "http://x").pathname);
      if (rel.endsWith("/")) rel += "index.html";
      const file = path.join(root, rel);
      if (!file.startsWith(root)) throw new Error("outside root");
      const body = await readFile(file);
      res.writeHead(200, {
        "Content-Type": TYPES[path.extname(file)] ?? "application/octet-stream",
        "Cache-Control": "no-store",
        // The page may talk to itself and to a loopback API only.
        "Content-Security-Policy":
          "default-src 'self'; script-src 'self' 'unsafe-inline'; style-src 'self' 'unsafe-inline'; connect-src 'self' http://127.0.0.1:*; img-src 'self' data:; base-uri 'none'; form-action 'none'",
      });
      res.end(body);
    } catch {
      res.writeHead(404, { "Content-Type": "text/plain" });
      res.end("not found");
    }
  });
  return new Promise((resolve) => server.listen(port, "127.0.0.1", () => resolve(server)));
}

if (import.meta.url === `file://${process.argv[1]}`) {
  const port = Number(process.env.PORT ?? 3000);
  await serveOut(port);
  console.log(`static export on http://127.0.0.1:${port}/`);
}
