"""Extract Mach-O layout facts of the linked refund executable. Read-only. Output: JSON on stdout.
Usage: python3 -I -B extract_macho.py <executable>"""
import sys, struct, hashlib, json
p = sys.argv[1]; b = open(p, 'rb').read()
out = {'path': p, 'size': len(b), 'sha256': hashlib.sha256(b).hexdigest()}
magic, cpu, sub, ftype, ncmds, szcmds, flags, _ = struct.unpack_from('<8I', b, 0)
out['header'] = {'magic': hex(magic), 'cputype': hex(cpu), 'filetype': ftype, 'ncmds': ncmds, 'sizeofcmds': szcmds, 'flags': hex(flags), 'MH_PIE': bool(flags & 0x200000)}
off = 32; segs = []; cmds = []
for i in range(ncmds):
    cmd, size = struct.unpack_from('<2I', b, off)
    rec = {'index': i, 'file_offset': off, 'cmd': hex(cmd), 'cmdsize': size}
    if cmd == 0x19:
        name = b[off+8:off+24].rstrip(b'\0').decode()
        vmaddr, vmsize, fileoff, filesize = struct.unpack_from('<4Q', b, off + 24)
        maxprot, initprot, nsects, sflags = struct.unpack_from('<4I', b, off + 56)
        secs = []
        for j in range(nsects):
            so = off + 72 + 80 * j
            sn = b[so:so+16].rstrip(b'\0').decode()
            addr, ssize = struct.unpack_from('<2Q', b, so + 32); soff, = struct.unpack_from('<I', b, so + 48)
            nreloc, = struct.unpack_from('<I', b, so + 60)
            secs.append({'sectname': sn, 'addr': hex(addr), 'size': ssize, 'offset': soff, 'nreloc': nreloc})
        rec.update({'segname': name, 'vmaddr': hex(vmaddr), 'vmsize': vmsize, 'fileoff': fileoff, 'filesize': filesize,
                    'maxprot': maxprot, 'initprot': initprot, 'sections': secs})
        segs.append(rec)
    elif cmd == 0x80000028:
        rec['entryoff'], rec['stacksize'] = struct.unpack_from('<2Q', b, off + 8)
    elif cmd in (0x80000034, 0x80000033, 0x1d, 0x26, 0x29):
        rec['dataoff'], rec['datasize'] = struct.unpack_from('<2I', b, off + 8)
    cmds.append(rec); off += size
out['load_commands'] = cmds
def sl(a, n): return b[a:a+n]
code_off, code_len = 0x40D0, 130436
bm_off, bm_words = 180224 + 0x18, 2531
code = sl(code_off, code_len); bm = sl(bm_off, 8 * bm_words)
out['slices'] = {
 'text_segment': {'fileoff': 0, 'len': 163840, 'sha256': hashlib.sha256(sl(0, 163840)).hexdigest()},
 'cml_main_stub': {'fileoff': 0x4000, 'vmaddr': hex(0x100004000), 'len': 108, 'sha256': hashlib.sha256(sl(0x4000, 108)).hexdigest()},
 'code': {'fileoff': code_off, 'vmaddr': hex(0x100000000 + code_off), 'len': code_len, 'sha256': hashlib.sha256(code).hexdigest()},
 'codebuffer': {'fileoff': code_off + code_len, 'len': 428, 'all_zero': not any(sl(code_off + code_len, 428))},
 'slots': {'fileoff': 180224, 'len': 24, 'hex': sl(180224, 24).hex()},
 'bitmaps': {'fileoff': bm_off, 'vmaddr': hex(0x10002C000 + 0x18), 'words': bm_words, 'len': 8 * bm_words, 'sha256': hashlib.sha256(bm).hexdigest()},
}
w = struct.unpack('<%dQ' % bm_words, bm)
out['controls'] = {'first_bitmap_word': hex(w[0]),
  'code_index_differs_at_plus4': next(i for i in range(code_len - 4) if code[i] != code[i + 4]),
  'bitmap_index_differs_at_plus1': next(i for i in range(bm_words - 1) if w[i] != w[i + 1])}
print(json.dumps(out, indent=1))
