"""Phase 2 (part B): recompute the file comparison of every step from the files on disk. Separate from driver.py.

Usage: python3 -I -B recheck_phase2.py     (writes comparison-phase2.json, prints one line per step)

For a theory step it reads the fresh <theory>Theory.{sig,sml,dat} and compares SHA-256 values with
the values in the OLD record of the packet (read here directly from the packet, not from plan.json).
  equal               = the .dat file (theorem statements, definitions, types) AND the .sig file
                        are byte-identical to the recorded ones
  different           = a recorded hash exists and the fresh .dat or .sig differs
  no stored statement = the packet record holds no hash of the theory files
This is a comparison of files. It is not a proof check.
"""
from pathlib import Path
import hashlib, json, os, re

ROOT = Path('<HOME>/forge')
OUT = Path(__file__).resolve().parent.parent
plan = {'steps': json.loads((OUT / 'plan-phase2.json').read_text())['B']['steps']}
status = json.loads((OUT / 'status.json').read_text())['steps'] if (OUT / 'status.json').exists() else {}


def sha(path):
    digest = hashlib.sha256()
    with open(path, 'rb') as handle:
        for block in iter(lambda: handle.read(1 << 20), b''):
            digest.update(block)
    return digest.hexdigest()


result = {}
for s in plan['steps']:
    st = status.get(s['id'], {})
    theory = s['theory']
    entry = {'theory': theory, 'status': st.get('status', 'NOT_REACHED')}
    if theory and st.get('status') == 'REPLAYED':
        old = json.loads((ROOT / s['recorded']['record']).read_text())
        objs = old.get('objects') or old.get('object_sha256') or {}
        objs = {Path(k).name: v for k, v in objs.items()}
        d = ROOT / (s['cwd'] + '/.hol/objs' if s['kind'] == 'holmake' else s['run_folder'] + '/' + s['case'] + '/.hol/objs')
        files = {}
        for suffix in ('sig', 'sml', 'dat'):
            name = theory + 'Theory.' + suffix
            f = d / name
            files[suffix] = {'fresh': sha(f) if f.is_file() else None, 'recorded': objs.get(name), 'bytes': f.stat().st_size if f.is_file() else None}
            files[suffix]['equal'] = None if objs.get(name) is None or not f.is_file() else files[suffix]['fresh'] == objs.get(name)
        sig = (d / (theory + 'Theory.sig')).read_text(errors='replace') if (d / (theory + 'Theory.sig')).is_file() else ''
        entry['exported_thm_names'] = len(re.findall(r'^\s*val\s+[A-Za-z0-9_\']+\s*:\s*thm\b', sig, re.M))
        entry['files'] = files
        if files['dat']['recorded'] is None and files['sig']['recorded'] is None:
            entry['comparison'] = 'no stored statement'
        elif files['dat']['equal'] and files['sig']['equal'] is not False:
            entry['comparison'] = 'equal'
        else:
            entry['comparison'] = 'different'
            entry['different_files'] = [k for k, v in files.items() if v['equal'] is False]
    elif not theory and st.get('status') == 'REPLAYED':
        entry['comparison'] = st.get('statement_comparison')
        entry['stdout_vs_packet'] = st.get('stdout_vs_packet')
    result[s['id']] = entry
    print('%-28s %-30s %-20s %-20s %s' % (s['id'], theory or '(import check)', entry['status'], entry.get('comparison'),
                                           entry.get('different_files', '')))
tmp = OUT / 'comparison-phase2.json.tmp'
tmp.write_text(json.dumps(result, indent=1) + '\n')
os.replace(tmp, OUT / 'comparison-phase2.json')
