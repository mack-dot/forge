"""Offline controls for GitHub token handling in common.fetch (v3.4 versus v3.5).

  python3 -I -B token_controls.py CODE_DIR VERSION OUTPUT

CODE_DIR holds the common.py under test. A local HTTP server on 127.0.0.1
answers with the status named in the path and keeps only a digest of the
Authorization header it receives. Every token is synthetic. Exit 0 when every
case gets the outcome expected for VERSION.
"""
import base64
import hashlib
import http.server
import json
import os
from pathlib import Path
import random
import sys
import threading
import urllib.error

CODE, VERSION, OUT = sys.argv[1], sys.argv[2], Path(sys.argv[3]).resolve()
sys.path.insert(0, CODE)
import common  # noqa: E402

seen = {}


class Handler(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        auth = self.headers.get('Authorization', '')
        seen[self.path] = {'sha256': hashlib.sha256(auth.encode()).hexdigest(), 'length': len(auth),
                           'extra_headers': sorted(k for k in self.headers if k.lower().startswith('x-'))}
        code = int(self.path.split('/')[2])
        body = json.dumps({'ok': code == 200}).encode()
        self.send_response(code)
        self.send_header('Content-Type', 'application/json')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *args):
        pass


server = http.server.ThreadingHTTPServer(('127.0.0.1', 0), Handler)
threading.Thread(target=server.serve_forever, daemon=True).start()
BASE = 'http://127.0.0.1:%d' % server.server_address[1]
rng = random.Random(20261029)


def b64(n):
    return base64.urlsafe_b64encode(bytes(rng.randrange(256) for _ in range(n))).rstrip(b'=').decode()


def stateless(total):
    # Shape of GitHub's stateless installation token: ghs_<APPID>_<JWT header.payload.signature>.
    head, sig = b64(27), b64(256)
    prefix = 'ghs_1234567_' + head + '.'
    payload_len = total - len(prefix) - 1 - len(sig)
    return prefix + b64(payload_len)[:payload_len] + '.' + sig


