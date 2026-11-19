#!/usr/bin/env python3 -I
"""Draft verifier of the Forge refund-slice BINDING manifest (worker Z8, M1-B mission, 2026-11-19). DRAFT.

Extends drafts/manifest/verify_m1_manifest.py (W5). That verifier asks "is M1-A or M1-B supported". This one asks,
for the refund slice: which exact files are bound to which graph link, at which evidence class, and which links
have NO binding. Standard library only. No network. It never runs Dafny, HOL, Node or a build. It checks identity
(SHA-256 of bytes on disk) and record consistency only. It does NOT re-run any proof.

The class of every link is COMPUTED here from the record kinds (fixed in this file). The manifest only STATES a
class; a stated class above the computed one is a refusal.

Exit 0: every identity check passed, every record is consistent, every stated class equals a computed class.
Exit 1: refused (reasons printed).  Exit 2: crash (never a pass).
"""
import argparse
import ast
import hashlib
import json
import posixpath
import re
import subprocess
import sys
from pathlib import Path

FORMAT = 'forge.m1b.refund-binding-manifest/1'
HEX64 = re.compile(r'^[0-9a-f]{64}$')
LEVEL_KEYS = re.compile(r'(level|verdict|achieved|computed|verified_class|m1_status|closed)', re.I)
RANK = {'UNBOUND': 0, 'REPORTED_ONLY': 0, 'ASSUMPTION': 1, 'TEST': 2, 'MODEL': 3, 'SOURCE_PROOF': 3}
# The links of TOP_LEVEL_GRAPH.md sections 2 and 7 (U5 split into U5a, U5b; X11e added in section 7).
REQUIRED_LINKS = (['S%d' % i for i in range(1, 9)] + ['S3a'] + ['X%d' % i for i in range(1, 17)] + ['X11e']
                  + ['U1', 'U2', 'U3', 'U4', 'U5a', 'U5b', 'U6', 'U7', 'U8'] + ['V%d' % i for i in range(1, 8)]
                  + ['E%d' % i for i in range(1, 6)])
REQUIRED_PROOFS = {'S3-linked-refund', 'S3a-linked-refund-no-hex', 'U5a-sink-core'}
REQUIRED_UNBOUND = {'c-runtime-ranges', 'got-binds', 'sink.ts', 'minter.ts', 'compiled-js-core', 'node', 'sqlite'}
TOP = {'manifest_format', 'subject', 'end_to_end', 'notes', 'reference_values_pinned_by', 'toolchain', 'dafny_proofs',
       'recorded_runs', 'executable', 'export', 'assumptions', 'reported', 'unbound', 'claims'}
# record kind -> class it can support (fixed here, never read from the manifest)
KIND_CLASS = {'run_check_result': 'SOURCE_PROOF', 'w9_attempt': 'SOURCE_PROOF', 'y10_run': 'SOURCE_PROOF',
              'y7_result': 'SOURCE_PROOF', 'slice1_dafny_verify': 'SOURCE_PROOF', 'slice1_refund_gate': 'SOURCE_PROOF',
              'f20_summary': 'MODEL', 'hol_case': 'MODEL', 'm1r1_command': 'MODEL', 'u294_command': 'MODEL',
              'slice1_suite': 'TEST', 'conformance': 'TEST', 'y9_extract_result': 'TEST'}


def sha(b):
    return hashlib.sha256(b).hexdigest()


class V:
    def __init__(self, root, scratch, tc, git_tree):
        self.root, self.scratch, self.tc, self.git_tree = root, scratch, tc, git_tree
        self.reasons, self.notes, self.storage_cache = [], [], {}

    def no(self, code, text):
        self.reasons.append(f'{code}: {text}')

    def note(self, text):
        self.notes.append(text)

    # ---------- locators ----------
    def base(self, loc):
        if not isinstance(loc, dict) or len(loc) != 1:
            return None, None
        kind, val = next(iter(loc.items()))
        base = {'repo': self.root, 'scratch': self.scratch, 'toolchain': self.tc}.get(kind)
        if base is None or not isinstance(val, str) or val.startswith('/') or '..' in Path(val).parts:
            return None, None
        return base, val

    def path(self, loc, where):
        base, val = self.base(loc)
        if base is None:
            self.no('BAD_LOCATOR', f'{where}: {loc}')
            return None
        p = base / val
        if p.is_symlink():
            self.no('SYMLINK', f'{where}: {val} is a symbolic link')
            return None
        return p

    def read(self, loc, where):
        p = self.path(loc, where)
        if p is None:
            return None
        if not p.is_file():
            self.no('MISSING_FILE', f'{where}: {next(iter(loc.values()))}')
            return None
        return p.read_bytes()

    def pinned(self, obj, where):
        if not (isinstance(obj, dict) and set(obj) == {'locator', 'sha256'}):
            self.no('MISSING_EVIDENCE', f'{where} is not a pinned {{locator, sha256}} pair')
            return None
        if not isinstance(obj['sha256'], str) or not HEX64.match(obj['sha256']):
            self.no('BAD_DIGEST', where)
            return None
        data = self.read(obj['locator'], where)
        if data is None:
            return None
        if sha(data) != obj['sha256']:
            self.no('DIGEST_MISMATCH', f'{where}: file {sha(data)[:16]}… manifest {obj["sha256"][:16]}…')
            return None
        return data

    def storage(self, loc):
        """Where a record lives: tracked in git, untracked or ignored in the work tree, scratch, toolchain."""
        kind, val = next(iter(loc.items()))
        if kind != 'repo':
            return kind
        if val in self.storage_cache:
            return self.storage_cache[val]
        g = ['git', '-C', str(self.git_tree)]
        r = subprocess.run(g + ['ls-files', '--error-unmatch', '--', val], capture_output=True)
        if r.returncode == 0:
            out = 'tracked'
        else:
            r = subprocess.run(g + ['check-ignore', '-q', '--', val], capture_output=True)
            out = 'ignored' if r.returncode == 0 else 'untracked'
        self.storage_cache[val] = out
        return out

    def keys(self, obj, want, where, optional=()):
        if not isinstance(obj, dict):
            self.no('MISSING_FIELD', f'{where} is not an object')
            return False
        ok = True
        for k in sorted(set(want) - set(obj)):
            self.no('MISSING_FIELD', f'{where}.{k}')
            ok = False
        for k in sorted(set(obj) - set(want) - set(optional)):
            self.no('PRODUCER_STATED_LEVEL' if LEVEL_KEYS.search(k) else 'UNKNOWN_FIELD', f'{where}.{k}')
            ok = False
        return ok


