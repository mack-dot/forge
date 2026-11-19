"""A23: run the ORIGINAL and the PATCHED (model-total C FFI) refund images on the conformance vector corpus
and compare stdout, stderr and exit status byte for byte. FINITE TEST, not a proof. No credential, no gate,
no Dafny, no Node. The corpus generator is taken VERBATIM (ast extraction, no edit) from
scripts/exit_m1_conformance.py; the fixture file is checked against the digest pinned in that script.
Usage: python3 -I diff_conformance.py <original-image> <patched-image> <out.json>
"""
import ast, hashlib, json, os, subprocess, sys
from concurrent.futures import ThreadPoolExecutor

ROOT = '/Users/USER/forge'
SRC = ROOT + '/scripts/exit_m1_conformance.py'
NAMES = {'MAX_MONEY', 'APPROVED_REASONS', 'M1_ENVIRONMENT', 'RECORDED_SHA256', 'RECORDED', 'HOSTILE_TEXTS',
         'HOSTILE_REASONS', 'HUGE', 'atom', 'integer', 'boolean', 'request_atoms', 'request_bytes', 'vector', 'corpus'}


def load_generator():
    text = open(SRC, encoding='utf-8').read()
    tree = ast.parse(text)
    keep = []
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name in NAMES:
            keep.append(node)
        elif isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id in NAMES for t in node.targets):
            keep.append(node)
    ns = {}
    exec(compile(ast.Module(body=keep, type_ignores=[]), SRC, 'exec'), ns)
    assert NAMES <= set(ns), NAMES - set(ns)
    return ns, hashlib.sha256(text.encode()).hexdigest()


def main():
    orig, pat, out = sys.argv[1:4]
    ns, src_sha = load_generator()
    rec_path = ROOT + '/' + ns['RECORDED']
    rec_bytes = open(rec_path, 'rb').read()
    assert hashlib.sha256(rec_bytes).hexdigest() == ns['RECORDED_SHA256'], 'fixture digest'
    typed, wire = ns['corpus'](json.loads(rec_bytes))
    inputs = [(v['id'], ns['request_bytes'](v)) for v in typed] + [(w['id'], w['bytes']) for w in wire]
    # Extra malformed / size cases (not in the repository corpus).
    extra = [('X-random-%d' % i, hashlib.sha256(b'a23-%d' % i).digest() * (1 + i * 37)) for i in range(20)]
    extra += [('X-nul-only', b'\x00' * 5000), ('X-ff-only', b'\xff' * 9000), ('X-open-only', b'(' * 4097),
              ('X-4095', b'(' + b'a' * 4094), ('X-4096', b'(' + b'a' * 4095), ('X-4097', b'(' + b'a' * 4096)]
    inputs += extra
    env = ns['M1_ENVIRONMENT']
    sha = lambda p: hashlib.sha256(open(p, 'rb').read()).hexdigest()
    images = {'orig': orig, 'patched': pat}
    digests_before = {k: sha(p) for k, p in images.items()}

    def one(item):
        key, data = item
        r = {}
        for name, exe in images.items():
            c = subprocess.run([exe], input=data, capture_output=True, env=env, timeout=60)
            r[name] = (c.returncode, c.stdout, c.stderr)
        return key, data, r

    with ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(one, inputs))
    rows, diffs, classes, exits = [], [], {}, {}
    for key, data, r in results:
        (eo, so, xo), (ep, sp, xp) = r['orig'], r['patched']
        same = (eo, so, xo) == (ep, sp, xp)
        cls = 'REJECTED' if so == b'(refund-result-v1 False 0 "" "" "" 0)' else (
            'AUTHORIZED' if so.startswith(b'(refund-result-v1 True ') else ('NO_OUTPUT' if so == b'' else 'OTHER'))
        classes[cls] = classes.get(cls, 0) + 1
        exits[str(eo)] = exits.get(str(eo), 0) + 1
        row = {'id': key, 'stdin_len': len(data), 'stdin_sha256': hashlib.sha256(data).hexdigest(), 'exit': eo,
               'stdout_sha256': hashlib.sha256(so).hexdigest(), 'stderr_sha256': hashlib.sha256(xo).hexdigest(),
               'class': cls, 'identical': same}
        if not same:
            row['patched'] = {'exit': ep, 'stdout_sha256': hashlib.sha256(sp).hexdigest(),
                              'stderr_sha256': hashlib.sha256(xp).hexdigest()}
            diffs.append(key)
        rows.append(row)
    res = {'class': 'TESTED-UNPROVED (finite test)', 'generator_source': SRC, 'generator_source_sha256': src_sha,
           'fixture_sha256': ns['RECORDED_SHA256'], 'images': images, 'image_sha256_before': digests_before,
           'image_sha256_after': {k: sha(p) for k, p in images.items()}, 'environment': env,
           'vectors': len(rows), 'typed': len(typed), 'wire': len(wire), 'extra': len(extra),
           'identical': len(rows) - len(diffs), 'differences': diffs, 'orig_classes': classes, 'orig_exits': exits,
           'rows': rows}
    json.dump(res, open(out, 'w'), indent=1)
    print(json.dumps({k: res[k] for k in ('vectors', 'typed', 'wire', 'extra', 'identical', 'differences',
                                          'orig_classes', 'orig_exits', 'image_sha256_before')}))
    return 0 if not diffs else 1


if __name__ == '__main__':
    sys.exit(main())
