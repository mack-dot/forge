"""Shared helpers for the assurance ledger (night shift 2026-11-19, Orchestrator B, task f-binding).

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
    and derived files (closure path -> {'diff': repo path, 'kind': 'classic-diff'}). Returns (rows, missing)."""
    with tempfile.TemporaryDirectory(dir=tmpbase) as td:
        w = Path(td) / 'root'
        tree.materialize(root_rel, w)
        for cpath, rpath in (overlay_files or {}).items():
            t = w / cpath
            t.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(tree.path(rpath), t)
        for cpath, d in (derive or {}).items():
            if d.get('kind') != 'classic-diff':
                raise ValueError('unknown derivation %r' % d)
            fr.apply_classic(tree.text(d['diff']), w / cpath)
        seen, missing = fr.include_closure(w, entry)
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
