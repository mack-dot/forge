"""Shared helpers for the assurance ledger (night shift 2026-11-19, Orchestrator B, task f-binding; copied and
extended by task f-binding-2: HOL theorem-name, COMMAND-line and run-record helpers; nothing removed; extended by
task f-binding-3: several closure roots per run (union of the closures of each root), exploration-run marker; extended
by task f-binding-4: review state as data (reviewed: true/false/pending) with a check that a reviewed edge names a
REPORTED review directory, and the superseded-sole-support rule; nothing removed).

Python 3 standard library only. No absolute home path is stored by these helpers: every stored path is relative
to the repository root. The include-closure rule is IMPORTED from the f-records runner
(orch-B/f-records/reproduce_dafny_proofs.py: `include_closure`, `apply_classic`, `set_digest`), so the ledger and
the f-records records use one rule.
"""
import csv, hashlib, importlib.util, os, re, shutil, tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_REPO = HERE.parents[3]                     # f-binding -> orch-B -> night-shift-20261119 -> results -> repo
NIGHT = 'results/night-shift-20261119'
F_RECORDS = NIGHT + '/orch-B/f-records'
BANNER_IDENTITY = 'IDENTITY AND RECORD CONSISTENCY ONLY — no proof was re-run'
CLASSES = ['MACHINE-CHECKED', 'ASSUMPTION', 'TESTED-UNPROVED', 'MISSING', 'CLAIMED, log missing', 'UNKNOWN-TONIGHT']
# Accepted exit-line forms (last non-empty line of a log). `exit N`: the Dafny lock script (orch-B/tools/dafny_locked.sh)
# and the node wrappers of the workers. `go exit N`: Orchestrator A's HOL wrapper (results/m1b-routeA-20261119/.../go-routeA.sh).
EXIT_FORMS = [('lock-script', re.compile(r'^exit (-?\d+)$')), ('hol-go-wrapper', re.compile(r'^go exit (-?\d+)$'))]


def load_frecords(repo):
    """Import the f-records runner from its file in the repository tree (its bytes are pinned as a ledger node)."""
    p = Path(repo) / F_RECORDS / 'reproduce_dafny_proofs.py'
    spec = importlib.util.spec_from_file_location('frecords_runner', p)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def sha_bytes(b):
    return hashlib.sha256(b).hexdigest()


def sha_file(p):
    return sha_bytes(Path(p).read_bytes())


def set_digest(rows):
    """The f-records set digest: SHA-256 of sorted lines `path<TAB>sha256<LF>`."""
    return sha_bytes(''.join('%s\t%s\n' % (p, h) for p, h in sorted(rows)).encode())


class Tree:
    """Repository view with an optional overlay directory (used by the controls: a mutated evidence file is placed
    at overlay/<relpath> and shadows the repository file; the repository is never written)."""

    def __init__(self, repo, overlay=None):
        self.repo = Path(repo).resolve()
        self.overlay = Path(overlay).resolve() if overlay else None

    def safe_rel(self, rel):
        """None if `rel` is not a plain relative path inside the repository tree."""
        if not isinstance(rel, str) or not rel or rel.startswith('/') or rel.startswith('~'):
            return None
        parts = Path(rel).parts
        if '..' in parts:
            return None
        real = (self.repo / rel).resolve()
        try:
            real.relative_to(self.repo)
        except ValueError:
            return None
        return rel

    def path(self, rel):
        if self.overlay is not None and (self.overlay / rel).exists():
            return self.overlay / rel
        return self.repo / rel

    def exists(self, rel):
        return self.safe_rel(rel) is not None and self.path(rel).is_file()

    def sha(self, rel):
        return sha_file(self.path(rel))

    def text(self, rel):
        return self.path(rel).read_text(encoding='utf-8', errors='replace')

    def materialize(self, root_rel, dest):
        """Copy the folder root_rel (repository, then overlay files on top) to dest."""
        src = self.repo / root_rel
        shutil.copytree(src, dest, symlinks=False)
        if self.overlay is not None and (self.overlay / root_rel).is_dir():
            for q in (self.overlay / root_rel).rglob('*'):
                if q.is_file():
                    t = Path(dest) / q.relative_to(self.overlay / root_rel)
                    t.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copyfile(q, t)


