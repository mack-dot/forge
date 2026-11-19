#!/usr/bin/env python3 -I
"""Y9: independent Mach-O 64 parser (pure Python, struct only).

Written from the Mach-O format (mach-o/loader.h, nlist.h, fixup-chains.h layouts
as known to the author), WITHOUT reading extract_macho.py or the HOL ML reader.
Usage: python3 -I y9_macho.py <file> [--json out.json]
"""
import struct, sys, hashlib, json

LC = {0x19: "LC_SEGMENT_64", 0x2: "LC_SYMTAB", 0xb: "LC_DYSYMTAB", 0xe: "LC_LOAD_DYLINKER",
      0xc: "LC_LOAD_DYLIB", 0x80000018: "LC_LOAD_WEAK_DYLIB", 0x1b: "LC_UUID",
      0x32: "LC_BUILD_VERSION", 0x2a: "LC_SOURCE_VERSION", 0x80000028: "LC_MAIN",
      0x26: "LC_FUNCTION_STARTS", 0x29: "LC_DATA_IN_CODE", 0x1d: "LC_CODE_SIGNATURE",
      0x80000034: "LC_DYLD_CHAINED_FIXUPS", 0x80000033: "LC_DYLD_EXPORTS_TRIE",
      0x80000022: "LC_DYLD_INFO_ONLY", 0x22: "LC_DYLD_INFO", 0x8000001c: "LC_RPATH"}


def cstr(b):
    return b.split(b"\0", 1)[0].decode("ascii", "replace")


def parse(data):
    out = {}
    magic, cputype, cpusub, ftype, ncmds, sizeofcmds, flags, res = struct.unpack_from("<IiiIIIII", data, 0)
    assert magic == 0xFEEDFACF, hex(magic)
    out["header"] = dict(magic=magic, cputype=cputype, cpusubtype=cpusub & 0xffffffff, filetype=ftype,
                         ncmds=ncmds, sizeofcmds=sizeofcmds, flags=flags, MH_PIE=bool(flags & 0x200000))
    off = 32
    cmds, segs, dylibs = [], [], []
    for i in range(ncmds):
        cmd, size = struct.unpack_from("<II", data, off)
        c = dict(index=i, offset=off, cmd=cmd, name=LC.get(cmd, hex(cmd)), cmdsize=size)
        if cmd == 0x19:
            (segname, vmaddr, vmsize, fileoff, filesize, maxprot, initprot, nsects, sflags) = \
                struct.unpack_from("<16sQQQQiiII", data, off + 8)
            seg = dict(segname=cstr(segname), vmaddr=vmaddr, vmsize=vmsize, fileoff=fileoff,
                       filesize=filesize, maxprot=maxprot, initprot=initprot, nsects=nsects,
                       flags=sflags, sections=[], field_offsets=dict(
                           segname=off + 8, vmaddr=off + 24, vmsize=off + 32, fileoff=off + 40,
                           filesize=off + 48, nsects=off + 64))
            so = off + 72
            for _ in range(nsects):
                (sn, sg, addr, ssize, soff, align, reloff, nreloc, fl, r1, r2, r3) = \
                    struct.unpack_from("<16s16sQQIIIIIIII", data, so)
                seg["sections"].append(dict(sectname=cstr(sn), segname=cstr(sg), addr=addr, size=ssize,
                                            offset=soff, align=align, nreloc=nreloc, flags=fl,
                                            type=fl & 0xff, reserved1=r1, reserved2=r2))
                so += 80
            c["segment"] = seg
            segs.append(seg)
        elif cmd == 0x2:
            c["symoff"], c["nsyms"], c["stroff"], c["strsize"] = struct.unpack_from("<IIII", data, off + 8)
        elif cmd == 0xb:
            names = ["ilocalsym", "nlocalsym", "iextdefsym", "nextdefsym", "iundefsym", "nundefsym",
                     "tocoff", "ntoc", "modtaboff", "nmodtab", "extrefsymoff", "nextrefsyms",
                     "indirectsymoff", "nindirectsyms", "extreloff", "nextrel", "locreloff", "nlocrel"]
            c.update(dict(zip(names, struct.unpack_from("<18I", data, off + 8))))
        elif cmd in (0xc, 0x80000018, 0xe):
            noff = struct.unpack_from("<I", data, off + 8)[0]
            c["path"] = cstr(data[off + noff: off + size])
            if cmd != 0xe:
                ts, cur, compat = struct.unpack_from("<III", data, off + 12)
                c["current_version"] = "%d.%d.%d" % (cur >> 16, (cur >> 8) & 0xff, cur & 0xff)
                dylibs.append(c["path"])
        elif cmd == 0x80000028:
            c["entryoff"], c["stacksize"] = struct.unpack_from("<QQ", data, off + 8)
        elif cmd == 0x1b:
            c["uuid"] = data[off + 8: off + 24].hex()
        elif cmd in (0x26, 0x29, 0x1d, 0x80000034, 0x80000033):
            c["dataoff"], c["datasize"] = struct.unpack_from("<II", data, off + 8)
        elif cmd == 0x32:
            plat, minos, sdk, ntools = struct.unpack_from("<IIII", data, off + 8)
            c.update(platform=plat, minos=hex(minos), sdk=hex(sdk), ntools=ntools)
        cmds.append(c)
        off += size
    assert off == 32 + sizeofcmds, (off, sizeofcmds)
    out["load_commands"] = cmds
    out["dylibs"] = dylibs
    # symbols
    st = next(c for c in cmds if c["cmd"] == 0x2)
    syms = []
    for i in range(st["nsyms"]):
        strx, ntype, sect, desc, value = struct.unpack_from("<IBBHQ", data, st["symoff"] + 16 * i)
        name = cstr(data[st["stroff"] + strx: st["stroff"] + st["strsize"]])
        syms.append(dict(name=name, type=ntype, sect=sect, desc=desc, value=value,
                         ext=bool(ntype & 1), undef=(ntype & 0x0e) == 0))
    out["symbols"] = syms
    # chained fixups
    cf = [c for c in cmds if c["cmd"] == 0x80000034]
    if cf:
        out["fixups"] = parse_fixups(data, cf[0]["dataoff"], segs)
    return out


