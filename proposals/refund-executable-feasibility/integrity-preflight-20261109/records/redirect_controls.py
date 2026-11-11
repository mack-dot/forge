"""Local HTTP-handler controls. No sockets, hosted jobs, or proof execution."""
from pathlib import Path
import ast
from email.message import Message
import hashlib
import importlib.util
import io
import json
import subprocess
import sys
import traceback
import urllib.request
import urllib.response

out = Path(__file__).resolve().parent
source = out / 'integrity_driver.py'
sha = lambda b: hashlib.sha256(b).hexdigest()

def child(case):
    spec = importlib.util.spec_from_file_location('integrity_under_review', source)
    driver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(driver)  # __main__ is not entered.
    tree = ast.parse(source.read_text())
    main = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'main')
    fetch = next(n for n in main.body if isinstance(n, ast.FunctionDef) and n.name == 'fetch')
    module = ast.fix_missing_locations(ast.Module(body=[fetch], type_ignores=[]))
    namespace = vars(driver)
    exec(compile(module, str(source), 'exec'), namespace)
    requests = []
    origin = 'https://raw.githubusercontent.com/mack-dot/forge/21c4bdf958627e6a24e8dee9a45d90568b3e3c20/proposals/m1-hosted-cf-inputs/INPUTS.json'
    expected_code = None if case == 'positive' else int(case.removeprefix('redirect-'))
    assert expected_code in (None, 301, 302, 303, 307, 308)

    class FakeHTTPS(urllib.request.HTTPSHandler):
        def https_open(self, request):
            requests.append(request.full_url)
            assert len(requests) == 1 and request.full_url == origin, 'unexpected follow-up request'
            headers = Message()
            if expected_code:
                headers['Location'] = 'https://outside-approved-scope.invalid/redirect-target'
            response = urllib.response.addinfourl(io.BytesIO(b'fixture bytes'), headers,
                                                  request.full_url, expected_code or 200)
            response.msg = 'Found' if expected_code else 'OK'
            return response

    real_build_opener = urllib.request.build_opener
    def local_opener(*handlers):
        assert len(handlers) == 1 and isinstance(handlers[0], driver.NoRedirect)
        return real_build_opener(*handlers, FakeHTTPS())
    urllib.request.build_opener = local_opener
    try:
        result = namespace['fetch'](origin, 64)
        assert expected_code is None and result == b'fixture bytes'
        print(json.dumps({'case': case, 'requests': requests, 'network_used': False, 'result': 'accepted expected bytes'}))
        return 0
    except ValueError as exc:
        assert expected_code is not None
        assert str(exc) == 'redirect refused before follow-up request'
        assert requests == [origin]
        print(json.dumps({'case': case, 'requests': requests, 'network_used': False,
                          'rejection': str(exc), 'follow_up_requests': 0}))
        traceback.print_exc()
        return 1
    finally:
        urllib.request.build_opener = real_build_opener

if len(sys.argv) == 2:
    raise SystemExit(child(sys.argv[1]))
results = []
for case in ['positive', 'redirect-301', 'redirect-302', 'redirect-303', 'redirect-307', 'redirect-308']:
    target = out / 'controls' / case
    target.mkdir(parents=True, exist_ok=False)
    argv = [sys.executable, '-B', str(Path(__file__).resolve()), case]
    p = subprocess.run(argv, capture_output=True)
    r = {'case': case, 'argv': argv, 'actual_exit': p.returncode,
         'expected_exit': 0 if case == 'positive' else 1}
    for name, data in [('stdout', p.stdout), ('stderr', p.stderr)]:
        (target / (name + '.log')).write_bytes(data)
        r[name + '_sha256'] = sha(data)
    (target / 'command.json').write_text(json.dumps(r, indent=2) + '\n')
    assert p.returncode == r['expected_exit'], r
    results.append(r)
r = {'actual_exit': 0, 'cases': results, 'network_used': False,
     'hosted_jobs_started': 0, 'proof_executed': False, 'end_to_end': False}
(out / 'REDIRECT-CONTROLS.json').write_text(json.dumps(r, indent=2) + '\n')
print(json.dumps(r))
