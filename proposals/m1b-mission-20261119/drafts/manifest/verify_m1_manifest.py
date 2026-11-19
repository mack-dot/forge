#!/usr/bin/env python3
"""Draft verifier of a Forge M1 evidence manifest (W5, 2026-11-19). Standard library only. No network.

Question: is this exact artifact covered by this exact proof, against this exact approved contract,
under these exact assumptions, at the level that the CALLER asks for (--level M1-A or M1-B)?

The level is an input of the verifier. The manifest never states a level. The verifier computes the
supported level from the evidence fields. Every comparison fails closed: a missing, null, unknown,
unreadable or different value is a refusal.

Exit 0: the requested level is fully supported.  Exit 1: refused (reasons printed).  Exit 2: crash.
"""
import argparse
import hashlib
import json
import re
import subprocess
import sys
from pathlib import Path

FORMAT = 'forge.m1.evidence-manifest/1'
HEX64 = re.compile(r'^[0-9a-f]{64}$')
HEX40 = re.compile(r'^[0-9a-f]{40}$')
LEVEL_KEYS = re.compile(r'(level|verdict|achieved|claim_status|m1_status|closed)', re.I)
# Profile A as approved on 2026-11-19 (OWNER_DECISIONS.md Q1 to Q5). Fixed in the verifier, not read from the manifest.
PROFILE_A = {'A-R1', 'A-R2', 'A-R3', 'A-R4', 'A-R5', 'A-R6', 'A-R8', 'A-R9', 'A-R10', 'A-R13', 'A-Q3A', 'A-Q3C', 'A-Q5'}
LINK_RANK = {'NOT_ESTABLISHED': 0, 'REVIEWED': 1, 'MACHINE_CHECKED': 2}
REVIEW_ROWS = 18

KEYS = {
    '': {'manifest_format', 'subject', 'end_to_end', 'notes', 'approved_spec', 'implementation_sources',
         'final_theorem', 'proof_dependencies', 'toolchain', 'artifact', 'assumption_profile', 'obligations',
         'contract_link', 'replays', 'open_issues'},
    'approved_spec': {'contract', 'protocol', 'lock', 'approval_record', 'approval_commit'},
    'final_theorem': {'theory', 'name', 'sig', 'statement_log', 'statement_sha256', 'premises'},
    'proof_dependencies': {'allowed_tags', 'forge_theories', 'upstream_parents', 'replay_comparisons'},
    'toolchain': {'pin_source', 'polyml_commit', 'hol_commit', 'cakeml_commit', 'dafny_build', 'backend_config',
                  'compile_theorem'},
    'toolchain.compile_theorem': {'theory', 'name', 'theory_log', 'assembly'},
    'artifact': {'file', 'size', 'format', 'image_theory', 'slices'},
    'assumption_profile': {'profile', 'decision_record', 'items', 'premise_ledger', 'conditions'},
    'assumption_profile.premise_ledger': {'status', 'record', 'map', 'note'},
    'contract_link': {'status', 'review', 'mechanical', 'note'},
    'replays': {'chain_same_machine', 'recorded_cases_158', 'clean', 'independent'},
}
LIST_KEYS = {
    'implementation_sources': {'role', 'locator', 'sha256'},
    'proof_dependencies.forge_theories': {'theory', 'dat', 'sig_sha256'},
    'proof_dependencies.upstream_parents': {'theory', 'dat'},
    'artifact.slices': {'name', 'offset', 'length', 'unit', 'sha256', 'hol_theorem'},
    'assumption_profile.items': {'id', 'kind', 'decision_ref', 'statement', 'status', 'verified'},
    'assumption_profile.conditions': {'item', 'status', 'record', 'note'},
    'obligations': {'id', 'status', 'ref'},
    'open_issues': {'id', 'status', 'text'},
}
PINNED = {'locator', 'sha256'}
STATUS_RECORD = {'status', 'record'}


