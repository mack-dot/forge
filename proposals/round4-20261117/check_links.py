"""List the relative Markdown link targets of given files that do not exist in a git revision. Reads only.

A link is `[text](target)`. Targets with a scheme (https:, mailto:) and pure anchors are skipped. A target is
resolved against the folder of the file that holds it, then looked up in the tree of the revision.
Exit 0: no missing target. Exit 1: at least one missing target. Exit 2: a named file is not in the revision.
Usage: python3 -I -B check_links.py <revision> <file.md> [<file.md> ...]
"""
import json, posixpath, re, subprocess, sys
from pathlib import Path

FORGE = Path(__file__).resolve().parents[2]
revision, files = sys.argv[1], sys.argv[2:]
LINK = re.compile(r'\]\(([^)\s]+)\)')


def show(path):
    child = subprocess.run(['git', '-C', str(FORGE), 'show', revision + ':' + path], capture_output=True)
    return child.stdout.decode('utf-8') if child.returncode == 0 else None


def exists(path):
    return subprocess.run(['git', '-C', str(FORGE), 'cat-file', '-e', revision + ':' + path], capture_output=True).returncode == 0


report, missing_file = {}, False
for name in files:
    text = show(name)
    if text is None:
        report[name] = 'FILE NOT IN REVISION'
        missing_file = True
        continue
    targets = sorted({t.split('#', 1)[0] for t in LINK.findall(text) if not re.match(r'[a-zA-Z][a-zA-Z0-9+.-]*:', t)} - {''})
    resolved = {t: posixpath.normpath(posixpath.join(posixpath.dirname(name), t)).rstrip('/') for t in targets}
    report[name] = {'relative_links': len(targets), 'missing': [t for t in targets if not exists(resolved[t])]}
commit = subprocess.run(['git', '-C', str(FORGE), 'rev-parse', revision], capture_output=True, text=True).stdout.strip()
print(json.dumps({'revision': revision, 'commit': commit, 'files': report}, indent=1, sort_keys=True))
bad = any(isinstance(v, dict) and v['missing'] for v in report.values())
raise SystemExit(2 if missing_file else 1 if bad else 0)