# ---------- digests over sets of files ----------
def set_digest(pairs):
    """Digest over the sorted list of (path, sha256): one line 'path<TAB>sha256<LF>' per file."""
    return sha(''.join(f'{p}\t{h}\n' for p, h in sorted(pairs)).encode())


def tree_files(v, top, where):
    out = {}
    for p in sorted(top.rglob('*')):
        rel = p.relative_to(top).as_posix()
        if p.is_symlink():
            out[rel] = 'symlink:' + str(p.readlink())
        elif p.is_file():
            out[rel] = sha(p.read_bytes())
    return out


INCLUDE = re.compile(r'^\s*include\s+"([^"]+)"', re.M)


def include_closure(v, root, entries, where):
    seen, stack = {}, list(entries)
    while stack:
        rel = stack.pop()
        if rel in seen:
            continue
        p = root / rel
        if not p.is_file() or p.is_symlink():
            v.no('MISSING_FILE', f'{where}: included file {rel}')
            seen[rel] = None
            continue
        data = p.read_bytes()
        seen[rel] = sha(data)
        for inc in INCLUDE.findall(data.decode('utf-8', 'replace')):
            nxt = posixpath.normpath(posixpath.join(posixpath.dirname(rel), inc))
            if nxt.startswith('../') or nxt.startswith('/'):
                v.no('CLOSURE_ESCAPE', f'{where}: {rel} includes {inc} outside the root')
                continue
            stack.append(nxt)
    return seen


def compare_sets(v, code_where, want_list, got):
    want = {x['path']: x['sha256'] for x in want_list}
    for p in sorted(set(got) - set(want)):
        v.no('EXTRA_FILE', f'{code_where}: {p} is on disk / reached but not in the manifest')
    for p in sorted(set(want) - set(got)):
        v.no('MISSING_FILE', f'{code_where}: {p} is in the manifest but not on disk / not reached')
    for p in sorted(set(want) & set(got)):
        if want[p] != got[p]:
            v.no('DIGEST_MISMATCH', f'{code_where}: {p}: file {str(got[p])[:16]}… manifest {want[p][:16]}…')


def gate_options(src):
    for node in ast.walk(ast.parse(src)):
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == 'OPTIONS' for t in node.targets):
            return ast.literal_eval(node.value)
    return None


def runner_dict(src, name):
    for node in ast.walk(ast.parse(src)):
        if isinstance(node, ast.Assign) and any(isinstance(t, ast.Name) and t.id == name for t in node.targets):
            if isinstance(node.value, ast.Dict):
                return [ast.literal_eval(k) for k in node.value.keys]
    return None


def apply_normal_diff(old, diff):
    """Apply a classic (non-unified) `diff` output with a/c/d commands. Returns bytes or None."""
    lines, out, pos = old.decode('utf-8').split('\n'), [], 0
    cmds = diff.decode('utf-8').split('\n')
    i = 0
    hunk = re.compile(r'^(\d+)(?:,(\d+))?([acd])(\d+)(?:,(\d+))?$')
    while i < len(cmds):
        m = hunk.match(cmds[i])
        if not m:
            if cmds[i] == '':
                i += 1
                continue
            return None
        a1, a2, op = int(m.group(1)), int(m.group(2) or m.group(1)), m.group(3)
        i += 1
        removed, added = [], []
        while i < len(cmds) and (cmds[i].startswith('< ') or cmds[i] == '<' or cmds[i] == '---'
                                 or cmds[i].startswith('> ') or cmds[i] == '>'):
            if cmds[i].startswith('<'):
                removed.append(cmds[i][2:])
            elif cmds[i].startswith('>'):
                added.append(cmds[i][2:])
            i += 1
        start = a1 if op == 'a' else a1 - 1
        out += lines[pos:start]
        if op in 'cd':
            if lines[start:a2] != removed:
                return None
            pos = a2
        else:
            pos = start
        out += added
    out += lines[pos:]
    return '\n'.join(out).encode('utf-8')