class Check:
    def __init__(self, root, git_dir, toolchain_root):
        self.root, self.git_dir, self.tc = root, git_dir, toolchain_root
        self.common, self.only_a, self.only_b = [], [], []
        self.cache = {}

    def no(self, code, text, scope='common'):
        {'common': self.common, 'A': self.only_a, 'B': self.only_b}[scope].append(f'{code}: {text}')

    # ---------- reading ----------
    def read(self, locator, where):
        if not isinstance(locator, dict) or len(locator) != 1:
            self.no('BAD_LOCATOR', where)
            return None
        kind, val = next(iter(locator.items()))
        key = json.dumps(locator, sort_keys=True)
        if key in self.cache:
            return self.cache[key]
        data = None
        if kind in ('file', 'toolchain'):
            base = self.root if kind == 'file' else self.tc
            if base is None or not isinstance(val, str) or val.startswith('/') or '..' in Path(val).parts:
                self.no('BAD_LOCATOR', f'{where}: {kind} locator not usable')
                return None
            p = base / val
            if p.is_file():
                data = p.read_bytes()
        elif kind == 'git':
            if not (isinstance(val, dict) and set(val) == {'commit', 'path'} and HEX40.match(str(val['commit']))):
                self.no('BAD_LOCATOR', f'{where}: git locator needs a full 40-hex commit and a path')
                return None
            r = subprocess.run(['git', '--git-dir', str(self.git_dir), 'cat-file', 'blob', f"{val['commit']}:{val['path']}"],
                               capture_output=True)
            data = r.stdout if r.returncode == 0 else None
        else:
            self.no('BAD_LOCATOR', f'{where}: unknown locator kind {kind}')
            return None
        if data is None:
            self.no('UNREADABLE', f'{where}: {val}')
        self.cache[key] = data
        return data

    def pinned(self, obj, where):
        """A {locator, sha256} pair: read the bytes and compare the SHA-256. Returns the bytes or None."""
        if obj is None:
            self.no('MISSING_EVIDENCE', where)
            return None
        if not self.keys(obj, PINNED, where):
            return None
        if not isinstance(obj['sha256'], str) or not HEX64.match(obj['sha256']):
            self.no('BAD_DIGEST', where)
            return None
        data = self.read(obj['locator'], where)
        if data is None:
            return None
        got = hashlib.sha256(data).hexdigest()
        if got != obj['sha256']:
            self.no('DIGEST_MISMATCH', f'{where}: file {got[:16]}... manifest {obj["sha256"][:16]}...')
            return None
        return data

    def keys(self, obj, want, where):
        if not isinstance(obj, dict):
            self.no('MISSING_FIELD', f'{where} is not an object')
            return False
        ok = True
        for k in sorted(want - set(obj)):
            self.no('MISSING_FIELD', f'{where}.{k}'.lstrip('.'))
            ok = False
        for k in sorted(set(obj) - want):
            code = 'PRODUCER_STATED_LEVEL' if LEVEL_KEYS.search(k) else 'UNKNOWN_FIELD'
            self.no(code, f'{where}.{k}'.lstrip('.'))
            ok = False
        return ok


# ---------- HOL .dat reading (structure only; no term decoding) ----------
def sexp(text):
    stack, i, n = [[]], 0, len(text)
    while i < n:
        c = text[i]
        if c.isspace():
            i += 1
        elif c == '(':
            stack.append([])
            i += 1
        elif c == ')':
            x = stack.pop()
            stack[-1].append(x)
            i += 1
        elif c == '"':
            j, buf = i + 1, []
            while text[j] != '"':
                if text[j] == '\\':
                    buf.append(text[j + 1])
                    j += 2
                else:
                    buf.append(text[j])
                    j += 1
            stack[-1].append(('S', ''.join(buf)))
            i = j + 1
        else:
            j = i
            while j < n and not text[j].isspace() and text[j] not in '()"':
                j += 1
            stack[-1].append(('A', text[i:j]))
            i = j
    if len(stack) != 1 or len(stack[0]) != 1:
        raise ValueError('unbalanced')
    return stack[0][0]


def read_dat(data):
    """Returns (theory name, [(parent, sha1)], {entry name: (class, [tags])})."""
    root = sexp(data.decode('utf-8'))
    if root[0] != ('A', 'theory'):
        raise ValueError('not a theory file')
    head = root[1]
    name = head[0][1]
    parents = []
    for p in head[1:]:
        if len(p) != 3 or p[1] != ('A', '.') or not HEX40.match(p[2][1]):
            raise ValueError('bad parent record')
        parents.append((p[0][1], p[2][1]))
    core = root[2]
    strings = [x[1] for x in core[1][1][1:]]
    if core[1][1][0] != ('A', 'string-table') or core[2] != ('A', 'exports'):
        raise ValueError('unexpected core-data layout')
    entries = {}
    for e in core[5]:
        nm = strings[int(e[0][1])]
        tags = e[1][1:]
        if not all(isinstance(t, tuple) and t[0] == 'S' for t in tags):
            raise ValueError(f'non-string tag in {nm}')
        entries[nm] = (int(e[2][0][1]), [t[1] for t in tags])
    return name, parents, entries


