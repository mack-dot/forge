#!/usr/bin/env python3
"""Test of the video cut (Python stdlib only, plain asserts, no pytest). end_to_end=false.

It runs the 1-take runner as a subprocess (`--fast --flood-mb 16 --no-model --json <tmp>`) and checks the
exit code and the JSON dump. The runner takes the heavy lock for the take. Two negative controls prove
that this test can fail: (i) the same domain check exits 1 against a sabotaged engine; (ii) harness.Shot
marks a wrong observed answer as not ok.

  python3 demos/video_cut/test_video_cut.py [--node P] [--min-swap-free-mib N]

One line per check. Exit 0 if every check holds, else 1.
"""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import harness  # noqa: E402
from domains import ORDER  # noqa: E402

RUNNER = HERE / 'run_recording_take.py'
RESULTS = []


def check(name, ok, detail=''):
    RESULTS.append(bool(ok))
    print('%s | %s%s' % ('PASS' if ok else 'FAIL', name, (' | ' + str(detail)) if detail else ''), flush=True)
    return bool(ok)


def note(doc, domain, name):
    found = [n['value'] for n in doc['notes'] if n['domain'] == domain and n['name'] == name]
    return found[0] if len(found) == 1 else None


def unit_checks():
    """Negative control (ii): the harness marks a wrong observed answer as not ok."""
    wrong = harness.Shot('t', 'h', 'r', 'q', 'REJECTED_POLICY TOTAL_CAP', 'COMMITTED r1 epoch=2 x', 1.0, 'l')
    check('control (ii): Shot with a wrong observed answer is not ok', wrong.ok is False and wrong.as_dict()['result'] == 'FAIL')
    check('control (ii): that answer is classed ALLOWED (a commit where a refusal was required)', wrong.klass == 'ALLOWED')
    near = harness.Shot('t', 'h', 'r', 'q', 'REJECTED_POLICY RULE', 'REJECTED_POLICY RULE_OTHER', 1.0, 'l')
    check('control (ii): a longer token does not match the required start', near.ok is False and near.klass == 'BLOCKED')
    empty = harness.Shot('t', 'h', 'r', 'q', 'COMMITTED', '', 1.0, 'l')
    check('control (ii): an empty observed answer is not ok and not ALLOWED', empty.ok is False and empty.klass == 'BLOCKED')
    right = harness.Shot('t', 'h', 'r', 'q', 'REJECTED_POLICY RULE', 'REJECTED_POLICY RULE', 1.0, 'l')
    check('Shot with the required answer is ok', right.ok is True and right.klass == 'BLOCKED')


