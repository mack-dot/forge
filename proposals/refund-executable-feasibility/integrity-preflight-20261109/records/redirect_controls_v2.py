"""Controls use fake HTTPS responses. They never open a network socket."""
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
import urllib.error
import urllib.request
import urllib.response

out = Path(__file__).resolve().parent
old_source = Path('/Users/mackianni/forge/proposals/refund-executable-feasibility/integrity-preflight-20261108/records/integrity_driver.py')
sha = lambda b: hashlib.sha256(b).hexdigest()

def child(case):
    baseline = case == 'original-302'
    source = old_source if baseline else out / 'integrity_driver.py'
    spec = importlib.util.spec_from_file_location('integrity_under_review', source)
    driver = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(driver)
    tree = ast.parse(source.read_text())
    main = next(n for n in tree.body if isinstance(n, ast.FunctionDef) and n.name == 'main')
    fetch = next(n for n in main.body if isinstance(n, ast.FunctionDef) and n.name == 'fetch')
    module = ast.fix_missing_locations(ast.Module(body=[fetch], type_ignores=[]))
    namespace = vars(driver)
    exec(compile(module, str(source), 'exec'), namespace)
    requests = []
    origin = 'https://raw.githubusercontent.com/mack-dot/forge/21c4bdf958627e6a24e8dee9a45d90568b3e3c20/proposals/m1-hosted-cf-inputs/INPUTS.json'
    outside = 'https://outside-approved-scope.invalid/redirect-target'
    code = 302 if baseline else None if case == 'positive' else int(case.removeprefix('redirect-'))
    assert code in (None, 301, 302, 303, 307, 308)

    class FollowUpDetected(Exception):
        pass

    class FakeHTTPS(urllib.request.HTTPSHandler):
        def https_open(self, request):
            requests.append(request.full_url)
            if len(requests) > 1:
                raise FollowUpDetected('redirect handler attempted a follow-up URL')
            assert request.full_url == origin
            headers = Message()
            if code:
                headers['Location'] = outside
            response = urllib.response.addinfourl(io.BytesIO(b'fixture bytes'), headers,
                                                  request.full_url, code or 200)
            response.msg = 'Found' if code else 'OK'
            return response

    real_build_opener = urllib.request.build_opener
    real_urlopen = urllib.request.urlopen
    def local_opener(*handlers):
        assert len(handlers) == 1 and isinstance(handlers[0], driver.NoRedirect)
        return real_build_opener(*handlers, FakeHTTPS())
    if baseline:
        urllib.request.urlopen = real_build_opener(FakeHTTPS()).open
    else:
        urllib.request.build_opener = local_opener
    common = {'case': case, 'network_used': False, 'source_sha256': sha(source.read_bytes())}
    try:
        result = namespace['fetch'](origin, 64)
        assert code is None and result == b'fixture bytes' and requests == [origin]
        print(json.dumps(dict(common, requests=requests, result='accepted expected bytes', follow_up_requests=0)))
        return 0
    except FollowUpDetected:
        assert baseline and requests == [origin, outside]
        print(json.dumps(dict(common, requests=requests, result='original attempted follow-up URL', follow_up_requests=1)))
        traceback.print_exc()
        return 1
    except (ValueError, urllib.error.HTTPError) as exc:
        assert not baseline and code is not None and requests == [origin]
        if isinstance(exc, urllib.error.HTTPError):
            assert exc.code == 308 and code == 308
            reason = 'HTTP 308 rejected by this Python runtime before any follow-up request'
        else:
            assert str(exc) == 'redirect refused before follow-up request'
            reason = str(exc)
        print(json.dumps(dict(common, requests=requests, result=reason, follow_up_requests=0)))
        traceback.print_exc()
        return 1
    finally:
        urllib.request.build_opener = real_build_opener
        urllib.request.urlopen = real_urlopen

if len(sys.argv) == 2:
    raise SystemExit(child(sys.argv[1]))
results = []
for case in ['original-302', 'positive', 'redirect-301', 'redirect-302', 'redirect-303', 'redirect-307', 'redirect-308']:
    target = out / 'controls-v2' / case
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
    evidence = json.loads(p.stdout.decode().splitlines()[-1])
    assert evidence['case'] == case and evidence['network_used'] is False
    assert evidence['follow_up_requests'] == (1 if case == 'original-302' else 0)
    assert len(evidence['requests']) == (2 if case == 'original-302' else 1)
    if case == 'positive':
        assert evidence['result'] == 'accepted expected bytes'
    elif case == 'original-302':
        assert evidence['result'] == 'original attempted follow-up URL'
    else:
        assert evidence['result'] in ('redirect refused before follow-up request',
                                     'HTTP 308 rejected by this Python runtime before any follow-up request')
    r['checked_evidence'] = evidence
    results.append(r)
r = {'actual_exit': 0, 'cases': results, 'python_version': sys.version,
     'network_used': False, 'hosted_jobs_started': 0, 'proof_executed': False,
     'prior_harness_limit': 'Version1 checked exit codes only; its308 stderr was HTTPError,without the expected result record.',
     'end_to_end': False}
(out / 'REDIRECT-CONTROLS-V2.json').write_text(json.dumps(r, indent=2) + '\n')
print(json.dumps({'actual_exit': 0, 'cases': [{k: v for k, v in r.items() if k in ('case', 'actual_exit', 'checked_evidence')} for r in results],
                  'network_used': False, 'end_to_end': False}))