def norm(s):
    return ' '.join(s.split())


def printed_statement(log, name):
    lines = log.split('\n')
    if lines.count('CHECKED ' + name) != 1:
        return None
    i = lines.index('CHECKED ' + name) + 1
    stops = ('Saved theorem', 'CHECKED ', 'MARK ', 'MACHINE_SEM_TERM ', 'INPUT_PREMISE ', 'EXACT_COMPLETE')
    out = []
    while i < len(lines) and not lines[i].startswith(stops):
        out.append(lines[i])
        i += 1
    return norm(' '.join(out))


def split_top(s, sep):
    parts, depth, cur, i = [], 0, '', 0
    while i < len(s):
        if s[i] == '(':
            depth += 1
        elif s[i] == ')':
            depth -= 1
        if depth == 0 and s.startswith(sep, i):
            parts.append(cur.strip())
            cur, i = '', i + len(sep)
            continue
        cur += s[i]
        i += 1
    parts.append(cur.strip())
    return parts


def status_record(c, obj, where, need, artifact_sha, scope):
    """{status, record}: status must equal `need`; the record must be pinned and must restate status and artifact."""
    if obj is None or not c.keys(obj, STATUS_RECORD, where):
        c.no('MISSING_EVIDENCE', where, scope)
        return False
    if obj['status'] != need:
        c.no('NOT_SATISFIED', f'{where}: status {obj["status"]}, needs {need}', scope)
        return False
    data = c.pinned(obj['record'], where + '.record')
    if data is None:
        return False
    try:
        rec = json.loads(data)
    except ValueError:
        c.no('BAD_RECORD', where, scope)
        return False
    if rec.get('status') != need or rec.get('artifact_sha256') != artifact_sha:
        c.no('RECORD_NOT_BOUND', f'{where}: record status or artifact_sha256 differs', scope)
        return False
    return True