# ---------- record kinds: facts extracted by code fixed here ----------
def lines_of(b):
    return b.decode('utf-8', 'replace').split('\n')


def has_thm(lines, t):
    return any(l.split(' ', 2)[:2] in (['CHECKED', t], ['FORGE_THEOREM', t]) for l in lines)


def summary_of(b):
    s = [l.strip() for l in lines_of(b) if l.strip().startswith('Dafny program verifier finished')]
    return s[-1] if s else None


def sha_lines(b, prefix=''):
    """Lines '<sha256>  <path>': returns {path relative to `prefix` (if it contains it): sha}."""
    out = {}
    for l in lines_of(b):
        m = re.match(r'^([0-9a-f]{64})\s+(\S.*)$', l.strip())
        if m:
            p = m.group(2)
            if prefix and prefix in p:
                p = p.split(prefix, 1)[1]
            out[p] = m.group(1)
    return out


def facts(v, rec, entry, m, where):
    """Read the pinned record files of one run and return facts: exit, summary, files {rel: sha}, controls, extra."""
    kind = rec.get('record_kind')
    if kind not in KIND_CLASS:
        v.no('UNKNOWN_RECORD_KIND', f'{where}: {kind}')
        return None
    files = {}
    for name, obj in rec.get('files', {}).items():
        files[name] = v.pinned(obj, f'{where}.files.{name}')
    if any(b is None for b in files.values()) or not files:
        return None
    f = {'exit': None, 'summary': None, 'files': {}, 'controls': {}, 'theorems_ok': None, 'kind': kind}
    try:
        if kind == 'run_check_result':
            d = json.loads(files['result'])
            copies = {c['approved']['repo']: c['copy'] for c in entry.get('approved_copies', [])}
            for r in d['rows']:
                c = r['check']
                if c == 'proof file SHA-256':
                    f['files'][entry['entries'][0]] = r['actual']
                elif c.startswith('flat contract file SHA-256'):
                    f['files']['transport/FlatCore.dfy'] = r['actual']
                elif c.startswith('copy equals '):
                    f['files'][copies.get(c[len('copy equals '):], '?' + c)] = r['actual']
                elif c == 'verify LinkedRefund.dfy (exit)':
                    f['exit'] = r['actual']
                elif c == 'verify LinkedRefund.dfy (summary)':
                    f['summary'] = r['actual']
                elif c.startswith('control ') and c.endswith(' (exit)'):
                    f['controls'][c[8:-7]] = r['actual']
            f['all_as_expected'] = d.get('all_as_expected')
            if 'log' in files and lines_of(files['log'])[-2:] != ['exit %d' % (0 if d.get('all_as_expected') else 1), '']:
                v.no('RECORD_INCONSISTENT', f'{where}: the stored log does not end with the exit of the result file')
        elif kind == 'w9_attempt':
            env = {l.split(':', 1)[0]: l.split(':', 1)[1].strip() for l in lines_of(files['env']) if ':' in l}
            f['exit'] = int(env['exit'])
            f['summary'] = summary_of(files['output'])
            f['files'].update(sha_lines(files['sha'], '/proof/inputs/'))
            if 'closure_list' in files:
                f['files'].update(sha_lines(files['closure_list']))
            f['command'] = files['command'].decode()
        elif kind == 'y10_run':
            m_ = re.match(r'exit=(\d+)', files['exit'].decode().strip())
            f['exit'] = int(m_.group(1)) if m_ else None
            f['summary'] = summary_of(files['out'])
            f['files'].update(sha_lines(files['sha'], '/inputs/'))
            f['command'] = files['command'].decode()
        elif kind == 'y7_result':
            rows = json.loads(files['result'])
            for r in rows:
                c = r['check']
                if c == 'SinkCore.dfy sha256':
                    f['files']['sink/SinkCore.dfy'] = r['value']
                elif c.startswith('copy '):
                    f['files'][c[5:]] = r['copy_sha256']
                elif c == 'verify SinkCore.dfy':
                    f['exit'], f['summary'] = r['exit'], r['summary']
                elif c.startswith('control '):
                    f['controls'][c[8:]] = r['exit']
            log = lines_of(files['log'])
            if 'EXIT %s' % f['exit'] not in log or summary_of(files['log']) != f['summary']:
                v.no('RECORD_INCONSISTENT', f'{where}: main.log and result-all.json disagree')
        elif kind in ('slice1_dafny_verify', 'slice1_refund_gate', 'slice1_suite'):
            d = json.loads(files['evidence'])
            sm = {x['path']: x['sha256'] for x in d['source_manifest']}
            sm.update(d['approved_inputs_sha256'])
            f['files'] = sm
            part = {'slice1_dafny_verify': d['source_proof']['verify'], 'slice1_refund_gate': d['source_proof']['refund_gate'],
                    'slice1_suite': d['sink_controls']}[kind]
            f['exit'] = part['exit_code']
            if kind == 'slice1_suite' and part['report']['counts'].get('failed') != 0:
                v.no('RECORD_NOT_PASSING', f'{where}: suite reports failed rows')
        elif kind == 'conformance':
            d = json.loads(files['evidence'])
            f['files'] = {x['path']: x['sha256'] for x in d['source_manifest']}
            f['exit'] = 0 if d['conformance'].get('findings') == 0 else 1
        elif kind == 'f20_summary':
            d = json.loads(files['summary'])
            for c in d['cases']:
                if c['name'] == rec['case']:
                    f['exit'], f['summary'] = c['checker_exit'], c['last_line']
                    f['files'][c['file']] = c['file_sha256']
                else:
                    f['controls'][c['name']] = c['checker_exit'] if c['result'] == 'PASS' else 'FAILED'
        elif kind == 'hol_case':
            d = json.loads(files['command'])
            f['exit'] = d['actual_exit']
            if d.get('stdout_sha256') != sha(files['stdout']):
                v.no('RECORD_INCONSISTENT', f'{where}: command.json stdout_sha256 differs from the stored stdout.log')
            f['theorems_ok'] = all(has_thm(lines_of(files['stdout']), t) for t in rec['theorems'])
        elif kind == 'm1r1_command':
            d = json.loads(files['commands'])
            hit = [c for c in d['commands'] if c['label'] == rec['label']]
            if len(hit) != 1 or hit[0]['status'] != 'FINISHED':
                v.no('RECORD_INCONSISTENT', f'{where}: label {rec["label"]} not exactly once FINISHED')
                return None
            f['exit'] = hit[0]['actual_exit']
            man = json.loads(files['replay_manifest'])['files']
            loc = next(iter(rec['files']['log']['locator'].values()))
            key = loc.split('m1-chain-replay-20261118/', 1)[1]
            if man.get(key, {}).get('sha256') != sha(files['log']):
                v.no('RECORD_INCONSISTENT', f'{where}: log digest differs from the replay MANIFEST.json')
            text = lines_of(files['log'])
            f['theorems_ok'] = all(has_thm(text, t) for t in rec['theorems'])
        elif kind == 'u294_command':
            d = json.loads(files['command'])
            f['exit'] = d['actual_exit']
            f['input_sha256'] = d['input_sha256']
            f['theorems_ok'] = all(has_thm(lines_of(files['stdout']), t) for t in rec['theorems'])
        elif kind == 'y9_extract_result':
            d = json.loads(files['result'])
            f['exit'] = 0 if d.get('ALL_EQUAL') is True else 1
            f['extract'] = d
            f['no_exit_code_stored'] = True
    except (KeyError, ValueError, TypeError, IndexError, AttributeError) as e:
        v.no('RECORD_UNREADABLE', f'{where}: {type(e).__name__} {e}')
        return None
    return f


