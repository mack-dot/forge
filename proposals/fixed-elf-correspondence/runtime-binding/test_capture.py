"""Test-only record comparator. This does not certify freshness or provenance."""
import importlib.util,json,sys
from pathlib import Path
spec=importlib.util.spec_from_file_location('bound_observation',Path(__file__).with_name('run_bound_observation.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
try:
    result=module.bind_capture(Path(sys.argv[1]))
    print(json.dumps({'record_comparison_only':True,'freshness_claimed':False,'result':result}))
except (module.Refusal,OSError,ValueError) as error:
    print(str(error),file=sys.stderr)
    raise SystemExit(1)
