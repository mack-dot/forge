"""Check a `Holmake -n` log before the real upstream build. Read-only on the tool tree.

Usage: python3 -I -B dryrun_check.py <dry-run log> <out.json> <forbid-pattern file>

Lists the output files that Holmake plans to make. Fails (exit 1) if a planned output file
already exists on disk or is in tooltree-listing-before.json: that would be a rebuild of an
existing built file, which is not allowed. Writes one regular expression that matches a
Holmake progress line of any theory that is NOT in the plan (used to stop the real run).
"""
from pathlib import Path
import json, os, re, sys

TC = Path('<HOME>/forge/.toolchain/experiments/refund-cakeml-20261104')
OUT = Path(__file__).resolve().parent.parent
listing = json.loads((OUT / 'tooltree-listing-before.json').read_text())['files']
planned, existing, other = [], [], []
for line in Path(sys.argv[1]).read_text(errors='replace').splitlines():
    line = re.sub(r'\x1b\[[0-9;]*m', '', line)
    m = re.match(r'Holmake: (\$\((HOLDIR|CAKEMLDIR)\)\S*) - (\S+)$', line)
    if m:
        d = m.group(1).replace('$(HOLDIR)', 'HOL').replace('$(CAKEMLDIR)', 'cakeml')
        name = m.group(3)
        planned.append(d + '/' + name)
        for cand in (TC / d / '.hol/objs' / name, TC / d / name):
            rel = str(cand.relative_to(TC))
            if cand.exists() or rel in listing:
                existing.append(rel)
    elif not line.startswith('Holmake: Scanning') and line.strip():
        other.append(line[:300])
theories = sorted({Path(p).name[:-len('Theory.uo')] for p in planned if p.endswith('Theory.uo')})
objects = sorted(p for p in planned if not re.search(r'Theory\.(sml|dat|sig|ui|uo)$', p))
result = {'dry_run_log': sys.argv[1].replace(str(Path.home()), '<HOME>'), 'planned_files': len(planned),
          'planned_theories': theories, 'planned_other_objects': objects,
          'planned_outputs_that_already_exist': sorted(set(existing)), 'other_log_lines': other[:40],
          'ok_new_files_only': not existing}
Path(sys.argv[2]).write_text(json.dumps(result, indent=1) + '\n')
names = '|'.join(re.escape(t) for t in theories) or 'NO_PLANNED_THEORY'
# Holmake -j1 prints "Holmake: Linking <dir>/<name>Script.uo to produce theory-builder ..." when it starts a theory.
Path(sys.argv[3]).write_text(r'Holmake: Linking \S*/(?!(?:' + names + r')Script\.uo)[A-Za-z0-9_]+Script\.uo' + '\n' +
                             r'^(?!(?:' + names + r')Theory\b)[A-Za-z0-9_]+Theory\s' + '\n')
print(json.dumps({k: result[k] for k in ('planned_theories', 'planned_other_objects', 'planned_outputs_that_already_exist', 'ok_new_files_only')}, indent=1))
raise SystemExit(0 if not existing else 1)