# ---------- sections ----------
def check_toolchain(v, m):
    t = m['toolchain']
    if not v.keys(t, {'dafny_tree', 'dafny_tree_digest', 'dafny_tree_files', 'dafny', 'z3', 'gate_options_source',
                      'version'}, 'toolchain'):
        return None
    top = v.path(t['dafny_tree'], 'toolchain.dafny_tree')
    if top is None or not top.is_dir():
        v.no('MISSING_FILE', 'toolchain.dafny_tree')
        return None
    files = tree_files(v, top, 'toolchain')
    if len(files) != t['dafny_tree_files'] or set_digest(files.items()) != t['dafny_tree_digest']:
        v.no('TOOL_MISMATCH', f'Dafny tree: {len(files)} files, digest {set_digest(files.items())[:16]}…')
    for k in ('dafny', 'z3'):
        v.pinned(t[k], f'toolchain.{k}')
        inside = next(iter(t[k]['locator'].values()))
        if not inside.startswith(next(iter(t['dafny_tree'].values())) + '/'):
            v.no('TOOL_OUTSIDE_TREE', f'toolchain.{k} is not inside the pinned tree')
    src = v.pinned(t['gate_options_source'], 'toolchain.gate_options_source')
    opts = gate_options(src.decode()) if src else None
    if opts is None:
        v.no('TOOL_MISMATCH', 'gate OPTIONS not readable from the pinned gate file')
        return None
    z3 = next(iter(t['z3']['locator'].values()))
    i = opts.index('--solver-path') if '--solver-path' in opts else -1
    if i < 0 or opts[i + 1] != z3:
        v.no('TOOL_MISMATCH', 'the gate solver path is not the pinned Z3')
        return None
    return ['{dafny}', 'verify'], [('{z3}' if j == i + 1 else o) for j, o in enumerate(opts)]