ALNUM = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
legacy = 'ghs_' + ''.join(rng.choice(ALNUM) for _ in range(36))
oauth = 'gho_' + ''.join(rng.choice(ALNUM) for _ in range(36))
pat = 'github_pat_' + ''.join(rng.choice(ALNUM + '_') for _ in range(82))
s520 = stateless(520)
R = 'GITHUB_TOKEN_REQUIRED:FORGE_TEST_TOKEN'
# (name, token or None for unset, status served, expected v3.4, expected v3.5)
CASES = [
    ('legacy ghs_ 40 chars', legacy, 200, 'ACCEPTED', 'ACCEPTED'),
    ('oauth gho_ 40 chars', oauth, 200, 'ACCEPTED', 'ACCEPTED'),
    ('fine-grained github_pat_ 93 chars', pat, 200, 'ACCEPTED', 'ACCEPTED'),
    ('stateless ghs_ JWT 520 chars (R2 shape)', s520, 200, R, 'ACCEPTED'),
    ('stateless 1000 chars', stateless(1000), 200, R, 'ACCEPTED'),
    ('stateless 2048 chars', stateless(2048), 200, R, 'ACCEPTED'),
    ('stateless 4096 chars (upper bound)', stateless(4096), 200, R, 'ACCEPTED'),
    ('stateless 4097 chars (over bound)', stateless(4097), 200, R, R),
    ('unset', None, 200, R, R),
    ('empty', '', 200, R, R),
    ('19 chars', legacy[:19], 200, R, R),
    ('trailing LF', s520 + '\n', 200, R, R),
    ('CRLF header injection', legacy + '\r\nX-Injected: yes', 200, R, R),
    ('embedded space', legacy[:20] + ' ' + legacy[20:], 200, R, R),
    ('tab', legacy + '\t', 200, R, R),
    ('NUL (cannot be placed in the environment)', legacy + '\x00', 200, 'ENVIRONMENT_REJECTS_VALUE', 'ENVIRONMENT_REJECTS_VALUE'),
    ('DEL', legacy + '\x7f', 200, R, R),
    ('non-ASCII', legacy + 'é', 200, R, R),
    ('Unicode line separator', legacy + ' ', 200, R, R),
    ('double quotes around the token', '"' + legacy + '"', 200, R, R),
    ('comma', legacy + ',x', 200, R, R),
    ('semicolon', legacy + ';x', 200, R, R),
    ('backslash', legacy + '\\x', 200, R, R),
    ('parentheses', legacy + '()', 200, R, R),
    ('= inside the token', legacy[:20] + '=' + legacy[20:], 200, R, R),
    ('trailing = padding', legacy + '==', 200, R, 'ACCEPTED'),
    ('RFC 6750 punctuation ~ + / . -', legacy + '~+/.-', 200, R, 'ACCEPTED'),
    ('hyphen token ghp- (earlier c10 control)', 'ghp-' + 'a' * 36, 200, R, 'ACCEPTED'),
    ('stateless + HTTP 401', s520, 401, R, 'GITHUB_HTTP_STATUS:401'),
    ('stateless + HTTP 403', s520, 403, R, 'GITHUB_HTTP_STATUS:403'),
    ('stateless + HTTP 404', s520, 404, R, 'GITHUB_HTTP_STATUS:404'),
    ('stateless + HTTP 503', s520, 503, R, 'GITHUB_HTTP_STATUS:503'),
    ('legacy + HTTP 401', legacy, 401, 'GITHUB_HTTP_STATUS:401', 'GITHUB_HTTP_STATUS:401'),
    ('stateless + API unavailable (connection refused)', s520, None, R, 'EXCEPTION:URLError'),
]
OUT.mkdir(parents=True, exist_ok=False)
results = []
for n, (name, token, status, exp34, exp35) in enumerate(CASES):
    expected = exp34 if VERSION == 'v3.4' else exp35
    try:
        if token is None:
            os.environ.pop('FORGE_TEST_TOKEN', None)
        else:
            os.environ['FORGE_TEST_TOKEN'] = token
    except ValueError:
        # The operating system cannot hold this value in an environment variable.
        results.append({'case': name, 'token_length': len(token), 'status_served': status, 'expected': expected,
                        'observed': 'ENVIRONMENT_REJECTS_VALUE', 'request_sent': False,
                        'header_equals_bearer_token': False, 'pass': expected == 'ENVIRONMENT_REJECTS_VALUE'})
        print('PASS' if results[-1]['pass'] else 'FAIL', '|', VERSION, '|', name, '| expected', expected,
              '| observed ENVIRONMENT_REJECTS_VALUE', flush=True)
        continue
    path = '/status/%d/%02d' % (status or 200, n)
    url = (BASE + path) if status else 'http://127.0.0.1:9/unavailable'
    try:
        common.fetch(url, common.Records(OUT / ('case-%02d' % n)), 'response', token_name='FORGE_TEST_TOKEN')
        observed = 'ACCEPTED'
    except common.Rejected as error:
        observed = error.reason
    except (urllib.error.URLError, OSError, ValueError) as error:
        observed = 'EXCEPTION:' + type(error).__name__
    got = seen.get(path)
    header_exact = got is not None and got['sha256'] == hashlib.sha256(('Bearer ' + (token or '')).encode()).hexdigest()
    ok = observed == expected and (observed != 'ACCEPTED' or (header_exact and got['extra_headers'] == []))
    results.append({'case': name, 'token_length': None if token is None else len(token), 'status_served': status,
                    'expected': expected, 'observed': observed, 'request_sent': got is not None,
                    'header_equals_bearer_token': header_exact, 'pass': ok})
    print('PASS' if ok else 'FAIL', '|', VERSION, '|', name, '| expected', expected, '| observed', observed,
          '| sent', got is not None, flush=True)
os.environ.pop('FORGE_TEST_TOKEN', None)
server.shutdown()
tokens = [c[1] for c in CASES if c[1]]
leaks = sorted(str(p.relative_to(OUT)) for p in OUT.rglob('*') if p.is_file()
               and any(t.encode() in p.read_bytes() for t in tokens))
(OUT / 'results.json').write_text(json.dumps({'version': VERSION, 'results': results, 'files_containing_a_token': leaks,
                                              'end_to_end': False}, indent=2) + '\n')
bad = [r for r in results if not r['pass']]
print('cases', len(results), 'not passing', len(bad), '| files containing a token:', len(leaks))
sys.exit(1 if bad or leaks else 0)
