import sys, os
sys.dont_write_bytecode = True
BASE = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'base')
sys.path.insert(0, os.path.join(BASE, 'gate'))
import approval, incremental, obligations
print('--- in-process modules of the PR gate loaded from gate/ (after import incremental):')
loaded = sorted(os.path.relpath(m.__file__, BASE) for m in list(sys.modules.values())
                if getattr(m, '__file__', None) and m.__file__.startswith(BASE))
import core  # imported lazily inside incremental.check()
loaded = sorted(set(loaded) | {'gate/core.py'})
covered = obligations.all_inputs()
for name in loaded:
    print('%-32s ratifiable=%-5s obligation_input=%s' % (name, approval._ratifiable(name), name in covered))
print('--- _ratifiable table')
names = ['gate/incremental.py', 'gate/Incremental.py', 'gate/INCREMENTAL.PY', 'gate/common.py', 'gate/common/__init__.py',
         'gate/approval/__init__.py', 'gate/incremental/__init__.py', 'gate/common.so', 'gate/common.cpython-310-darwin.so',
         'gate/common.pyc', 'gate/json.py', 'gate/yaml.py', 'gate/jsonschema/__init__.py', 'gate/provenance.py',
         'gate/provenance/common.py', 'gate/Provenance/common.py', 'gate/approvals/x.json', 'gate/Approvals/x.json',
         'gate/approvals.json', 'gate/core.py', 'gate/dependencies.py', 'gate/backends/__init__.py', 'gate/backends/dafny.py',
         'gate/gate.py', 'toolchain/install_ci.py', 'toolchain/requirements-linux.txt', 'toolchain/linux-pins.json',
         'governance/gate-ratifications/x.json', 'governance/x', '.github/workflows/proof-gate.yml', 'spec.lock',
         'spec/refund/spec.lock', 'policy/tiers.yaml', 'gate/obligationſ.py', 'gate/pr_checK.py',
         'gate/ratiﬁcation.py', 'gate/poﬆ_pr_report.py', 'gate/ıncremental.py', 'gate/pr_check.py ',
         'gate/pr_check.py​', 'scripts/build_model.py', 'AGENTS.md']
for name in names:
    print('%-45r ratifiable=%-5s obligation_input=%s' % (name, approval._ratifiable(name), name in covered))