def check_proof(v, p, m, argv_parts, proofs_by_id):
    where = 'dafny_proofs.' + str(p.get('id'))
    want = {'id', 'kind', 'root', 'entries', 'include_closure', 'include_closure_digest', 'folder_files',
            'folder_digest', 'pins', 'argv', 'expected_exit', 'expected_summary', 'controls', 'runs', 'runner'}
    if not v.keys(p, want, where, optional={'approved_copies', 'derived_from', 'note'}):
        return None
    n0 = len(v.reasons)
    root = v.path(p['root'], where + '.root')
    if root is None or not root.is_dir():
        v.no('MISSING_FILE', where + '.root')
        return None
    reached = include_closure(v, root, p['entries'], where)
    compare_sets(v, where + '.include_closure', p['include_closure'], reached)
    if set_digest((x['path'], x['sha256']) for x in p['include_closure']) != p['include_closure_digest']:
        v.no('CLOSURE_DIGEST', f'{where}: include_closure_digest is not the digest of the listed pairs')
    folder = tree_files(v, root, where)
    compare_sets(v, where + '.folder_files', p['folder_files'], folder)
    if set_digest((x['path'], x['sha256']) for x in p['folder_files']) != p['folder_digest']:
        v.no('CLOSURE_DIGEST', f'{where}: folder_digest is not the digest of the listed pairs')
    for pin in p['pins']:
        if reached.get(pin['path']) != pin['sha256']:
            v.no('DIGEST_MISMATCH', f'{where}: pinned file {pin["path"]} ({pin.get("why", "")})')
    for c in p.get('approved_copies', []):
        data = v.read(c['approved'], where + '.approved_copies')
        if data is not None and sha(data) != reached.get(c['copy']):
            v.no('COPY_NOT_APPROVED', f'{where}: {c["copy"]} differs from {c["approved"]}')
    if argv_parts and p['argv'] != argv_parts[0] + p['entries'] + argv_parts[1]:
        v.no('ARGV_MISMATCH', f'{where}: argv is not the gate verify command for {p["entries"]}')
    n1 = len(v.reasons)  # identity of the closure, pins, copies, argv checked up to here
    runner = v.pinned(p['runner']['file'], where + '.runner') if p['runner'] else None
    if runner is not None:
        names = runner_dict(runner.decode(), p['runner']['controls_name'])
        if names is None or sorted(names) != sorted(c['name'] for c in p['controls']):
            v.no('CONTROL_SET', f'{where}: the manifest controls differ from the runner {p["runner"]["controls_name"]}')
        lits = set(re.findall(r"'([0-9a-f]{64})'", runner.decode()))
        if not lits <= {x['sha256'] for x in p['pins']}:
            v.no('RUNNER_PIN', f'{where}: the runner pins digests that the manifest does not pin')
    for c in p['controls']:
        cw = f'{where}.controls.{c.get("name")}'
        if c.get('diff') is not None:
            v.pinned(c['diff'], cw)
        elif c.get('mutant') is not None:
            data = v.pinned(c['mutant']['file'], cw)
            if data is not None and sha(data) == reached.get(c['mutant']['replaces']):
                v.no('CONTROL_NOT_A_MUTANT', cw)
        else:
            v.no('MISSING_EVIDENCE', cw + ' has neither diff nor mutant')
        if not isinstance(c.get('expected_exit'), int):
            v.no('MISSING_FIELD', cw + '.expected_exit')
    if p.get('derived_from'):
        d = p['derived_from']
        base = proofs_by_id.get(d['proof'])
        diff = v.pinned(d['diff'], where + '.derived_from.diff')
        if base is None or diff is None:
            v.no('DERIVATION', f'{where}: base proof or diff missing')
        else:
            bp = v.path(base['root'], where + '.derived_from')
            old = (bp / d['target']).read_bytes() if bp and (bp / d['target']).is_file() else None
            new = apply_normal_diff(old, diff) if old is not None else None
            mine = (root / d['target']).read_bytes() if (root / d['target']).is_file() else None
            if new is None or mine is None or sha(new) != sha(mine):
                v.no('DERIVATION', f'{where}: {d["target"]} is not the base file with the stored diff applied')
            other = {x['path']: x['sha256'] for x in base['folder_files'] if x['path'] != d['target']}
            if {k: h for k, h in folder.items() if k != d['target']} != other:
                v.no('DERIVATION', f'{where}: files other than {d["target"]} differ from the base proof')
    if n1 > n0:  # the bytes on disk are not the manifest's bytes: no record can be judged against them
        return {'class': None, 'runs': []}
    runs = []
    for i, r in enumerate(p['runs']):
        rw = f'{where}.runs[{i}]'
        f = facts(v, r, p, m, rw)
        if f is None:
            continue
        bad = []
        if f['exit'] != p['expected_exit']:
            bad.append(f'exit {f["exit"]}, expected {p["expected_exit"]}')
        if f['summary'] != p['expected_summary']:
            bad.append(f'summary "{f["summary"]}"')
        for rel, h in f['files'].items():
            if reached.get(rel) != h:
                bad.append(f'{rel} at run time {str(h)[:12]}… now {str(reached.get(rel))[:12]}…')
        if p['entries'][0] not in f['files']:
            bad.append('the record does not name the digest of the entry file')
        for c in p['controls']:
            if c['name'] in f['controls'] and f['controls'][c['name']] != c['expected_exit']:
                bad.append(f'control {c["name"]} exit {f["controls"][c["name"]]}')
        if 'command' in f and not all(tok in f['command'] for tok in p['argv'][1:] if not tok.startswith('{')):
            bad.append('the stored command lacks a token of the manifest argv')
        if bad:
            v.no('STALE_RECORD', f'{rw} ({r["record_kind"]}): ' + '; '.join(bad))
            continue
        bound = sum(1 for x in p['include_closure'] if x['path'] in f['files'])
        ctl = sum(1 for c in p['controls'] if c['name'] in f['controls'])
        store = sorted({v.storage(o['locator']) for o in r['files'].values()})
        runs.append({'kind': r['record_kind'], 'by': r.get('by'), 'storage': store,
                     'binding': f'{bound}/{len(p["include_closure"])} closure files named by the record',
                     'controls': f'{ctl}/{len(p["controls"])} control exits recorded'})
    if len(v.reasons) > n1:
        return {'class': None, 'runs': runs}
    cls = ('SOURCE_PROOF' if p['kind'] == 'source' else 'MODEL') if runs else 'REPORTED_ONLY'
    return {'class': cls, 'runs': runs}