def verify(m, c):
    if not c.keys(m, KEYS[''], ''):
        pass
    for path, want in KEYS.items():
        if path:
            obj = m
            for part in path.split('.'):
                obj = obj.get(part) if isinstance(obj, dict) else None
            if obj is not None:
                c.keys(obj, want, path)
    for path, want in LIST_KEYS.items():
        obj = m
        for part in path.split('.'):
            obj = obj.get(part) if isinstance(obj, dict) else None
        for i, item in enumerate(obj or []):
            c.keys(item, want, f'{path}[{i}]')
    if c.common:
        return  # the structure is wrong; no further reading
    # fields that must be a pinned {locator, sha256} pair; null or any other shape stops here (fail closed)
    must = [('approved_spec', k) for k in ('contract', 'protocol', 'lock', 'approval_record')]
    must += [('final_theorem', 'sig'), ('final_theorem', 'statement_log'), ('toolchain', 'pin_source'),
             ('artifact', 'file'), ('assumption_profile', 'decision_record')]
    pairs = [(f'{a}.{b}', m[a][b]) for a, b in must]
    pairs += [(f'toolchain.compile_theorem.{k}', m['toolchain']['compile_theorem'][k]) for k in ('theory_log', 'assembly')]
    pairs += [(f'theory {t["theory"]} .dat', t['dat']) for t in m['proof_dependencies']['forge_theories']]
    pairs += [(f'upstream {t["theory"]} .dat', t['dat']) for t in m['proof_dependencies']['upstream_parents']]
    pairs += [(f'replay_comparisons[{i}]', x) for i, x in enumerate(m['proof_dependencies']['replay_comparisons'])]
    for where, obj in pairs:
        if not (isinstance(obj, dict) and set(obj) == PINNED and isinstance(obj['locator'], dict)):
            c.no('MISSING_EVIDENCE', f'{where} is not a pinned {{locator, sha256}} pair')
    if not isinstance(m['artifact']['slices'], list) or not isinstance(m['final_theorem']['premises'], list):
        c.no('MISSING_FIELD', 'artifact.slices or final_theorem.premises is not a list')
    if c.common:
        return
    if m['manifest_format'] != FORMAT:
        c.no('FORMAT', m['manifest_format'])
    if m['end_to_end'] is not False:
        c.no('END_TO_END', 'end_to_end must be false; no M1 level is an end-to-end claim')

    # 1. approved specification
    s = m['approved_spec']
    contract = c.pinned(s['contract'], 'approved_spec.contract')
    protocol = c.pinned(s['protocol'], 'approved_spec.protocol')
    lock = c.pinned(s['lock'], 'approved_spec.lock')
    approval = c.pinned(s['approval_record'], 'approved_spec.approval_record')
    if approval is not None:
        text = approval.decode('utf-8')
        rows = dict(re.findall(r'\|\s*`([^`]+)`\s*\|\s*`([0-9a-f]{64})`\s*\|', text))
        if not HEX40.match(str(s['approval_commit'])) or s['approval_commit'] not in text:
            c.no('SPEC_NOT_APPROVED', 'approval commit not named in the approval record')
        for name, obj in (('spec/refund/RefundSpec.dfy', s['contract']), ('spec/refund/protocol.md', s['protocol'])):
            if rows.get(name) != obj.get('sha256'):
                c.no('SPEC_NOT_APPROVED', f'{name}: digest is not the approved digest')
    if lock is not None and contract is not None:
        lk = json.loads(lock)
        if lk.get('spec_sha256') != s['contract']['sha256'] or lk.get('protocol_sha256') != s['protocol']['sha256']:
            c.no('SPEC_NOT_APPROVED', 'spec.lock names other spec or protocol digests')
        if lk.get('dafny_build') != m['toolchain']['dafny_build']:
            c.no('TOOLCHAIN_MISMATCH', 'dafny_build differs from spec.lock')

    # 2. implementation sources
    roles = [x['role'] for x in m['implementation_sources']]
    need_roles = {'approved_assess_impl', 'boundary_dafny', 'hol_dafny_ast_program', 'whole_program_script',
                  'compile_application_script'}
    if set(roles) != need_roles or len(roles) != len(need_roles):
        c.no('SOURCE_SET', f'roles {sorted(roles)}')
    for x in m['implementation_sources']:
        c.pinned({'locator': x['locator'], 'sha256': x['sha256']}, f'implementation_sources.{x["role"]}')

    # 3. proof dependencies: every Forge theory, parent links by SHA-1, tags
    d = m['proof_dependencies']
    allowed = set(d['allowed_tags'])
    if allowed != {'DISK_THM'}:
        c.no('WEAK_TAG_POLICY', f'allowed_tags {sorted(allowed)}')
    replayed = {}
    for i, comp in enumerate(d['replay_comparisons']):
        data = c.pinned(comp, f'proof_dependencies.replay_comparisons[{i}]')
        if data is not None:
            for k, v in json.loads(data).items():
                if isinstance(v, dict) and v.get('theory'):
                    if v.get('comparison') != 'equal' or v.get('status') != 'REPLAYED':
                        c.no('REPLAY_NOT_EQUAL', k)
                    replayed[v['theory']] = (v['files']['dat']['fresh'], v['files']['sig']['fresh'])
    info, sha1 = {}, {}
    for th in d['forge_theories']:
        nm = th['theory']
        data = c.pinned(th['dat'], f'theory {nm} .dat')
        if replayed.get(nm) != (th['dat'].get('sha256'), th['sig_sha256']):
            c.no('STALE_PROOF_RECORD', f'{nm}: .dat/.sig digests differ from the replay comparison record')
        if data is None:
            continue
        try:
            name, parents, entries = read_dat(data)
        except (ValueError, IndexError, KeyError) as e:
            c.no('DAT_UNREADABLE', f'{nm}: {e}')
            continue
        if name != nm:
            c.no('DAT_NAME', f'{nm} file names theory {name}')
        for en, (cls, tags) in entries.items():
            if not set(tags) <= allowed:
                c.no('ORACLE_OR_TAG', f'{nm}.{en}: tags {tags}')
        info[nm] = (parents, entries)
        sha1[nm] = hashlib.sha1(data).hexdigest()
    up_sha1 = {}
    for u in d['upstream_parents']:
        data = c.pinned(u['dat'], f'upstream {u["theory"]} .dat')
        if data is not None:
            up_sha1[u['theory']] = hashlib.sha1(data).hexdigest()
    ft = m['final_theorem']
    seen, stack, reached_up = set(), [ft['theory']], set()
    while stack:
        x = stack.pop()
        if x in seen:
            continue
        seen.add(x)
        if x not in info:
            c.no('DEPENDENCY_NOT_BOUND', f'theory {x} has no readable bound .dat')
            continue
        for p, h in info[x][0]:
            if p in info or p in sha1:
                if sha1.get(p) != h:
                    c.no('PARENT_LINK', f'{x} -> {p}: parent SHA-1 differs')
                stack.append(p)
            elif p in up_sha1:
                reached_up.add(p)
                if up_sha1[p] != h:
                    c.no('PARENT_LINK', f'{x} -> upstream {p}: SHA-1 differs')
            else:
                c.no('DEPENDENCY_NOT_BOUND', f'{x} -> {p}: parent not in the manifest')
    listed = {t['theory'] for t in d['forge_theories']}
    if listed != seen:
        c.no('CLOSURE_MISMATCH', f'listed but not reached {sorted(listed - seen)}; reached but not listed {sorted(seen - listed)}')
    if {u['theory'] for u in d['upstream_parents']} != reached_up:
        c.no('CLOSURE_MISMATCH', 'upstream parent list differs from the parents reached')

    # 4. final theorem: name, class, tags, printed statement, premises
    sig = c.pinned(ft['sig'], 'final_theorem.sig')
    log = c.pinned(ft['statement_log'], 'final_theorem.statement_log')
    ent = info.get(ft['theory'], (None, {}))[1].get(ft['name'])
    if ent is None or ent[0] != 2:
        c.no('THEOREM_NOT_FOUND', f'{ft["theory"]}.{ft["name"]} is not a stored theorem')
    if sig is not None and f'val {ft["name"]} : thm' not in sig.decode('utf-8'):
        c.no('THEOREM_NOT_FOUND', 'name not in .sig')
    if replayed.get(ft['theory'], (None, None))[1] != ft['sig'].get('sha256'):
        c.no('STALE_PROOF_RECORD', 'final .sig digest differs from the replay record')
    stmt = printed_statement(log.decode('utf-8'), ft['name']) if log is not None else None
    if stmt is None:
        c.no('STATEMENT', 'printed statement not found exactly once')
    else:
        if hashlib.sha256(stmt.encode('utf-8')).hexdigest() != ft['statement_sha256']:
            c.no('STATEMENT', 'printed statement digest differs')
        ante = split_top(stmt.lstrip('⊢ '), ' ⇒ ')[0]
        if split_top(ante, ' ∧ ') != [norm(p[1]) for p in ft['premises']]:
            c.no('PREMISES', 'premise list differs from the antecedent of the printed statement')

    # 5. toolchain and compiler configuration
    t = m['toolchain']
    pins = c.pinned(t['pin_source'], 'toolchain.pin_source')
    if not t['pin_source']['locator'].get('file', '').startswith('toolchain/'):
        c.no('PIN_NOT_PROTECTED', 'HOL, CakeML and Poly/ML commits are not pinned in a protected toolchain/ file')
    if pins is not None:
        text = pins.decode('utf-8')
        for key, label in (('polyml_commit', 'polyml'), ('hol_commit', 'HOL'), ('cakeml_commit', 'cakeml')):
            mm = re.search(r"'%s':\s*\('[^']*',\s*'([0-9a-f]{40})'\)" % label, text)
            if not mm or mm.group(1) != t[key]:
                c.no('TOOLCHAIN_MISMATCH', f'{key} differs from the pin source')
    ct = t['compile_theorem']
    tl = c.pinned(ct['theory_log'], 'toolchain.compile_theorem.theory_log')
    c.pinned(ct['assembly'], 'toolchain.compile_theorem.assembly')
    if tl is not None:
        text = tl.decode('utf-8')
        for line in (f'FORGE_THEOREM {ct["name"]}', 'FORGE_ORACLES DISK_THM', 'FORGE_AXIOMS ', 'FORGE_HYPOTHESES 0',
                     f'FORGE_STATEMENT ⊢ backend$compile {t["backend_config"]}'):
            if not any(l == line or (line.startswith('FORGE_STATEMENT') and l.startswith(line)) for l in text.split('\n')):
                c.no('COMPILER_CONFIG', f'compile record lacks "{line.strip()}"')
    ce = info.get(ct['theory'], (None, {}))[1].get(ct['name'])
    if ct['theory'] not in seen or ce is None or ce[0] != 2:
        c.no('COMPILER_CONFIG', 'compile theorem is not a stored theorem inside the closure')

    # 6. artifact identity and slices
    a = m['artifact']
    exe = c.pinned(a['file'], 'artifact.file')
    if exe is not None and len(exe) != a['size']:
        c.no('ARTIFACT_SIZE', f'{len(exe)} bytes, manifest {a["size"]}')
    img = info.get(a['image_theory'], (None, {}))[1]
    if a['image_theory'] not in seen:
        c.no('ARTIFACT_NOT_LINKED', 'image theory not in the closure of the final theorem')
    names = sorted(sl['name'] for sl in a['slices'])
    if names != ['bitmaps', 'code']:
        c.no('ARTIFACT_SLICES', f'slices {names}')
    for sl in a['slices']:
        if exe is not None:
            o, n = sl['offset'], sl['length']
            if not (isinstance(o, int) and isinstance(n, int) and 0 <= o and n > 0 and o + n <= len(exe)):
                c.no('ARTIFACT_SLICES', f'{sl["name"]}: bad range')
            elif hashlib.sha256(exe[o:o + n]).hexdigest() != sl['sha256']:
                c.no('ARTIFACT_SLICES', f'{sl["name"]}: slice digest differs')
        if img.get(sl['hol_theorem'], (0,))[0] != 2:
            c.no('ARTIFACT_NOT_LINKED', f'{sl["hol_theorem"]} not a stored theorem of {a["image_theory"]}')

    # 7. assumption profile
    ap = m['assumption_profile']
    c.pinned(ap['decision_record'], 'assumption_profile.decision_record')
    if ap['profile'] != 'A':
        c.no('PROFILE', f'profile {ap["profile"]} is not the approved Profile A')
    ids = [i['id'] for i in ap['items']]
    if set(ids) != PROFILE_A or len(ids) != len(PROFILE_A):
        c.no('PROFILE', f'items differ from Profile A: extra {sorted(set(ids) - PROFILE_A)}, missing {sorted(PROFILE_A - set(ids))}')
    for i in ap['items']:
        if i['status'] != 'APPROVED' or not i['decision_ref'] or i['verified'] is not False:
            c.no('PROFILE', f'{i["id"]}: needs status APPROVED, a decision_ref and verified=false')
    led = ap['premise_ledger']
    pids = [p[0] for p in ft['premises']]
    if set(led['map']) != set(pids) or any(not set(v) or not set(v) <= set(ids) for v in led['map'].values()):
        c.no('PREMISE_LEDGER', 'not every premise maps to Profile A items')
    if led['status'] != 'REVIEWED':
        c.no('PREMISE_LEDGER', f'ledger status {led["status"]}, needs REVIEWED')
    else:
        c.pinned(led['record'], 'assumption_profile.premise_ledger.record')
    conds = {x['item']: x for x in ap['conditions']}
    if set(conds) != {'A-Q3C'}:
        c.no('PROFILE', 'conditions must be exactly A-Q3C')
    q3c = conds.get('A-Q3C')
    q3c = {'status': q3c['status'], 'record': q3c['record']} if q3c else None
    status_record(c, q3c, 'assumption_profile.conditions.A-Q3C', 'VALIDATED',
                  a['file'].get('sha256'), 'common')

    # 8. obligations and open issues
    for o in m['obligations']:
        if o['status'] not in ('DISCHARGED', 'APPROVED_ASSUMPTION'):
            c.no('OBLIGATION_OPEN', f'{o["id"]}: {o["status"]}')
    for o in m['open_issues']:
        if o['status'] != 'RESOLVED':
            c.no('OPEN_ISSUE', f'{o["id"]}: {o["status"]}')

    # 9. replays
    r = m['replays']
    ch = r['chain_same_machine']
    if not (isinstance(ch, dict) and ch.get('status') == 'PASSED' and c.pinned(ch.get('record'), 'replays.chain_same_machine.record')):
        c.no('REPLAY', 'chain_same_machine not PASSED with a pinned record')
    status_record(c, r['recorded_cases_158'], 'replays.recorded_cases_158', 'PASSED', a['file'].get('sha256'), 'common')
    status_record(c, r['clean'], 'replays.clean', 'PASSED', a['file'].get('sha256'), 'common')
    status_record(c, r['independent'], 'replays.independent', 'PASSED', a['file'].get('sha256'), 'B')

    # 10. contract link
    cl = m['contract_link']
    st = cl['status']
    if st not in LINK_RANK:
        c.no('LINK', f'unknown link status {st}')
        st = 'NOT_ESTABLISHED'
    if LINK_RANK[st] < 1:
        c.no('LINK_NOT_ESTABLISHED', 'no reviewed and no machine-checked link from the approved contract to the HOL model', 'A')
    if LINK_RANK[st] < 2:
        c.no('LINK_METHOD_WEAKER', f'link method {st} is weaker than MACHINE_CHECKED', 'B')
    if st == 'REVIEWED':
        check_review(c, cl['review'], s, a)
    if st == 'MACHINE_CHECKED':
        check_mechanical(c, cl['mechanical'], s, a, info, seen)