def closure_of(tree, fr, root_rel, entry, overlay_files=None, derive=None, tmpbase=None):
    """Full include closure of `entry` under `root_rel`, after placing overlay files (closure path -> repository path)
    and derived files (closure path -> {'diff': repo path, 'kind': 'classic-diff'}). Returns (rows, missing).
    [f2] When nothing is placed or derived and the overlay holds no file under root_rel, the imported include_closure
    runs on the repository folder itself (read-only; the same rule; no copy of a large root such as orch-B)."""
    if isinstance(entry, (list, tuple)):
        # [f3] several roots (one command line that names several .dfy files): the union of the closure of each root,
        # each computed by the same imported rule. A file reached from two roots appears once (same path, same bytes).
        allrows, allmissing = {}, []
        for en in entry:
            rows, missing = closure_of(tree, fr, root_rel, en, overlay_files, derive, tmpbase)
            allrows.update(dict(rows))
            allmissing += [m for m in missing if m not in allmissing]
        return sorted(allrows.items()), allmissing
    ov_under = tree.overlay is not None and (tree.overlay / root_rel).is_dir() and any(q.is_file() for q in (tree.overlay / root_rel).rglob('*'))
    if not overlay_files and not derive and not ov_under:
        seen, missing = fr.include_closure(tree.repo / root_rel, entry)
        return sorted(seen.items()), missing
    # [f4] DISK FIX: the earlier code copied the WHOLE root folder (tree.materialize) whenever an overlay file lay under it.
    # With root = orch-B that copied gigabytes per closure (and the tmp folder itself): 58 GB on 2026-11-19. Now only the
    # files that the include closure reaches are copied, one by one (overlay-aware), until the closure computed by the SAME
    # imported include_closure has no missing file that exists in the repository root. Hard cap: MATERIALIZE_CAP bytes.
    with tempfile.TemporaryDirectory(dir=tmpbase) as td:
        w = Path(td) / 'root'
        w.mkdir()
        used = [0]

        def place(cpath, src):
            t = w / cpath
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, t)
            used[0] += t.stat().st_size
            if used[0] > MATERIALIZE_CAP:
                raise ValueError('materialized closure exceeds %d bytes (cap); refused' % MATERIALIZE_CAP)

        for cpath, rpath in (overlay_files or {}).items():
            place(cpath, tree.path(rpath))
        for cpath, d in (derive or {}).items():
            if d.get('kind') != 'classic-diff':
                raise ValueError('unknown derivation %r' % d)
            if not (w / cpath).exists():
                place(cpath, tree.path(root_rel + '/' + cpath))
            fr.apply_classic(tree.text(d['diff']), w / cpath)
        for _ in range(100000):
            seen, missing = fr.include_closure(w, entry)
            todo = [m for m in missing if not m.startswith('LEAVES ROOT') and tree.safe_rel(root_rel + '/' + m) is not None
                    and tree.path(root_rel + '/' + m).is_file()]
            if not todo:
                break
            for m in todo:
                place(m, tree.path(root_rel + '/' + m))
        return sorted(seen.items()), missing


def last_line(text):
    lines = [l for l in text.splitlines() if l.strip()]
    return lines[-1].strip() if lines else ''


def parse_exit(text):
    """(form, exit) from the last non-empty line, or (None, None)."""
    ll = last_line(text)
    for form, rx in EXIT_FORMS:
        m = rx.match(ll)
        if m:
            return form, int(m.group(1))
    return None, None


def header(text, key):
    for l in text.splitlines()[:12]:
        if l.startswith('# %s:' % key):
            return l[len('# %s:' % key):].strip()
        if key in ('owner', 'cwd', 'start') and l.startswith('# owner='):
            m = re.search(r'\b%s=(\S+)' % key, l)
            if m:
                return m.group(1)
    return None


def cmd_dfy_files(cmd):
    """The .dfy file arguments of a `# cmd:` line (last path component)."""
    return [Path(t).name for t in (cmd or '').split() if t.endswith('.dfy')]


def relativize(s, repo):
    """Replace the repository root and any home folder by placeholders (no absolute home path in the ledger)."""
    s = s.replace(str(Path(repo).resolve()) + '/', '')
    return re.sub(r'/Users/[^/\s]+', '<home>', s)


def csv_lemmas(path):
    rows = list(csv.DictReader(open(path, newline='', encoding='utf-8')))
    out = {}
    for r in rows:
        name = re.sub(r' \(.*', '', r.get('TestResult.DisplayName', ''))
        out.setdefault(name, []).append(r.get('TestResult.Outcome'))
    return out, len(rows)


def check_required(path, required):
    """List of problems: required lemma rows absent or not all Passed."""
    lem, _ = csv_lemmas(path)
    bad = []
    for n in required:
        if n not in lem:
            bad.append('%s: no row' % n)
        elif any(o != 'Passed' for o in lem[n]):
            bad.append('%s: outcome %s' % (n, sorted(set(lem[n]))))
    return bad


# ---- added by f-binding-2 (HOL evidence helpers; read-only parsing of stored logs and run records)
HOL_NAME_RX = re.compile(r'^(?:\d+:)?(?:CHECKED|FORGE_THEOREM) ([A-Za-z0-9_\']+)')


def hol_names(text):
    """Theorem names that a HOL go log reports as proved: `CHECKED <name>` (route A, U294 replays) or
    `FORGE_THEOREM <name>` (link cases). `FORGE_BEGIN` lines do not count."""
    out = []
    for l in text.splitlines():
        m = HOL_NAME_RX.match(l.strip())
        if m and m.group(1) not in out:
            out.append(m.group(1))
    return out


def hol_command(text):
    """The `COMMAND:` line of a link go log (None for route-A logs, which have none)."""
    for l in text.splitlines():
        if l.startswith('COMMAND:'):
            return l
    return None