def vm_to_file(segs, addr):
    for s in segs:
        if s["vmaddr"] <= addr < s["vmaddr"] + s["filesize"]:
            return s["fileoff"] + addr - s["vmaddr"]
    return None


def parse_fixups(data, base, segs):
    (ver, starts_off, imports_off, symbols_off, imports_count, imports_format, symbols_format) = \
        struct.unpack_from("<IIIIIII", data, base)
    res = dict(version=ver, imports_count=imports_count, imports_format=imports_format,
               symbols_format=symbols_format, imports=[], binds=[], rebases=[])
    for i in range(imports_count):
        if imports_format == 1:  # DYLD_CHAINED_IMPORT
            v = struct.unpack_from("<I", data, base + imports_off + 4 * i)[0]
            lib, weak, noff = v & 0xff, (v >> 8) & 1, v >> 9
        else:
            raise ValueError("imports_format %d not handled" % imports_format)
        res["imports"].append(dict(lib_ordinal=lib, weak=weak,
                                   name=cstr(data[base + symbols_off + noff:base + symbols_off + noff + 256])))
    sbase = base + starts_off
    seg_count = struct.unpack_from("<I", data, sbase)[0]
    for si in range(seg_count):
        so = struct.unpack_from("<I", data, sbase + 4 + 4 * si)[0]
        if so == 0:
            continue
        p = sbase + so
        size, page_size, pfmt, seg_offset, maxvalid, page_count = struct.unpack_from("<IHHQIH", data, p)
        res.setdefault("segments", []).append(dict(seg_index=si, segname=segs[si]["segname"],
                                                   page_size=page_size, pointer_format=pfmt,
                                                   page_count=page_count))
        for pg in range(page_count):
            ps = struct.unpack_from("<H", data, p + 22 + 2 * pg)[0]
            if ps == 0xFFFF:
                continue
            assert not (ps & 0x8000), "multi-start pages not handled"
            seg = segs[si]
            foff = seg["fileoff"] + pg * page_size + ps
            assert pfmt in (2, 6), "pointer format %d not handled" % pfmt
            while True:
                v = struct.unpack_from("<Q", data, foff)[0]
                nxt = (v >> 51) & 0xfff
                vm = seg["vmaddr"] + (foff - seg["fileoff"])
                if v >> 63:
                    ordn, addend = v & 0xffffff, (v >> 24) & 0xff
                    res["binds"].append(dict(fileoff=foff, vmaddr=vm, ordinal=ordn, addend=addend,
                                             symbol=res["imports"][ordn]["name"],
                                             lib_ordinal=res["imports"][ordn]["lib_ordinal"]))
                else:
                    target, high8 = v & 0xfffffffff, (v >> 36) & 0xff
                    res["rebases"].append(dict(fileoff=foff, vmaddr=vm, target=target, high8=high8,
                                               fmt=pfmt))
                if nxt == 0:
                    break
                foff += nxt * 4
    return res


def main():
    path = sys.argv[1]
    data = open(path, "rb").read()
    m = parse(data)
    m["file"] = dict(size=len(data), sha256=hashlib.sha256(data).hexdigest())
    if "--json" in sys.argv:
        json.dump(m, open(sys.argv[sys.argv.index("--json") + 1], "w"), indent=1)
    print(json.dumps(m["header"]))
    for c in m["load_commands"]:
        d = {k: v for k, v in c.items() if k != "segment"}
        print("LC", json.dumps(d))
        if "segment" in c:
            s = c["segment"]
            print("  SEG %-12s vm %#x+%#x file %d+%d prot %d/%d nsects %d" % (
                s["segname"], s["vmaddr"], s["vmsize"], s["fileoff"], s["filesize"], s["maxprot"],
                s["initprot"], s["nsects"]))
            for x in s["sections"]:
                print("    SECT %-18s %#x size %d off %d type %d flags %#x r1 %d r2 %d" % (
                    x["sectname"], x["addr"], x["size"], x["offset"], x["type"], x["flags"],
                    x["reserved1"], x["reserved2"]))


if __name__ == "__main__":
    main()