def check_run(v, r, m):
    where = 'recorded_runs.' + str(r.get('id'))
    if not v.keys(r, {'id', 'record_kind', 'files', 'by'}, where,
                  optional={'bound_files', 'theorems', 'label', 'case', 'note'}):
        return None
    f = facts(v, r, None, m, where)
    if f is None:
        return {'class': None}
    bad = []
    if f['exit'] != 0:
        bad.append(f'exit {f["exit"]}')
    if f['theorems_ok'] is False:
        bad.append('a named theorem is not in the log')
    if r['record_kind'] == 'u294_command' and f['input_sha256'] != m['export']['output']['sha256']:
        bad.append('the HOL import read other bytes than the pinned export')
    if r['record_kind'] == 'y9_extract_result':
        e, x = f['extract'], m['executable']
        sl = {s['name']: s for s in x['slices']}
        if e['file']['sha256'] != x['file']['sha256'] or any(e[k]['sha256'] != sl[k]['sha256'] or e[k]['offset'] != sl[k]['offset']
                                                           for k in ('code', 'bitmaps')):
            bad.append('the extraction result names other bytes')
    for b in r.get('bound_files', []):
        data = v.pinned(b, where + '.bound_files')
        rel = next(iter(b['locator'].values()))
        if data is not None and f['files'].get(rel) != sha(data):
            bad.append(f'{rel}: the record names {str(f["files"].get(rel))[:12]}…, the file is {sha(data)[:12]}…')
    if bad:
        v.no('STALE_RECORD', f'{where} ({r["record_kind"]}): ' + '; '.join(bad))
        return {'class': None}
    store = sorted({v.storage(o['locator']) for o in r['files'].values()})
    extra = ' (no exit code stored; a pass flag only)' if f.get('no_exit_code_stored') else ''
    return {'class': KIND_CLASS[r['record_kind']], 'runs': [{'kind': r['record_kind'], 'by': r['by'], 'storage': store,
            'binding': f'{len(r.get("bound_files", []))} bound files re-hashed' + extra}]}


def check_executable(v, m):
    x = m['executable']
    if not v.keys(x, {'file', 'size', 'slices', 'symbol_parser', 'outside_slices'}, 'executable'):
        return None
    # whole-file hash first, as its own check; the slices are checked on the same bytes even if it fails,
    # so that a change inside a slice is reported by the slice check too (not hidden by the first refusal)
    data = v.read(x['file'].get('locator'), 'executable.file') if isinstance(x['file'], dict) else None
    if data is not None and sha(data) != x['file'].get('sha256'):
        v.no('WHOLE_FILE_DIGEST', f'executable.file: file {sha(data)[:16]}… manifest {str(x["file"].get("sha256"))[:16]}…')
    parser = v.pinned(x['symbol_parser'], 'executable.symbol_parser')
    if data is None:
        return None
    if len(data) != x['size']:
        v.no('ARTIFACT_SIZE', f'{len(data)} bytes, manifest {x["size"]}')
    names = sorted(s['name'] for s in x['slices'])
    if names != ['bitmaps', 'code']:
        v.no('ARTIFACT_SLICES', f'slices {names}')
        return None
    for s in x['slices']:
        o, n = s['offset'], s['length']
        if not (isinstance(o, int) and isinstance(n, int) and 0 <= o and n > 0 and o + n <= len(data)):
            v.no('ARTIFACT_SLICES', f'{s["name"]}: bad range')
        elif sha(data[o:o + n]) != s['sha256']:
            v.no('SLICE_DIGEST', f'{s["name"]}: slice digest {sha(data[o:o + n])[:16]}… manifest {s["sha256"][:16]}…')
    if parser is not None:  # offsets derived from the file's own symbols, by the pinned parser (loaded from the hashed bytes)
        ns = {'__name__': 'y9_macho_pinned'}
        try:
            exec(compile(parser, 'y9_macho.py(pinned)', 'exec'), ns)
            mo = ns['parse'](data)
            segs = [c['segment'] for c in mo['load_commands'] if 'segment' in c]
            for s in x['slices']:
                lo, hi = [[y['value'] for y in mo['symbols'] if y['name'] == nm and not y['undef']] for nm in s['symbols']]
                if len(lo) != 1 or len(hi) != 1:
                    v.no('SYMBOL_OFFSETS', f'{s["name"]}: symbols {s["symbols"]} not exactly once')
                    continue
                if (ns['vm_to_file'](segs, lo[0]), hi[0] - lo[0]) != (s['offset'], s['length']):
                    v.no('SYMBOL_OFFSETS', f'{s["name"]}: symbol-derived range differs from the manifest')
        except Exception as e:  # noqa: BLE001  a parse failure is a refusal, not a pass
            v.no('SYMBOL_OFFSETS', f'symbol parse failed: {type(e).__name__} {e}')
    cut = sorted((s['offset'], s['offset'] + s['length']) for s in x['slices'])
    rest, pos = [], 0
    for a, b in cut:
        rest.append([pos, a])
        pos = b
    rest.append([pos, len(data)])
    if rest != x['outside_slices']:
        v.no('OUTSIDE_RANGES', f'computed {rest}, manifest {x["outside_slices"]}')
    return rest