def take_checks(doc, code, names):
    shots = doc['shots']
    check('take: exit code 0', code == 0, 'exit %d' % code)
    check('take: no shot has result FAIL', all(s['result'] == 'PASS' for s in shots),
          '; '.join('%s/%s: OBSERVED %s' % (s['domain'], s['headline'], s['observed'][:80]) for s in shots if s['result'] != 'PASS'))
    check('take: nine domains ran', doc['take']['domains'] == names and len(names) == 9, doc['take']['domains'])
    for name in names:
        mine = [s for s in shots if s['domain'] == name]
        a = sum(1 for s in mine if s['class'] == 'ALLOWED' and s['result'] == 'PASS')
        b = sum(1 for s in mine if s['shown_as'] == 'BLOCKED' and s['result'] == 'PASS')  # an engine refusal code
        check('domain %s: at least one ALLOWED PASS and one BLOCKED PASS' % name, a >= 1 and b >= 1, 'allowed %d, blocked %d' % (a, b))
        # the owner's rule: a real COMMITTED valid action (the engine's own COMMITTED answer, not only OK or ACCEPT)
        c = sum(1 for s in mine if s['class'] == 'ALLOWED' and s['result'] == 'PASS' and s['observed'].startswith('COMMITTED '))
        check('domain %s: at least one COMMITTED answer and one BLOCKED answer' % name, c >= 1 and b >= 1, 'committed %d, blocked %d' % (c, b))
    # the race: observed counts (notes of d6, counted from the 50 answers) and the counted shot
    counts = (note(doc, 'saas', 'race: serve processes'), note(doc, 'saas', 'race: COMMITTED'), note(doc, 'saas', 'race: STALE_STATE_HASH'),
              note(doc, 'saas', 'race: other answers'), note(doc, 'saas', 'race: WAL effect records of the key'))
    check('race: 50 clients, 1 COMMITTED, 49 STALE_STATE_HASH, 0 other, 1 WAL record (OBSERVED)', counts == (50, 1, 49, 0, 1), counts)
    race = [s for s in shots if s['domain'] == 'saas' and s['observed'].startswith('50 racers: ')]
    check('race: the counted shot says the same and passed',
          len(race) == 1 and race[0]['result'] == 'PASS' and race[0]['observed'].startswith('50 racers: 1 COMMITTED, 49 STALE_STATE_HASH, 0 other'),
          race[0]['observed'] if race else 'no such shot')
    # SIGKILL recovery
    kill = [s for s in shots if s['domain'] == names[8] and any(w in (s['headline'] + ' ' + s['rule'] + ' ' + s['request']).upper() for w in ('SIGKILL', 'RECOVER'))]
    check('SIGKILL recovery: its shots exist and passed', len(kill) >= 1 and all(s['result'] == 'PASS' for s in kill),
          '%d shots: %s' % (len(kill), [s['headline'] for s in kill]))
    # the sabotage check of the take
    sab, good = note(doc, 'proof', 'sabotage_check_exit'), note(doc, 'proof', 'unsabotaged_check_exit')
    check('take: sabotage check exit code 1 (notes)', sab == 1, sab)
    check('take: unsabotaged check exit code 0 (notes)', good == 0, good)
    check('take: every extra check held', all(c['ok'] for c in doc['take']['checks']) and len(doc['take']['checks']) == 3, doc['take']['checks'])
    check('take: the live model was not in this take', doc['take']['model']['in_take'] is False)
    check('take: flood size 16 MiB', doc['take']['flood_mb'] == 16)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--node')
    ap.add_argument('--min-swap-free-mib', type=int, default=1024 if harness.LOCK_BASE.is_dir() else 0,
                    help='wait for this much free swap before the heavy take (default 1024 on the shared machine, else 0)')
    ap.add_argument('--lock-wait-min', type=int, default=0)
    ap.add_argument('--keep-output', help='copy the output and the JSON of the take to this folder')
    args = ap.parse_args()
    node = harness.find_node(args.node)
    unit_checks()
    tmp = Path(tempfile.mkdtemp(prefix='video-cut-test-'))
    try:
        base = [sys.executable, '-B', str(RUNNER), '--node', node, '--no-color']
        # a light control first: a subset is PARTIAL (exit 3), never a full pass
        p = subprocess.run(base + ['--fast', '--no-model', '--domains', 'robotics'], capture_output=True, text=True, timeout=600)
        check('runner: a subset take is PARTIAL (exit 3)', p.returncode == 3, 'exit %d' % p.returncode)
        p = subprocess.run(base + ['--fast', '--no-model', '--flood-mb', '65'], capture_output=True, text=True, timeout=600)
        check('runner: a flood above 64 MiB is refused (exit 2)', p.returncode == 2 and '10240' in p.stdout, 'exit %d' % p.returncode)
        # the take (heavy: the runner takes the lock and waits for swap)
        out_json, sab_dir = tmp / 'take.json', tmp / 'sabotaged-engine'
        cmd = base + ['--fast', '--flood-mb', '16', '--no-model', '--json', str(out_json), '--sabotage-dir', str(sab_dir),
                      '--min-swap-free-mib', str(args.min_swap_free_mib), '--lock-wait-min', str(args.lock_wait_min)]
        p = subprocess.run(cmd, capture_output=True, text=True)
        (tmp / 'take.out').write_text(p.stdout + p.stderr)
        if args.keep_output:
            Path(args.keep_output).mkdir(parents=True, exist_ok=True)
            for f in (tmp / 'take.out', out_json):
                if f.is_file():
                    shutil.copyfile(f, Path(args.keep_output) / f.name)
        if not out_json.is_file():
            check('take: the runner wrote the JSON dump', False, 'exit %d; last lines: %s' % (p.returncode, (p.stdout + p.stderr).strip().split('\n')[-6:]))
        else:
            doc = json.loads(out_json.read_text())
            names = [n for n in doc['take']['domains']]
            check('take: the domains are in the order of ORDER', [n for n in names] == [f.split('_', 1)[1] for f in ORDER], names)
            take_checks(doc, p.returncode, names)
            if p.returncode != 0:
                print('\n'.join((p.stdout + p.stderr).strip().split('\n')[-25:]))
            # negative control (i): the same check against the sabotaged engine of the take, run again here
            if (sab_dir / 'airlock-engine').is_file():
                bad = subprocess.run(base + ['--check-domain', 'treasury', '--engine-dir', str(sab_dir)], capture_output=True, text=True, timeout=600)
                check('control (i): --check-domain treasury exits 1 against the sabotaged engine', bad.returncode == 1,
                      'exit %d; %s' % (bad.returncode, [ln for ln in bad.stdout.split('\n') if ln.startswith('FAIL')][:2]))
                good = subprocess.run(base + ['--check-domain', 'treasury'], capture_output=True, text=True, timeout=600)
                check('control (i): the same check exits 0 against the unsabotaged engine', good.returncode == 0, 'exit %d' % good.returncode)
            else:
                check('control (i): the sabotaged engine of the take exists', False, str(sab_dir))
    finally:
        shutil.rmtree(tmp, ignore_errors=True)
    bad = RESULTS.count(False)
    print('%d checks, %d failed' % (len(RESULTS), bad))
    return 1 if bad else 0


if __name__ == '__main__':
    sys.exit(main())
