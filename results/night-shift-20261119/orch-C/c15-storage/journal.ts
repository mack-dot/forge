// Builds a SQLite rollback journal (file format section 3 of https://sqlite.org/fileformat2.html; from knowledge, offline)
// whose playback makes the database file equal to `target` (all pages of target; initial size = target pages).
export function makeJournal(target: Buffer, sector = 512): Buffer {
  const pageSize = (() => { const p = target.readUInt16BE(16); return p === 1 ? 65536 : p; })();
  const n = target.length / pageSize; if (!Number.isInteger(n)) throw new Error("target is not whole pages");
  const nonce = 0x1b2c3d4e;
  const hdr = Buffer.alloc(sector);
  Buffer.from("d9d505f920a163d7", "hex").copy(hdr, 0);
  hdr.writeUInt32BE(n, 8); hdr.writeUInt32BE(nonce, 12); hdr.writeUInt32BE(n, 16); hdr.writeUInt32BE(sector, 20); hdr.writeUInt32BE(pageSize, 24);
  const recs: Buffer[] = [hdr];
  for (let p = 1; p <= n; p++) {
    const data = target.subarray((p - 1) * pageSize, p * pageSize);
    let ck = nonce >>> 0; for (let i = pageSize - 200; i > 0; i -= 200) ck = (ck + data[i]) >>> 0;
    const r = Buffer.alloc(4 + pageSize + 4); r.writeUInt32BE(p, 0); data.copy(r, 4); r.writeUInt32BE(ck, 4 + pageSize); recs.push(r);
  }
  return Buffer.concat(recs);
}
