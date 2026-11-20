#!/usr/bin/env python3
"""Spec clearing of the PROPOSED RefundLogSpec, by import of scripts/spec_clearing.py (unchanged).

As src/primitives_v2/py/policy_to_dfy.py does: no file goes under clearing/ (a new file there changes the Slice 2
bundle), and clearing/subjects.json is not read. The subject is built here and given to clear_spec.

usage: clear_log_spec.py <checkout> <new work folder> [--wait-slot]
  <checkout>: a checkout of this repository that holds `.toolchain/` (the pinned Dafny) and
              `scripts/spec_clearing.py` with the same bytes as this tree's copy. Dafny runs with that folder as
              its working folder (the gate options name the solver by a relative path).
  --wait-slot: before each Dafny run, wait until no other proof process runs for 3 checks one minute apart.
Exit 0: verdict NO_CHOICE and acceptance ACCEPTS. Exit 1: any other result. Exit 2: usage.
"""

import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time

sys.dont_write_bytecode = True
HERE = Path(__file__).resolve().parent
TREE = HERE.parents[1]
SLOT = re.compile(r'dafny/dafny|Holmake|z3-4\.12\.1|run_regression_copy|exit_goal20_sdk')
QUIET = ('sh', 'bash', 'zsh', 'pgrep', 'grep', 'ps', 'tail', 'sleep')


def slot_busy():
    out = subprocess.run(['ps', '-ax', '-o', 'pid=,command='], capture_output=True, text=True).stdout
    for line in out.splitlines():
        pid, _, cmd = line.strip().partition(' ')
        first = os.path.basename(cmd.split(' ', 1)[0]).lstrip('-')
        if pid.isdigit() and int(pid) != os.getpid() and first not in QUIET and SLOT.search(cmd):
            return True
    return False


def wait_slot(log):
    start, free = time.time(), 0
    while free < 3:
        free = 0 if slot_busy() else free + 1
        if free < 3:
            time.sleep(60)
    log.append(int(time.time() - start))


def main():
    args = [a for a in sys.argv[1:] if a != '--wait-slot']
    if len(args) != 2:
        print(__doc__, file=sys.stderr)
        return 2
    checkout, work = Path(args[0]).resolve(), Path(args[1]).resolve()
    if work.exists():
        print('the work folder must be new', file=sys.stderr)
        return 2
    mine = (TREE / 'scripts/spec_clearing.py').read_bytes()
    theirs = (checkout / 'scripts/spec_clearing.py').read_bytes()
    if mine != theirs:
        print('scripts/spec_clearing.py of the checkout differs from this tree', file=sys.stderr)
        return 2
    sys.path.insert(0, str(checkout / 'scripts'))
    import spec_clearing as sc  # noqa: E402  (unchanged; its ROOT is the checkout)

    waited = []

    class SlotTool(sc.Tool):
        def run(self, argv, label):
            if '--wait-slot' in sys.argv:
                wait_slot(waited)
            return super().run(argv, label)

    def rel(name):
        return os.path.relpath(HERE / name if '/' not in name else TREE / name, sc.ROOT)

    spec, lemmas, instance, refund = (rel('RefundLogSpec.dfy'), rel('RefundLogSpecLemmas.dfy'),
                                      rel('RefundLogSpecInstance.dfy'), rel('impl/Refund.dfy'))
    bound = [['RefundLogClaim', {'S': 'RefundLogByStep'}], ['RefundLogSpecLemmas', {'S': 'RefundLogByStep'}]]
    lemma = 'RefundLogSpecLemmas.%s (correctness)'
    subject = {
        'id': 'refund-log-proposal', 'title': 'PROPOSED stateful refund-log specification (not approved)',
        'spec': spec, 'planted': False,
        'claim': {'files': [lemmas], 'member': 'RefundLogClaim.NoChoice (correctness)'},
        'proof': {'files': [lemmas, instance], 'instances': bound,
                  'members': ['RefundLogClaim.NoChoice (correctness)', 'RefundLogClaim.DecideThenPost (correctness)']
                  + [lemma % m for m in ('StepIsDecidePost', 'EffectIsUnique', 'DecidePostIsStep',
                                         'AllowedIsApprovedEligible', 'ApprovedAssessAgrees', 'Conservation',
                                         'AtMostOnceHolds', 'ReplayInvariant', 'PrefixIsValid', 'RepeatedIdIsRefused')]},
        'acceptance': {'purpose': 'a concrete valid history of two refunds from a valid genesis',
                       'files': [lemmas, instance], 'instances': bound,
                       'members': [lemma % 'AcceptedHistoryOfTwo']},
        'candidates': [],
        'spec_probe': {'files': [spec, refund], 'modules': [['RefundLogSpec', {'R': 'Refund'}]],
                       'open': ['RefundLogSpec.Decide']},
    }
    tool = SlotTool(work / 'clearing')
    record = sc.clear_spec(tool, subject, work / 'generated')
    short = {'subject': subject['id'], 'verdict': record['verdict'],
             'acceptance': record.get('acceptance', {}).get('result'),
             'claim': {k: record['claim'][k] for k in ('audit_exit', 'checker_exit', 'failed', 'refused', 'members')},
             'proof_passed': (record['proof'] or {}).get('passed'),
             'proof_members': (record['proof'] or {}).get('members'),
             'spec_probe_passed': (record['spec_probe'] or {}).get('passed'),
             'spec_probe_without_body': (record['spec_probe'] or {}).get('without_body'),
             'commands': [{'name': c['name'], 'exit_code': c['exit_code']} for c in tool.commands],
             'slot_waits_seconds': waited,
             'spec_clearing_sha256': hashlib.sha256(theirs).hexdigest(),
             'source': 'scripts/spec_clearing.py clear_spec (imported, unchanged); subject built by clear_log_spec.py'}
    (work / 'clearing-record.json').write_text(json.dumps(record, sort_keys=True, indent=1, default=str) + '\n')
    (work / 'summary.json').write_text(json.dumps(short, sort_keys=True, indent=1) + '\n')
    print(json.dumps(short, sort_keys=True, indent=1))
    return 0 if record['verdict'] == 'NO_CHOICE' and short['acceptance'] == 'ACCEPTS' else 1


if __name__ == '__main__':
    sys.exit(main())