def check_export(v, m):
    e = m['export']
    if not v.keys(e, {'source', 'export_input', 'output', 'size', 'export_record'}, 'export', optional={'note'}):
        return None
    src = v.pinned(e['source'], 'export.source')
    inp = v.pinned(e['export_input'], 'export.export_input')
    out = v.pinned(e['output'], 'export.output')
    rec = v.pinned(e['export_record'], 'export.export_record')
    if None in (src, inp, out, rec):
        return None
    d = json.loads(rec)
    bad = []
    if sha(src) != sha(inp):
        bad.append('the export input is not byte-equal to the proof closure file')
    if d.get('input_sha256') != sha(src) or d.get('output_sha256') != sha(out) or d.get('actual_exit') != 0:
        bad.append('the export record names other bytes or a non-zero exit')
    if len(out) != e['size']:
        bad.append(f'export size {len(out)}')
    if bad:
        v.no('EXPORT_BINDING', '; '.join(bad))
        return None
    return {'class': 'TEST', 'runs': [{'kind': 'export byte equality', 'by': 'this verifier, now',
                                       'storage': sorted({v.storage(e[k]['locator']) for k in ('export_input', 'output', 'export_record')}),
                                       'binding': 'source = export input; record exit 0; output digest; the exporter itself is NOT bound'}]}