def hol_check_names(text, required, lines=()):
    """Problems: a required theorem name not reported as proved, or a required line (exact, stripped) absent."""
    have = set(hol_names(text))
    bad = ['%s: not reported as CHECKED/FORGE_THEOREM' % n for n in required if n not in have]
    stripped = set(re.sub(r'^\d+:', '', l.strip()) for l in text.splitlines())
    bad += ['line %r absent' % x for x in lines if x not in stripped]
    return bad


# ---- added by f-binding-3
# Orchestrator A marks an exploration run (no export, nothing stored, proves nothing) with this word in the go log and
# in the run record line. Such a run never supports a MACHINE-CHECKED edge, even when it ends `go exit 0`.
EXPLORE_MARK = 'EXPLORE_COMPLETE'
MATERIALIZE_CAP = 20 * 1024 * 1024   # [f4] bytes per materialized closure


def is_explore(*texts):
    return any(EXPLORE_MARK in (t or '') for t in texts)


def run_entries(run):
    """The closure roots of a Dafny run: `entries` (several roots on one command line) or [entry]."""
    return list(run.get('entries') or [run.get('entry')])


def entry_arg(run):
    """The argument for closure_of: a list when the run has several roots, else the single entry (unchanged rule)."""
    es = run_entries(run)
    return es if len(es) > 1 else es[0]


def cmd_roots_problem(cmd, run):
    """[f3] The `.dfy` files that the `# cmd:` line names must be EXACTLY the closure roots of the run (as a set of
    file names). A command with two roots but a ledger closure of one root (or the reverse) is refused."""
    named = sorted(set(cmd_dfy_files(cmd)))
    roots = sorted(set(Path(e).name for e in run_entries(run)))
    if named != roots:
        return '# cmd: names %s, the closure roots are %s' % (named, roots)
    return None


# ---- added by f-binding-4
# Review state of an edge is DATA: `reviewed` is True, False or 'pending'. A `reviewed: True` edge must name at least one
# review directory inside the repository tree, and each directory must be REPORTED: it holds REPORT.md (Orchestrator A's
# condensed reviews), or Orchestrator B's append-only STATE.md has a line `<folder name> [(...)] REPORTED`. (The worker
# harness refuses REPORT.md in B's worker folders, so B's reviews are known as finished only from STATE.md.)
STATE_B = NIGHT + '/orch-B/STATE.md'


def review_state_ok(st):
    return st is True or st is False or st == 'pending'


def review_reported(tree, d):
    """(True, basis) when the review directory d is REPORTED, else (False, reason)."""
    if tree.safe_rel(d) is None or not (tree.repo / d).is_dir():
        return False, 'review directory %r absent or outside the repository tree' % d
    if (tree.repo / d / 'REPORT.md').is_file():
        return True, d + '/REPORT.md'
    name = Path(d).name
    if tree.exists(STATE_B):
        rx = re.compile(r'(^|\s)%s(\s*\([^)]*\))?\s+REPORTED\b' % re.escape(name))
        for l in tree.text(STATE_B).splitlines():
            if rx.search(l):
                return True, '%s: %s' % (STATE_B, l.strip()[:90])
    return False, 'review %s: no REPORT.md and no "%s REPORTED" line in %s' % (d, name, STATE_B)


def review_problems(tree, e):
    """Problems of the review data of one edge (empty = consistent)."""
    st = e.get('reviewed', False)
    probs = []
    if not review_state_ok(st):
        return ['reviewed=%r is not true/false/pending' % (st,)]
    if st is True:
        dirs = e.get('review_dirs') or []
        if not dirs:
            probs.append('reviewed=true names no review directory')
        for d in dirs:
            ok, why = review_reported(tree, d)
            if not ok:
                probs.append(why)
        if e.get('review_pending'):
            probs.append('reviewed=true but review_pending lists %s' % e['review_pending'])
    elif st == 'pending':
        if not e.get('review_pending'):
            probs.append('reviewed=pending but no review_pending entry')
    elif e.get('review_pending'):
        probs.append('reviewed=false but review_pending lists %s (must be pending)' % e['review_pending'])
    return probs


def superseded_support_problems(edges):
    """[f4] An edge whose support (its `rests_on` edge ids; if none, its sub-edges) is non-empty but consists ONLY of superseded
    edges is refused: a superseded edge may stay in the ledger, but it may not be the only evidence that feeds another
    edge. Returns (code, message) pairs."""
    byid = {e.get('id'): e for e in edges}
    out = []
    for e in edges:
        ro = list(e.get('rests_on') or [])
        for x in ro:
            if x not in byid:
                out.append(('UNKNOWN_EDGE_REF', '%s rests_on absent edge %s' % (e.get('id'), x)))
        # The declared evidence (`rests_on`) must hold a live edge. Without `rests_on`, the sub-edges are the support.
        sup = [x for x in ro if x in byid] if ro else [x.get('id') for x in edges if x.get('sub_of') == e.get('id')]
        live = [x for x in sup if not byid[x].get('superseded_by')]
        if sup and not live:
            out.append(('SUPERSEDED_SOLE_SUPPORT', '%s rests only on superseded edges %s' % (e.get('id'), sup)))
    return out