def check_review(c, rv, s, a):
    if rv is None:
        c.no('MISSING_EVIDENCE', 'contract_link.review', 'A')
        return
    data = c.pinned(rv, 'contract_link.review')
    if data is None:
        return
    rec = json.loads(data)
    if rec.get('spec_sha256') != s['contract']['sha256'] or rec.get('artifact_sha256') != a['file']['sha256']:
        c.no('RECORD_NOT_BOUND', 'review record names another spec or artifact', 'A')
    if rec.get('reviewer_is_author') is not False or not rec.get('reviewer') or not rec.get('owner_named_reviewer_ref'):
        c.no('REVIEW_NOT_INDEPENDENT', 'reviewer must be named by the owner and must not be the author', 'A')
    rows = rec.get('rows') or []
    if sorted(r.get('row') for r in rows) != list(range(1, REVIEW_ROWS + 1)):
        c.no('REVIEW_INCOMPLETE', 'rows 1 to 18 must each appear once', 'A')
    for r in rows:
        if r.get('verdict') != 'HOLDS' or r.get('disposition') != 'CLOSED':
            c.no('REVIEW_ROW', f'row {r.get("row")}: {r.get("verdict")} / {r.get("disposition")}', 'A')


def check_mechanical(c, mech, s, a, info, seen):
    want = {'dafny_record', 'hol_theory', 'hol_theorem'}
    if mech is None or not c.keys(mech, want, 'contract_link.mechanical'):
        c.no('MISSING_EVIDENCE', 'contract_link.mechanical', 'B')
        return
    data = c.pinned(mech['dafny_record'], 'contract_link.mechanical.dafny_record')
    if data is not None:
        rec = json.loads(data)
        if rec.get('spec_sha256') != s['contract']['sha256'] or rec.get('exit') != 0 or rec.get('status') != 'VERIFIED':
            c.no('LINK_DAFNY', 'Dafny half: not exit 0 VERIFIED against the approved spec digest', 'B')
    ent = info.get(mech['hol_theory'], (None, {}))[1].get(mech['hol_theorem'])
    if mech['hol_theory'] not in seen or ent is None or ent[0] != 2:
        c.no('LINK_HOL', 'HOL half: link theorem is not a stored theorem in the closure of the final theorem', 'B')


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('manifest')
    ap.add_argument('--level', required=True, choices=['M1-A', 'M1-B'])
    ap.add_argument('--root', required=True, help='folder for file locators')
    ap.add_argument('--git-dir', help='git object store for git locators (read only)')
    ap.add_argument('--toolchain-root', help='folder for toolchain locators')
    o = ap.parse_args()
    root = Path(o.root).resolve()
    c = Check(root, Path(o.git_dir) if o.git_dir else root / '.git',
              Path(o.toolchain_root).resolve() if o.toolchain_root else None)
    try:
        m = json.loads(Path(o.manifest).read_text(encoding='utf-8'))
    except (OSError, ValueError) as e:
        print(f'REFUSED {o.level}\n  MANIFEST_UNREADABLE: {e}')
        return 1
    verify(m, c)
    a_reasons = c.common + c.only_a
    b_reasons = c.common + c.only_a + c.only_b
    reasons = a_reasons if o.level == 'M1-A' else b_reasons
    supported = 'M1-B' if not b_reasons else 'M1-A' if not a_reasons else 'none'
    print(f'{"SUPPORTED" if not reasons else "REFUSED"} {o.level}  (highest level supported by this evidence: {supported})')
    for r in sorted(set(reasons), key=reasons.index):
        print('  ' + r)
    return 0 if not reasons else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except BaseException as e:  # noqa: BLE001  a crash is never a pass
        print(f'CRASH {type(e).__name__}: {e}')
        sys.exit(2)