def check_unbound(v, m, rest):
    ids = [u.get('id') for u in m['unbound']]
    for r in sorted(REQUIRED_UNBOUND - set(ids)):
        v.no('MISSING_REQUIRED_ENTRY', f'unbound.{r}')
    cut = [(s['offset'], s['offset'] + s['length']) for s in m['executable']['slices']]
    for u in m['unbound']:
        w = 'unbound.' + str(u.get('id'))
        if not v.keys(u, {'id', 'what', 'why'}, w, optional={'ranges', 'file', 'recorded_sha256', 'system_path', 'note'}):
            continue
        for a, b in u.get('ranges', []):
            if any(a < hi and lo < b for lo, hi in cut) or b > m['executable']['size']:
                v.no('UNBOUND_RANGE', f'{w}: [{a}, {b}) overlaps a bound slice or leaves the file')
        if 'file' in u:
            v.pinned(u['file'], w)
        if 'system_path' in u:
            p = Path(u['system_path'])
            if not p.is_file() or sha(p.read_bytes()) != u.get('recorded_sha256'):
                v.no('UNBOUND_IDENTITY', f'{w}: {p} differs from the recorded digest')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--root', required=True, help='repository folder (repo locators)')
    ap.add_argument('--scratch-root', required=True, help='scratch folder (scratch locators)')
    ap.add_argument('--toolchain-root', help='folder for toolchain locators (default: --root)')
    ap.add_argument('--git-tree', help='git work tree used only to classify storage (default: --root)')
    o = ap.parse_args()
    root = Path(o.root).resolve()
    v = V(root, Path(o.scratch_root).resolve(), Path(o.toolchain_root or o.root).resolve(), Path(o.git_tree or o.root).resolve())
    try:
        m = json.loads(Path(o.manifest).read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        print(f'REFUSED\n  MANIFEST_UNREADABLE: {e}\nproofs NOT re-run')
        return 1
    if not v.keys(m, TOP, ''):
        return report(v, m, {})
    if m['manifest_format'] != FORMAT:
        v.no('FORMAT', str(m['manifest_format']))
    if m['end_to_end'] is not False:
        v.no('END_TO_END', 'end_to_end must be false')
    ev = {}
    argv_parts = check_toolchain(v, m)
    proofs = {p.get('id'): p for p in m['dafny_proofs']}
    for r in sorted(REQUIRED_PROOFS - set(proofs)):
        v.no('MISSING_REQUIRED_ENTRY', f'dafny_proofs.{r}')
    for pid, p in proofs.items():
        ev[pid] = check_proof(v, p, m, argv_parts, proofs)
    for r in m['recorded_runs']:
        ev[r.get('id')] = check_run(v, r, m)
    n0 = len(v.reasons)
    rest = check_executable(v, m)
    ev['executable'] = {'class': 'IDENTITY'} if rest is not None and len(v.reasons) == n0 else {'class': None}
    ev['export'] = check_export(v, m) or {'class': None}
    for a in m['assumptions']:
        w = 'assumptions.' + str(a.get('id'))
        if v.keys(a, {'id', 'text', 'approved'}, w, optional={'decision', 'marker'}):
            if a['approved']:
                data = v.pinned(a.get('decision'), w + '.decision')
                if data is not None and a.get('marker', '\0') not in data.decode('utf-8', 'replace'):
                    v.no('DECISION_MARKER', f'{w}: marker {a.get("marker")} not in the decision record')
            ev[a['id']] = {'class': 'ASSUMPTION', 'runs': [{'kind': 'approved assumption' if a['approved'] else 'NOT approved',
                                                            'by': 'owner' if a['approved'] else 'nobody', 'storage': [], 'binding': a['text']}]}
    for r in m['reported']:
        w = 'reported.' + str(r.get('id'))
        if v.keys(r, {'id', 'file', 'quote'}, w):
            data = v.pinned(r['file'], w)
            if data is not None and r['quote'] not in data.decode('utf-8', 'replace'):
                v.no('QUOTE_NOT_FOUND', w)
            ev[r['id']] = {'class': 'REPORTED_ONLY', 'runs': [{'kind': 'a sentence in a report; no stored log', 'by': '-',
                                                               'storage': [v.storage(r['file']['locator'])], 'binding': r['quote'][:80]}]}
    if rest is not None:
        check_unbound(v, m, rest)
    for u in m['unbound']:
        ev['unbound:' + str(u.get('id'))] = {'class': 'UNBOUND', 'runs': []}
    return report(v, m, ev)


def report(v, m, ev):
    rows = []
    claims = m.get('claims') if isinstance(m.get('claims'), list) else []
    links = [c.get('link') for c in claims]
    for L in REQUIRED_LINKS:
        if links.count(L) != 1:
            v.no('MISSING_REQUIRED_ENTRY' if links.count(L) == 0 else 'DUPLICATE_ENTRY', f'claims.{L}')
    for c in claims:
        w = 'claims.' + str(c.get('link'))
        if not v.keys(c, {'link', 'stated_class', 'evidence'}, w, optional={'note'}):
            continue
        if c['stated_class'] not in RANK:
            v.no('BAD_CLASS', f'{w}: {c["stated_class"]}')
            continue
        got = []
        for e in c['evidence']:
            x = ev.get(e)
            if x is None:
                v.no('DANGLING_EVIDENCE', f'{w}: {e} is not an entry of this manifest')
            elif x['class'] is None:
                v.no('EVIDENCE_REFUSED', f'{w}: {e} failed its own checks')
            elif x['class'] != 'IDENTITY':
                got.append(x['class'])
        if not got:
            got = ['UNBOUND']
        top = max(RANK[g] for g in got)
        best = sorted({g for g in got if RANK[g] == top} | ({'UNBOUND'} if top == 0 else set()))
        if c['stated_class'] not in best:
            code = 'CLASS_OVERSTATED' if RANK[c['stated_class']] > top else 'CLASS_MISMATCH'
            v.no(code, f'{w}: stated {c["stated_class"]}, the evidence supports {"/".join(best)}')
        rows.append((c['link'], c['stated_class'], '/'.join(best), c['evidence']))
    ok = not v.reasons
    print(('IDENTITY VERIFIED' if ok else 'REFUSED') + ' — identity and record consistency only; proofs NOT re-run '
          '(no Dafny, no HOL, no Node was started)')
    for r in sorted(set(v.reasons), key=v.reasons.index):
        print('  ' + r)
    print('\n| link | stated | computed | evidence: record kind [storage] binding |')
    for link, st, cp, evs in rows:
        parts = []
        for e in evs:
            for run in (ev.get(e) or {}).get('runs', []) or []:
                parts.append(f'{e}: {run["kind"]} by {run["by"]} [{",".join(run["storage"])}] {run["binding"]}')
        print(f'| {link} | {st} | {cp} | ' + ('; '.join(parts) if parts else '-') + ' |')
    print('\nUNBOUND (no proof binds these bytes or components):')
    for u in m.get('unbound', []) if isinstance(m.get('unbound'), list) else []:
        print(f'  {u.get("id")}: {u.get("what")}')
    for n in v.notes:
        print('NOTE ' + n)
    print('identity verified; proofs NOT re-run' if ok else 'REFUSED; proofs NOT re-run')
    return 0 if ok else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException as e:  # noqa: BLE001  a crash is never a pass
        print(f'CRASH {type(e).__name__}: {e}\nproofs NOT re-run')
        sys.exit(2)
