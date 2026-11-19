#!/usr/bin/env python3
"""Wave Gate 1: EXIT checks of the conformance between the M1 refund executable and the Slice 1 Dafny refund checker.

Two stacks decide the same refund question:
  M1       the CakeML refund program as the tracked ARM64 Mach-O executable (SHA-256 b8ed5ec2...7bb8)
  Slice 1  impl/Refund.dfy (Assess) and impl/RefundFinality.dfy (Check), compiled to JavaScript by the pinned Dafny

This script makes one vector corpus, gives every TYPED vector to both stacks, and compares the answers:
accept or reject, amount, reason, charge id, request id and intent count. Changed wire inputs and the
recorded fixture inputs go to M1 only; their expected bytes come from the other stack or from the records.

What a pass means: on the recorded finite corpus the two stacks gave the same answers. It is a FINITE TEST.
It is NOT a proof of the JavaScript, NOT a compiler proof, NOT a proof of the executable, and it adds
nothing to M1. end_to_end stays false. The bundle is a RECORD, not gate evidence.

The script starts the tools and compares bytes. Three small pieces of code in it are transcriptions and
are NOT proved: the S-expression renderer (checked against the 22 HOL-written fixtures), the reference
predicate `reference_eligible` (a third opinion, from the HOL definition eligible_def), and the comparison.

Raw outputs go to build/m1-conformance/ (ignored by git). Nothing is written under results/.

Cases:
  conformance      compile the core; run every vector on both stacks and on the issuer process; 0 findings
  record-controls  planted faults in the records of each side: each must be found by its own check
  core-controls    25 wrong Dafny cores: the comparison must report each; Dafny must not prove the 16 wrong decisions
  m1-audit         table of the M1 replay steps that are not run, from the tracked replay records (no HOL run)
  evidence         all four, twice, in fresh folders; the two bundles are byte-identical
"""

import argparse
from concurrent.futures import ThreadPoolExecutor
import copy
import json
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import traceback

sys.dont_write_bytecode = True
ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'gate'))
sys.path.insert(0, str(ROOT))
from common import canonical, digest, pin_file, read_json  # noqa: E402
from backends import dafny  # noqa: E402  (the gate's own Dafny path and options)

EXECUTABLE = 'proposals/forge2-m1-conformance/artifacts/refund-arm64-macho'
EXECUTABLE_SHA256 = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
RECORDED = 'tests/m1-conformance/recorded-m1-cases.json'
DRIVER = 'tests/m1-conformance/driver.cjs'
FIXTURES = 'tests/m1-conformance/fixtures'
SLICE1_RECORD = 'proposals/forge2-slice1-refund-finality/records/evidence.json'
SLICE1_FIXTURES = 'tests/refund-finality/fixtures'
REPLAY_PLAN = 'proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/plan-phase2.json'
REPLAY_BUDGET = 'proposals/refund-executable-feasibility/m1-chain-replay-20261118/records/budget-phase2.json'
CORE = 'impl/RefundFinality.dfy'
ISSUER = 'ts/refund-finality/minter.ts'
SPEC_LOCK = 'spec/refund/spec.lock'
FOOTER = b'\nmodule.exports = { RefundFinality, Refund, runtime: _dafny };\n'
M1_ENVIRONMENT = {'PATH': '/usr/bin:/bin', 'LANG': 'C', 'LC_ALL': 'C', 'CML_HEAP_SIZE': '256', 'CML_STACK_SIZE': '256'}
MAX_MONEY = 9223372036854775807
APPROVED_REASONS = ['duplicate_charge', 'service_not_delivered', 'returned_item']
REJECTED_BYTES = b'(refund-result-v1 False 0 "" "" "" 0)'
AUTHORIZED_PREFIX = b'(refund-result-v1 True '
ISSUER_MAX_TEXT = 256
RECORDED_SHA256 = 'cc5543460c0577561c60b0f3850f47ef0bfc4a59b48365f2946f89e343a7911f'
ALL_CHECKS = ['M-EXIT', 'M-CLASS', 'REF', 'A-CALLS', 'A-PLAN', 'A-BYTES', 'F-VERDICT', 'F-TOKEN', 'F-POST', 'F-BIND',
              'F-TAMPER', 'I-VERDICT', 'I-TOKEN', 'W-RULE', 'R-STDIN', 'R-RENDER', 'R-STDOUT', 'R-MALFORMED']
GROUPS = ['hol-fixture', 'boundary', 'adversarial', 'pseudo-random', 'wire-base']
NON_CANDIDATES = ['Missing', 'TimedOut', 'Failed', 'Malformed', 'Oversized', 'Unsupported']

# Wrong refund decisions (tests/m1-conformance/fixtures). Each replaces impl/Refund.dfy in a work folder.
WRONG_DECISIONS = [
    'RefundAcceptsAnyReason', 'RefundAcceptsEmptyRequestId', 'RefundAcceptsNegative', 'RefundAcceptsOverRemaining',
    'RefundAcceptsReasonPrefix', 'RefundAuthorizesMissing', 'RefundClampsAmount', 'RefundIgnoresEnabled',
    'RefundIgnoresOpen', 'RefundNoMoneyCap', 'RefundOffByOneAmount', 'RefundRejectsEverything',
    'RefundRejectsFullRemaining', 'RefundRejectsZero', 'RefundRemainingOverOriginal', 'RefundSwapsIntentIds']
# Wrong checker cores of Slice 1 (tests/refund-finality/fixtures) and the check that must report each.
WRONG_CORES = {
    'CoreIssuesEverything': ['F-VERDICT', 'F-TAMPER'],
    'CoreRefusesEverything': ['F-VERDICT'],
    'CoreKeepsRemaining': ['F-VERDICT', 'F-TAMPER'],
    'CoreSkipsIntentCheck': ['F-TAMPER'],
    'CoreWrongHash': ['F-BIND'],
    'CoreIntentOnRefusal': ['F-BIND'],
}
# Wrong checker cores that the review found (tests/m1-conformance/fixtures): one direction of a value was not tried.
REVIEW_CORES = ['CoreIntentAmountAtMost', 'CoreIntentIdPrefix', 'CorePostOriginalAtMost']
SUBJECT = ['scripts/exit_m1_conformance.py', DRIVER, RECORDED, EXECUTABLE] + [
    FIXTURES + '/' + name + '.dfy' for name in WRONG_DECISIONS + REVIEW_CORES]
SLICE1 = [CORE, 'impl/Refund.dfy', ISSUER, 'ts/refund-finality/encoding.ts', SLICE1_RECORD] + [
    SLICE1_FIXTURES + '/' + name + '.dfy' for name in sorted(WRONG_CORES)]
APPROVED = ['spec/refund/RefundSpec.dfy', 'spec/refund/protocol.md', SPEC_LOCK, 'policy/refund.yaml']
M1_RECORDS = [REPLAY_PLAN, REPLAY_BUDGET]
TRUSTED = ['gate/backends/dafny.py', 'gate/common.py', pin_file('dafny'), pin_file('javascript'),
           'scripts/javascript_env.py', 'package.json', 'package-lock.json', 'tsconfig.json']
CLAIMS = [
    ('X1', 'tested_against_proved_model',
     'For every typed vector of the recorded corpus, the stdout bytes of the M1 executable are equal to the '
     'rendering of the result of the compiled Refund.Assess (decision, amount, reason, charge id, request id, '
     'intent count). Refund.Assess is proved at source level for R1-R5; the compiled JavaScript is not proved.'),
    ('X2', 'tested_against_proved_model',
     'For every typed vector with an open request and a candidate response, the compiled RefundFinality.Check '
     'issues a token for the honest transition exactly when the M1 executable authorizes; the token intent '
     'renders to the M1 stdout bytes; the post-state is the pre-state with `remaining` decreased by that amount; '
     'every listed tampered transition (14 kinds, each differs from the honest one) is refused.'),
    ('X3', 'unit_tested',
     'For the same vectors the Slice 1 issuer process (its JSON message format) answers with a token only when '
     'the M1 executable authorizes, and with one for every authorized vector inside its text limits. The '
     'signature of a token is NOT verified in this check.'),
    ('X4', 'unit_tested',
     'For every recorded changed wire input (not canonical), the M1 executable wrote nothing, or the rejection, '
     'or exactly the result that the compiled Refund.Assess gives for the unchanged base request.'),
    ('X5', 'unit_tested',
     'The executable reproduces the 22 HOL-written fixture outputs and the 6 recorded malformed-input '
     'observations of 2026-11-04; the renderer of this script reproduces the 22 HOL-written inputs and outputs.'),
    ('K1', 'floor_controls',
     'Each planted record fault is found by its own check, at the changed vector only. Each of 25 wrong Dafny '
     'cores gives findings. For each of the 16 wrong decisions the pinned Dafny reports a postcondition that '
     'could not be proved (exit 4); for the true decision in the same folder layout it exits 0. A corpus or a '
     'record with an empty side is refused. A substituted executable and a changed core module are refused '
     'before use. Not every sub-condition of every check has its own fault (see the report).'),
]
ASSUMPTIONS = [
    'Finite test: only the recorded vectors were executed. No statement about any other input.',
    'A text is a sequence of Unicode scalar values on the Dafny side and its UTF-8 bytes on the M1 side. Byte '
    'strings that are not UTF-8 are outside this comparison.',
    'Typed vectors are sent to M1 in the canonical serialization (the transcription of sexp_to_string in this '
    'script). The transcription is not proved; it reproduces the 22 HOL-written fixture inputs.',
    'The checker core takes the request as open and the response as a candidate. Vectors with a closed request '
    'or a non-candidate response are compared with Refund.Assess only.',
    'Both sides can be wrong in the same way. The reference predicate in this script is a third, unproved opinion.',
    'One machine, one operating system, one run environment (256 MiB CakeML heap and stack).',
    'No text of the corpus has more than 20,000 code points: the Dafny JavaScript runtime fails for a text of '
    '50,000 (Seq.UnicodeFromString). A wrong decision that depends on a longer text is not found.',
]
TRUSTED_BASE = [
    'M1 side: the executable bytes b8ed5ec2... as loaded and run by macOS on this Apple processor; libSystem; the '
    'CakeML basis FFI C code linked into it. The M1 theorems are model theorems with open premises (M1 is open); '
    'this test does not use them.',
    'Slice 1 side: pinned Dafny with Boogie, .NET and Z3 4.12.1; the Dafny JavaScript back end and runtime; '
    'bignumber.js; pinned Node; tsx and typescript for the issuer process.',
    'This script, tests/m1-conformance/driver.cjs and Python 3.10.11: corpus, rendering, comparison. Not proved.',
]


class Failed(Exception):
    pass


def require(condition, message):
    if not condition:
        raise Failed(message)


def rel(path):
    return Path(path).resolve().relative_to(ROOT).as_posix()


def snapshot(names):
    return {name: digest((ROOT / name).read_bytes()) for name in names}


class Run:
    """One fresh work folder: every tool command with its real exit code and full output."""

    def __init__(self, work):
        self.work = work
        work.mkdir(parents=True)
        self.commands = []

    def execute(self, argv, name, quiet=False):
        child = subprocess.run([str(part) for part in argv], cwd=ROOT, capture_output=True)
        (self.work / (name + '.stdout')).write_bytes(child.stdout)
        (self.work / (name + '.stderr')).write_bytes(child.stderr)
        self.commands.append({'name': name, 'argv': [str(part) for part in argv], 'exit_code': child.returncode,
                              'stdout_sha256': digest(child.stdout), 'stderr_sha256': digest(child.stderr)})
        (self.work / 'operations.json').write_bytes(canonical({'commands': self.commands, 'stage_exit': False}))
        if not quiet:
            print('  ' + name + ': exit ' + str(child.returncode), flush=True)
        return child


def toolchain(run):
    require((platform.system(), platform.machine()) == ('Darwin', 'arm64'),
            'TOOLCHAIN: the M1 executable is an ARM64 Mach-O file; this check runs on macOS arm64 only')
    pins = read_json(ROOT / pin_file('dafny'))
    require(pins['verification_options'] == dafny.OPTIONS, 'TOOLCHAIN: the pinned options are not the gate options')
    require(platform.python_version() == pins['python']['version'], 'TOOLCHAIN: Python version differs from the pin')
    executables = {dafny.DAFNY: pins['dafny']['executable_sha256'],
                   ROOT / pins['z3']['path']: pins['z3']['executable_sha256'],
                   Path(sys.executable): pins['python']['executable_sha256']}
    for path, expected in executables.items():
        require(digest(Path(path).read_bytes()) == expected, 'TOOLCHAIN: executable digest differs: ' + str(path))
    version = run.execute([dafny.DAFNY, '--version'], 'dafny-version')
    require(version.returncode == 0 and version.stdout.decode().strip() == pins['dafny']['version_output'],
            'TOOLCHAIN: Dafny version differs from the pin')
    from scripts.javascript_env import check as check_javascript
    js_pins = check_javascript()
    return {'dafny': pins['dafny']['version_output'], 'z3': pins['z3']['version_output'],
            'python': pins['python']['version'], 'node': 'v' + js_pins['node_version']}


# ---------------------------------------------------------------------------------------------------------
# Wire format of the M1 program. Transcription of the pinned CakeML definitions (not proved here):
#   mlsexp: is_safe_char, make_str_safe, sexp_to_string;  mlstring: char_escape_seq, escape_str;
#   mlint: toString (negative sign "~");  forge_refund_io: refund_request_def, refund_response_def.

def atom(data):
    if data == b'':
        return b'""'
    if all(byte not in b'()"\x00' and byte != 32 and not 9 <= byte <= 13 for byte in data):
        return data
    escapes = {9: b'\\t', 10: b'\\n', 92: b'\\\\', 34: b'\\"'}
    return b'"' + b''.join(escapes.get(byte, bytes([byte])) for byte in data) + b'"'


def integer(value):
    return (b'~' if value < 0 else b'') + str(abs(value)).encode()


def boolean(value):
    return b'True' if value else b'False'


def request_atoms(v):
    return [atom(v['charge'].encode()), atom(v['request'].encode()), integer(v['original']), integer(v['remaining']),
            boolean(v['enabled']), boolean(v['opened']), boolean(v['candidate']), integer(v['amount']),
            atom(v['reason'].encode())]


def request_bytes(v):
    return b'(' + b' '.join(request_atoms(v)) + b')'


def response_bytes(ok, amount, reason, charge, request, count):
    return b'(' + b' '.join([b'refund-result-v1', boolean(ok), integer(amount), atom(reason.encode()),
                             atom(charge.encode()), atom(request.encode()), integer(count)]) + b')'


def m1_class(stdout):
    if stdout == REJECTED_BYTES:
        return 'REJECTED'
    if stdout.startswith(AUTHORIZED_PREFIX):
        return 'AUTHORIZED'
    return 'NO_OUTPUT' if stdout == b'' else 'OTHER'


def reference_eligible(v):
    """Transcription of eligible_def (forge_refund, HOL). A third opinion; not proved; no side depends on it."""
    return (v['charge'] != '' and v['request'] != '' and v['enabled'] and v['opened']
            and 0 <= v['original'] <= MAX_MONEY and 0 <= v['remaining'] <= v['original'] and v['candidate']
            and 0 <= v['amount'] <= v['remaining'] and v['reason'] in APPROVED_REASONS)


# ---------------------------------------------------------------------------------------------------------
# The vector corpus. Deterministic: fixed lists and one fixed linear congruential sequence.

def vector(vid, group, charge, request, original, remaining, enabled, opened, candidate, amount, reason):
    return {'id': vid, 'group': group, 'charge': charge, 'request': request, 'original': original,
            'remaining': remaining, 'enabled': enabled, 'opened': opened, 'candidate': candidate,
            'amount': amount, 'reason': reason}


HOSTILE_TEXTS = [
    '', ' ', 'a b', '(', ')', '()', '"', '""', '\\', 'a\\', '\\"', '\x00', 'a\x00b', '\t', '\n', '\r', '\x0b', '\x0c',
    'True', 'False', '~1', '0', 'refund-result-v1', 'é', '\u0080', '\u0085', ' ', '߿', 'ࠀ',
    ' ', '￿', '\U00010000', '\U0010ffff', 'x' * 256, 'x' * 257, 'y' * 5000, '(a b c d e f g h i)',
    'a)(b', 'charge-1 request-1', '\\n', '\\0', 'a\x7fb', '\x01', 'z' * 20000,
]
HOSTILE_REASONS = [
    '', 'Returned_item', 'returned_item ', ' returned_item', 'returned_item\x00', 'returned_item\x00evil',
    'returned_ite', 'returned_itemm', 'returned-item', 'RETURNED_ITEM', 'duplicate_charge,returned_item',
    'returned_item\n', 'retuгned_item', 'goodwill', 'True', '0', '(returned_item)', '"returned_item"',
    'returned_item)', 'service_not_delivered\t', 'a' * 5000, 'returned_item​', 'ｒeturned_item',
    'returned_item\U0010ffff', 'duplicate_charg', 'duplicate_chargee', 'service_not_delivered ', '\\returned_item',
    'returned_item\\', 'duplicate_charge\r',
]
HUGE = [2 ** 63, 2 ** 64, 2 ** 256, 10 ** 100, -(2 ** 63), -(2 ** 256), MAX_MONEY, MAX_MONEY + 1, MAX_MONEY - 1]


def corpus(recorded):
    typed = []
    for case in recorded['typed']:
        i = case['inputs']
        typed.append(vector('H-' + case['name'], 'hol-fixture', i['charge'], i['request'], int(i['original']),
                            int(i['remaining']), i['enabled'], i['opened'], i['candidate'], int(i['amount']),
                            i['reason']))
    # Boundary: every bound of the decision at its value, one below and one above.
    count = 0
    for original in [0, 1, 2, 100, MAX_MONEY - 1, MAX_MONEY, MAX_MONEY + 1, -1]:
        for remaining in sorted({-1, 0, 1, original - 1, original, original + 1}):
            for amount in sorted({-1, 0, 1, remaining - 1, remaining, remaining + 1, original, original + 1,
                                  MAX_MONEY, MAX_MONEY + 1}):
                rows = [(True, True, True, 'returned_item')]
                if amount in (0, remaining):
                    rows += [(e, o, c, 'returned_item') for e in (True, False) for o in (True, False)
                             for c in (True, False) if not (e and o and c)]
                    rows += [(True, True, True, reason) for reason in
                             ('duplicate_charge', 'service_not_delivered', 'goodwill')]
                for enabled, opened, candidate, reason in rows:
                    count += 1
                    typed.append(vector('B-%04d' % count, 'boundary', 'charge-1', 'request-1', original, remaining,
                                        enabled, opened, candidate, amount, reason))
    # Adversarial: one field of an eligible base request is replaced by a hostile value.
    count = 0

    def hostile(**changes):
        nonlocal count
        count += 1
        fields = dict(charge='charge-1', request='request-1', original=100, remaining=60, enabled=True, opened=True,
                      candidate=True, amount=40, reason='returned_item')
        fields.update(changes)
        typed.append(vector('A-%04d' % count, 'adversarial', **fields))

    for text in HOSTILE_TEXTS:
        hostile(charge=text)
        hostile(request=text)
        hostile(charge=text, request=text)
    for reason in HOSTILE_REASONS:
        hostile(reason=reason)
        hostile(reason=reason, amount=60)
    for value in HUGE:
        hostile(original=value)
        hostile(remaining=value)
        hostile(amount=value)
        hostile(original=value, remaining=value, amount=value)
        hostile(original=value, remaining=value, amount=0)
    for approved in APPROVED_REASONS:
        for text in ('é', '(', 'a b', '\U0010ffff', 'x' * 256):
            hostile(charge=text, request=text, reason=approved, amount=60)
    # Pseudo-random mix from one fixed sequence.
    state = 20261118

    def pick(items):
        nonlocal state
        state = (state * 6364136223846793005 + 1442695040888963407) % (2 ** 64)
        return items[(state >> 33) % len(items)]

    texts = ['charge-1', 'request-1', 'c', 'r-é', 'id with space', 'q"uote', '', 'x' * 40, '(p)', 'a\\b', '\U0001f600']
    reasons = APPROVED_REASONS * 3 + ['goodwill', '', 'returned_item ', 'Duplicate_charge']
    flags = [True] * 7 + [False]
    for number in range(1, 1201):
        original = pick([0, 1, 7, 100, 1000, 10 ** 9, MAX_MONEY - 1, MAX_MONEY, MAX_MONEY + 1, -5])
        remaining = pick([0, 1, original // 2, original - 1, original, original + 1, -1])
        amount = pick([0, 1, remaining // 2, remaining - 1, remaining, remaining + 1, -1, original])
        typed.append(vector('P-%04d' % number, 'pseudo-random', pick(texts), pick(texts), original, remaining,
                            pick(flags), pick(flags), pick(flags), amount, pick(reasons)))
    # Wire inputs that are NOT canonical: changes of three base requests. Rule X4 applies to these inputs. Most
    # changes keep every typed value. Four give a value that the decision rejects (a negative amount with - or ~,
    # a reason with a newline or U+0000 at its end); the rule permits the rejection. No change gives a value that
    # the decision could accept in place of the base value (a first list had three such changes; they were typed
    # requests of their own, and the first run reported them).
    bases = [vector('W-base-accept', 'wire-base', 'charge-1', 'request-1', 100, 60, True, True, True, 40, 'returned_item'),
             vector('W-base-reject', 'wire-base', 'charge-1', 'request-1', 100, 60, True, True, True, 61, 'returned_item'),
             vector('W-base-disabled', 'wire-base', 'charge-1', 'request-1', 100, 60, False, True, True, 40, 'returned_item')]
    typed += bases
    wire = []
    for base in bases:
        atoms = request_atoms(base)
        whole = request_bytes(base)

        def swap(index, value, atoms=atoms):
            changed = list(atoms)
            changed[index] = value
            return b'(' + b' '.join(changed) + b')'

        amount = atoms[7]
        changes = [
            ('trailing-newline', whole + b'\n'), ('trailing-space', whole + b' '), ('leading-space', b' ' + whole),
            ('leading-newline', b'\n' + whole), ('crlf-end', whole + b'\r\n'), ('double-spaces', whole.replace(b' ', b'  ')),
            ('tab-separators', whole.replace(b' ', b'\t')), ('newline-separators', whole.replace(b' ', b'\n')),
            ('second-request', whole + b' ' + whole), ('second-request-no-space', whole + whole),
            ('trailing-garbage', whole + b'x'), ('trailing-close', whole + b')'), ('unclosed', whole[:-1]),
            ('no-open', whole[1:]), ('empty', b''), ('only-space', b'   '), ('no-fields', b'()'),
            ('eight-fields', b'(' + b' '.join(atoms[:8]) + b')'), ('ten-fields', b'(' + b' '.join(atoms + [b'x']) + b')'),
            ('nested-first', b'((' + atoms[0] + b') ' + b' '.join(atoms[1:]) + b')'),
            ('nested-whole', b'(' + whole + b')'), ('amount-leading-zero', swap(7, b'0' + amount)),
            ('amount-plus-sign', swap(7, b'+' + amount)), ('amount-minus-sign', swap(7, b'-' + amount)),
            ('amount-tilde', swap(7, b'~' + amount)), ('amount-decimal', swap(7, amount + b'.0')),
            ('amount-exponent', swap(7, amount + b'e0')), ('amount-hex', swap(7, b'0x28')),
            ('amount-underscore', swap(7, amount[:1] + b'_' + amount[1:])),
            ('amount-fullwidth', swap(7, '４０'.encode())), ('amount-quoted', swap(7, b'"' + amount + b'"')),
            ('amount-empty-quoted', swap(7, b'""')), ('amount-word', swap(7, b'forty')),
            ('amount-nul-suffix', swap(7, amount + b'\x00')), ('amount-trailing-letter', swap(7, amount + b'a')),
            ('enabled-lowercase', swap(4, b'true')), ('enabled-uppercase', swap(4, b'TRUE')), ('enabled-one', swap(4, b'1')),
            ('enabled-quoted', swap(4, b'"' + atoms[4] + b'"')), ('enabled-false-lowercase', swap(4, b'false')),
            ('enabled-false-uppercase', swap(4, b'FALSE')), ('enabled-zero', swap(4, b'0')), ('enabled-long', swap(4, atoms[4] + b'e')),
            ('enabled-empty-quoted', swap(4, b'""')), ('enabled-yes', swap(4, b'yes')), ('opened-lowercase', swap(5, b'true')),
            ('candidate-lowercase', swap(6, b'true')), ('candidate-quoted', swap(6, b'"True"')),
            ('reason-quoted', swap(8, b'"returned_item"')), ('reason-nul-suffix', swap(8, b'returned_item\x00')),
            ('reason-escape-n', swap(8, b'"returned_item\\n"')), ('reason-bad-escape', swap(8, b'"returned_item\\x"')),
            ('reason-unterminated', swap(8, b'"returned_item')), ('reason-nested', swap(8, b'(returned_item)')),
            ('charge-quoted', swap(0, b'"charge-1"')), ('byte-order-mark', b'\xef\xbb\xbf' + whole),
            ('nul-after', whole + b'\x00'), ('nul-before', b'\x00' + whole),
            ('many-leading-spaces', b' ' * 100000 + whole), ('deep-nesting', b'(' * 10000 + b')' * 10000),
            ('comment-suffix', whole + b' ; comment'),
            ('original-leading-zero', swap(2, b'0' + atoms[2])), ('remaining-plus-sign', swap(3, b'+' + atoms[3])),
            ('remaining-quoted', swap(3, b'"' + atoms[3] + b'"')),
        ]
        for name, data in changes:
            wire.append({'id': base['id'] + '/' + name, 'base': base['id'], 'bytes': data})
    return typed, wire


def points(text):
    return [ord(character) for character in text]


def finality_of(v):
    """The honest transition of Slice 1 for this request, and tampered transitions that differ from it."""
    if not (v['opened'] and v['candidate']):
        return None
    pre = {'chargeId': v['charge'], 'original': v['original'], 'remaining': v['remaining'], 'refundEnabled': v['enabled']}
    request = {'requestId': v['request'], 'amount': v['amount'], 'reason': v['reason']}
    intent = {'chargeId': v['charge'], 'requestId': v['request'], 'amount': v['amount'], 'reason': v['reason']}
    post = dict(pre, remaining=v['remaining'] - v['amount'])
    other_reason = next(reason for reason in APPROVED_REASONS if reason != v['reason'])
    candidates = [
        ('honest', post, intent),
        ('post-keeps-remaining', pre, intent),
        ('post-one-less', dict(post, remaining=post['remaining'] - 1), intent),
        ('post-original-plus-one', dict(post, original=post['original'] + 1), intent),
        ('post-enabled-flipped', dict(post, refundEnabled=not post['refundEnabled']), intent),
        ('post-other-charge', dict(post, chargeId=post['chargeId'] + 'x'), intent),
        ('intent-amount-plus-one', post, dict(intent, amount=intent['amount'] + 1)),
        ('intent-other-charge', post, dict(intent, chargeId=intent['chargeId'] + 'x')),
        ('intent-other-request', post, dict(intent, requestId=intent['requestId'] + 'x')),
        ('intent-other-reason', post, dict(intent, reason=other_reason)),
        ('post-one-more', dict(post, remaining=post['remaining'] + 1), intent),
        ('post-original-minus-one', dict(post, original=post['original'] - 1), intent),
        ('intent-amount-minus-one', post, dict(intent, amount=intent['amount'] - 1)),
        ('intent-charge-truncated', post, dict(intent, chargeId=intent['chargeId'][:-1])),
        ('intent-request-truncated', post, dict(intent, requestId=intent['requestId'][:-1])),
    ]
    transitions = [{'label': label, 'request': request, 'post': p, 'intent': i} for label, p, i in candidates
                   if label == 'honest' or (p, i) != (post, intent)]
    return {'pre': pre, 'hash': 'pre-state-hash-of-' + v['id'], 'transitions': transitions}


def driver_input(typed):
    def charge(c):
        return {'chargeId': points(c['chargeId']), 'original': str(c['original']), 'remaining': str(c['remaining']),
                'refundEnabled': c['refundEnabled']}

    rows = []
    for v in typed:
        row = {'id': v['id'], 'charge': points(v['charge']), 'request': points(v['request']),
               'original': str(v['original']), 'remaining': str(v['remaining']), 'enabled': v['enabled'],
               'opened': v['opened'], 'candidate': v['candidate'], 'amount': str(v['amount']),
               'reason': points(v['reason']), 'finality': None}
        f = finality_of(v)
        if f is not None:
            row['finality'] = {'pre': charge(f['pre']), 'hash': points(f['hash']), 'transitions': [
                {'label': t['label'],
                 'request': {'requestId': points(t['request']['requestId']), 'amount': str(t['request']['amount']),
                             'reason': points(t['request']['reason'])},
                 'post': charge(t['post']),
                 'intent': {'chargeId': points(t['intent']['chargeId']), 'requestId': points(t['intent']['requestId']),
                            'amount': str(t['intent']['amount']), 'reason': points(t['intent']['reason'])}}
                for t in f['transitions']]}
        rows.append(row)
    return rows


# ---------------------------------------------------------------------------------------------------------
# Running the two stacks.

def load_executable(source, work):
    """Copies the executable into the work folder. Refuses any file whose SHA-256 is not the recorded one."""
    data = Path(source).read_bytes()
    require(digest(data) == EXECUTABLE_SHA256, 'EXECUTABLE: the file is not the recorded M1 executable; it was not run')
    target = work / 'refund'
    target.write_bytes(data)
    target.chmod(0o700)
    return target


def load_recorded(path):
    """The fixture file must be the pinned one: its digest is in this script."""
    require(digest(Path(path).read_bytes()) == RECORDED_SHA256, 'RECORDED: the fixture file is not the pinned one; it was not used')
    return read_json(path)


def run_m1(executable, inputs):
    """inputs: {id: stdin bytes}. One process per input. Returns {id: record}."""
    def one(item):
        key, data = item
        try:
            child = subprocess.run([str(executable)], input=data, capture_output=True, env=M1_ENVIRONMENT, timeout=60)
            return key, {'exit': child.returncode, 'timed_out': False, 'stdout': child.stdout, 'stderr': child.stderr}
        except subprocess.TimeoutExpired as error:
            return key, {'exit': None, 'timed_out': True, 'stdout': error.stdout or b'', 'stderr': error.stderr or b''}

    with ThreadPoolExecutor(max_workers=4) as pool:
        records = dict(pool.map(one, sorted(inputs.items())))
    require(digest(Path(executable).read_bytes()) == EXECUTABLE_SHA256, 'EXECUTABLE: the copy changed during the runs')
    return records


def compile_core(run, source, name, verify):
    out = run.work / name
    out.mkdir()
    options = dafny.OPTIONS if verify else ['--no-verify']
    built = run.execute([dafny.DAFNY, 'build', source, '--target', 'js', '--output', rel(out / 'model'), *options],
                        'compile-' + name, quiet=not verify)
    require(built.returncode == 0, 'compile ' + name + ': expected exit 0, observed ' + str(built.returncode))
    generated = (out / 'model.js').read_bytes()
    module = out / 'model.cjs'
    module.write_bytes(generated + FOOTER)
    return module, generated


def check_core_module(module):
    """The compiled core must be the module of the Slice 1 evidence record, byte for byte."""
    recorded = read_json(ROOT / SLICE1_RECORD)['compiled_core']['module_sha256']
    require(digest(Path(module).read_bytes()) == recorded,
            'CORE_MODULE: the compiled core is not the module of the Slice 1 record; it was not used')
    return recorded


def run_driver(run, module, typed, name):
    vectors_path, output_path = run.work / (name + '-vectors.json'), run.work / (name + '-dafny.json')
    vectors_path.write_text(json.dumps(driver_input(typed)))
    child = run.execute(['node', DRIVER, rel(module), rel(vectors_path), rel(output_path)], 'driver-' + name, quiet=True)
    require(child.returncode == 0, 'driver ' + name + ': expected exit 0, observed ' + str(child.returncode))
    rows = json.loads(output_path.read_text())
    require([row['id'] for row in rows] == [v['id'] for v in typed], 'driver ' + name + ': the rows are not the vectors')
    return {row['id']: row for row in rows}


def run_issuer(run, module, typed):
    """Sends the honest transition of every finality vector to the real Slice 1 issuer process."""
    errors = open(run.work / 'issuer.stderr', 'wb')  # a file, not a pipe: a pipe that nobody reads can block
    process = subprocess.Popen(['node', '--import', 'tsx', ISSUER, rel(module), SPEC_LOCK, 'off'], cwd=ROOT,
                               stdin=subprocess.PIPE, stdout=subprocess.PIPE, stderr=errors)
    answers = {}
    try:
        ready = json.loads(process.stdout.readline())
        require(ready.get('ready') is True and ready['specLockSha256'] == digest((ROOT / SPEC_LOCK).read_bytes()),
                'issuer: no ready line for the present spec lock')
        number = 0
        for v in typed:
            f = finality_of(v)
            if f is None:
                continue
            number += 1
            honest = f['transitions'][0]

            def charge(c):
                return {'chargeId': c['chargeId'], 'original': str(c['original']), 'remaining': str(c['remaining']),
                        'refundEnabled': c['refundEnabled']}

            message = {'id': number, 'pre': charge(f['pre']), 'transition': {
                'request': {'requestId': honest['request']['requestId'], 'amount': str(honest['request']['amount']),
                            'reason': honest['request']['reason']},
                'post': charge(honest['post']),
                'intent': {'chargeId': honest['intent']['chargeId'], 'requestId': honest['intent']['requestId'],
                           'amount': str(honest['intent']['amount']), 'reason': honest['intent']['reason']}}}
            process.stdin.write(json.dumps(message).encode() + b'\n')
            process.stdin.flush()
            answer = json.loads(process.stdout.readline())
            require(answer.get('id') in (number, None) and isinstance(answer.get('ok'), bool),
                    'issuer: answer out of order at ' + v['id'])
            answers[v['id']] = {'ok': answer['ok'], 'reason': answer.get('reason'),
                                'body': answer['token']['body'] if answer['ok'] else None}
        process.stdin.close()
        code = process.wait(timeout=60)
        require(code == 0, 'issuer: expected exit 0 at the end of the input, observed ' + str(code))
    finally:
        if process.poll() is None:
            process.kill()
            process.wait()
        errors.close()
    (run.work / 'issuer-answers.json').write_text(json.dumps(answers, sort_keys=True))
    return answers


def issuer_text(text):
    return len(text.encode('utf-16-le')) // 2 <= ISSUER_MAX_TEXT and '\x00' not in text


# ---------------------------------------------------------------------------------------------------------
# The comparison. Every difference is a finding. `tally` counts how often each check was evaluated.

def check(findings, name, condition, vector_id, detail, tally=None):
    if tally is not None:
        tally[name] = tally.get(name, 0) + 1
    if not condition:
        findings.append({'check': name, 'vector': vector_id, 'detail': detail})


def text_of(point_list):
    return ''.join(chr(point) for point in point_list)


def render_assess(result):
    """The M1 result bytes that correspond to one Refund.Assess result of the driver."""
    if not result['authorized']:
        return response_bytes(False, 0, '', '', '', len(result['plan']))
    first = result['plan'][0] if result['plan'] else {'chargeId': [], 'requestId': []}
    return response_bytes(True, int(result['amount']), text_of(result['reason']), text_of(first['chargeId']),
                          text_of(first['requestId']), len(result['plan']))


def render_intent(intent, count):
    return response_bytes(True, int(intent['amount']), text_of(intent['reason']), text_of(intent['chargeId']),
                          text_of(intent['requestId']), count)


def compare(state, tally=None):
    findings = []
    m1, dafny_rows, issuer, expected_of = state['m1'], state['dafny'], state['issuer'], {}
    for v in state['typed']:
        vid, native = v['id'], m1[v['id']]
        out, kind = native['stdout'], m1_class(native['stdout'])
        check(findings, 'M-EXIT', native['exit'] == 0 and not native['timed_out'] and native['stderr'] == b'', vid, 'M1 exit, time limit or stderr', tally)
        check(findings, 'M-CLASS', kind in ('AUTHORIZED', 'REJECTED'), vid, 'M1 wrote no result for a canonical request: ' + kind, tally)
        check(findings, 'REF', (kind == 'AUTHORIZED') == state['reference'][vid], vid, 'M1 differs from the reference predicate', tally)
        row = dafny_rows[vid]
        check(findings, 'A-CALLS', [result['response'] for result in row['assess']] == (['Candidate'] if v['candidate'] else NON_CANDIDATES), vid, 'the Assess calls are not the expected ones', tally)
        for result in row['assess']:
            well_formed = (len(result['plan']) == 1 and result['plan'][0]['amount'] == result['amount'] and result['plan'][0]['reason'] == result['reason']) if result['authorized'] else result['plan'] == []
            check(findings, 'A-PLAN', well_formed, vid, 'Assess (' + result['response'] + '): the plan does not fit the decision', tally)
            check(findings, 'A-BYTES', render_assess(result) == out, vid, 'Assess (' + result['response'] + ') and M1 stdout differ', tally)
        expected_of[vid] = render_assess(row['assess'][0]) if row['assess'] else None
        f = finality_of(v)
        if f is None:
            continue
        honest, tampered = row['finality'][0], row['finality'][1:]
        labels_fit = [r['transition'] for r in row['finality']] == [t['label'] for t in f['transitions']]
        check(findings, 'F-VERDICT', labels_fit and honest['issued'] == (kind == 'AUTHORIZED'), vid, 'Check (honest transition) and M1 differ', tally)
        if honest['issued']:
            token = honest['token']
            check(findings, 'F-TOKEN', render_intent(token['intent'], len(honest['plan'])) == out, vid, 'token intent and M1 stdout differ', tally)
            post_fits = (v['remaining'] - int(token['post']['remaining']) == int(token['intent']['amount']) and int(token['post']['original']) == v['original'] and text_of(token['post']['chargeId']) == v['charge'] and token['post']['refundEnabled'] == v['enabled'])
            check(findings, 'F-POST', post_fits, vid, 'token post-state is not the pre-state minus the amount', tally)
            check(findings, 'F-BIND', text_of(token['preStateHash']) == f['hash'] and text_of(token['requestId']) == v['request'] and honest['plan'] == [token['intent']], vid, 'token binding or plan', tally)
        else:
            check(findings, 'F-BIND', honest['plan'] == [], vid, 'a refusal has an intent', tally)
        check(findings, 'F-TAMPER', not any(r['issued'] for r in tampered), vid, 'a tampered transition got a token: ' + ', '.join(r['transition'] for r in tampered if r['issued']), tally)
        if issuer is not None:
            answer = issuer[vid]
            inside = issuer_text(v['charge']) and issuer_text(v['request']) and issuer_text(v['reason'])
            check(findings, 'I-VERDICT', (not answer['ok'] or kind == 'AUTHORIZED') and (answer['ok'] or not (kind == 'AUTHORIZED' and inside)), vid, 'issuer process and M1 differ', tally)
            if answer['ok']:
                body = answer['body']
                intent = {'amount': body['intent']['amount'], 'reason': points(body['intent']['reason']), 'chargeId': points(body['intent']['chargeId']), 'requestId': points(body['intent']['requestId'])}
                check(findings, 'I-TOKEN', render_intent(intent, 1) == out and v['remaining'] - int(body['post']['remaining']) == int(body['intent']['amount']) and body['requestId'] == v['request'], vid, 'issuer token and M1 stdout differ', tally)
    for w in state['wire']:
        native = m1[w['id']]
        check(findings, 'W-RULE', not native['timed_out'] and native['stdout'] in (b'', REJECTED_BYTES, expected_of[w['base']]), w['id'], 'a changed wire input gave a result that the base request does not have', tally)
    for case in state['recorded']['typed']:
        vid, inputs, expected = 'R-' + case['name'], case['inputs'], case['expected']
        as_vector = vector(vid, 'recorded', inputs['charge'], inputs['request'], int(inputs['original']), int(inputs['remaining']), inputs['enabled'], inputs['opened'], inputs['candidate'], int(inputs['amount']), inputs['reason'])
        check(findings, 'R-STDIN', request_bytes(as_vector).hex() == case['stdin_hex'], vid, 'the renderer does not reproduce the HOL-written input', tally)
        check(findings, 'R-RENDER', response_bytes(expected['ok'], int(expected['amount']), expected['reason'], expected['charge'], expected['request'], int(expected['count'])).hex() == case['hol_stdout_hex'], vid, 'the renderer does not reproduce the HOL-written output', tally)
        check(findings, 'R-STDOUT', m1[vid]['exit'] == 0 and m1[vid]['stdout'].hex() == case['hol_stdout_hex'], vid, 'M1 stdout is not the HOL-written output', tally)
    for case in state['recorded']['malformed']:
        vid = 'R-' + case['name']
        check(findings, 'R-MALFORMED', m1[vid]['exit'] == case['recorded_native_exit'] and m1[vid]['stdout'].hex() == case['recorded_native_stdout_hex'], vid, 'M1 differs from the recorded malformed-input observation', tally)
    return findings


def summary(state):
    """Counts for the record, and the non-vacuity requirements."""
    m1, dafny_rows, issuer = state['m1'], state['dafny'], state['issuer']
    groups, issued, refused_tampered, tampered, refused_of_authorized = {}, 0, 0, 0, 0
    for v in state['typed']:
        group = groups.setdefault(v['group'], {'vectors': 0, 'authorized': 0, 'rejected': 0})
        group['vectors'] += 1
        group['authorized' if m1_class(m1[v['id']]['stdout']) == 'AUTHORIZED' else 'rejected'] += 1
        rows = dafny_rows[v['id']]['finality']
        if rows:
            issued += rows[0]['issued']
            tampered += len(rows) - 1
            refused_tampered += sum(not row['issued'] for row in rows[1:])
            if m1_class(m1[v['id']]['stdout']) == 'AUTHORIZED':
                refused_of_authorized += sum(not row['issued'] for row in rows[1:])
    finality_vectors = sum(1 for v in state['typed'] if finality_of(v) is not None)
    authorized = sum(group['authorized'] for group in groups.values())
    rejected = sum(group['rejected'] for group in groups.values())
    wire_classes = {}
    for w in state['wire']:
        native = m1[w['id']]
        kind = m1_class(native['stdout'])
        name = kind if kind != 'AUTHORIZED' else 'SAME_AS_BASE_AUTHORIZED'
        wire_classes[name] = wire_classes.get(name, 0) + 1
    wire_exits = {}
    for w in state['wire']:
        key = 'time limit' if m1[w['id']]['timed_out'] else 'exit ' + str(m1[w['id']]['exit'])
        wire_exits[key] = wire_exits.get(key, 0) + 1
    result = {'typed_vectors': len(state['typed']), 'groups': groups, 'm1_authorized': authorized, 'm1_rejected': rejected,
              'non_candidate_vectors': sum(1 for v in state['typed'] if not v['candidate']),
              'assess_calls': sum(len(dafny_rows[v['id']]['assess']) for v in state['typed']),
              'finality_vectors': finality_vectors, 'tokens_for_honest_transitions': issued,
              'tampered_transitions': tampered, 'tampered_transitions_refused': refused_tampered,
              'tampered_transitions_of_authorized_vectors_refused': refused_of_authorized,
              'wire_inputs': len(state['wire']), 'wire_result_classes': wire_classes, 'wire_process_exits': wire_exits,
              'hol_fixtures': len(state['recorded']['typed']), 'malformed_observations': len(state['recorded']['malformed'])}
    if issuer is not None:
        reasons = {}
        for answer in issuer.values():
            key = 'token' if answer['ok'] else str(answer['reason'])
            reasons[key] = reasons.get(key, 0) + 1
        result['issuer_answers'] = reasons
    require(authorized > 0 and rejected > 0 and issued > 0 and refused_of_authorized > 0 and result['non_candidate_vectors'] > 0
            and all(groups.get(name, {}).get('authorized', 0) > 0 and groups.get(name, {}).get('rejected', 0) > 0 for name in GROUPS)
            and (issuer is None or (result['issuer_answers'].get('token', 0) > 0 and result['issuer_answers'].get('core: Refuse', 0) > 0))
            and len(state['wire']) > 0 and len(state['recorded']['typed']) == 22 and len(state['recorded']['malformed']) == 6,
            'VACUITY: one side of the comparison is empty (a group, an accept, a reject, a token, a refusal, a wire input or a fixture)')
    return result


def coverage(tally, with_issuer):
    """Every check must have been evaluated at least once. A check that never ran has shown nothing."""
    never = [name for name in ALL_CHECKS if tally.get(name, 0) == 0 and (with_issuer or not name.startswith('I-'))]
    require(not never, 'VACUITY: these checks were never evaluated: ' + ', '.join(never))


def observe(run, module, with_issuer, executable_source=None):
    """Runs both stacks on the corpus. Returns the state that `compare` reads."""
    recorded = load_recorded(ROOT / RECORDED)
    typed, wire = corpus(recorded)
    require(len({v['id'] for v in typed} | {w['id'] for w in wire}) == len(typed) + len(wire), 'corpus: an id is used twice')
    executable = load_executable(executable_source or ROOT / EXECUTABLE, run.work)
    inputs = {v['id']: request_bytes(v) for v in typed}
    inputs.update({w['id']: w['bytes'] for w in wire})
    inputs.update({'R-' + case['name']: bytes.fromhex(case['stdin_hex']) for case in recorded['typed'] + recorded['malformed']})
    m1 = run_m1(executable, inputs)
    (run.work / 'm1-records.json').write_text(json.dumps(
        {key: {'exit': r['exit'], 'timed_out': r['timed_out'], 'stdout_hex': r['stdout'].hex(), 'stderr_hex': r['stderr'].hex()}
         for key, r in m1.items()}, sort_keys=True))
    corpus_sha256 = digest(canonical({'typed': driver_input(typed), 'wire': [{'id': w['id'], 'base': w['base'], 'hex': w['bytes'].hex()} for w in wire]}))
    return {'typed': typed, 'wire': wire, 'recorded': recorded, 'm1': m1, 'corpus_sha256': corpus_sha256,
            'reference': {v['id']: reference_eligible(v) for v in typed},
            'dafny': run_driver(run, module, typed, 'core'),
            'issuer': run_issuer(run, module, typed) if with_issuer else None}


def true_core(run):
    module, generated = compile_core(run, CORE, 'core', verify=True)
    recorded = check_core_module(module)
    return module, {'build_command_without_the_output_path': ['.toolchain/dafny-4.11.0/dafny/dafny', 'build', CORE, '--target', 'js', *dafny.OPTIONS],
                    'generated_js_sha256': digest(generated), 'module_sha256': recorded,
                    'equal_to_the_slice1_record': True, 'source_to_module_proved': False}


# ---------------------------------------------------------------------------------------------------------
# Cases.

def conformance(run):
    tools = toolchain(run)
    module, core = true_core(run)
    state = observe(run, module, with_issuer=True)
    tally = {}
    findings = compare(state, tally)
    (run.work / 'findings.json').write_text(json.dumps(findings, indent=1))
    counts = summary(state)
    coverage(tally, with_issuer=True)
    require(findings == [], 'CONFORMANCE: %d findings; first: %s' % (len(findings), json.dumps(findings[:3])))
    return {'toolchain': tools, 'compiled_core': core,
            'ids': {'m1_executable_sha256': EXECUTABLE_SHA256, 'corpus_sha256': state['corpus_sha256'],
                    'recorded_cases_sha256': digest((ROOT / RECORDED).read_bytes()),
                    'spec_lock_sha256': digest((ROOT / SPEC_LOCK).read_bytes())},
            'm1_environment': M1_ENVIRONMENT, 'counts': counts,
            'checks_evaluated': dict(sorted(tally.items())), 'findings': 0}


def planted_faults(state):
    """(name, checks that must report it, function that changes a copy of the records)."""
    typed = state['typed']

    def inside(v):
        return finality_of(v) is not None and issuer_text(v['charge']) and issuer_text(v['request']) and issuer_text(v['reason'])

    accept = next(v for v in typed if inside(v) and state['reference'][v['id']] and v['amount'] > 0 and v['charge'] != v['request'])
    reject = next(v for v in typed if inside(v) and not state['reference'][v['id']] and v['amount'] >= 0)
    a, r = accept['id'], reject['id']
    n = next(v['id'] for v in typed if not v['candidate'])
    wire = next(w for w in state['wire'] if w['base'] == 'W-base-reject')['id']
    ok = response_bytes

    def m1_set(key, **changes):
        return lambda s: s['m1'][key].update(changes)

    def token(s):
        return s['dafny'][a]['finality'][0]['token']

    def honest_refused(s):
        s['dafny'][a]['finality'][0].update(issued=False, plan=[])
        s['dafny'][a]['finality'][0].pop('token')

    def token_amount(s):
        token(s)['intent']['amount'] = str(accept['amount'] + 1)
        s['dafny'][a]['finality'][0]['plan'] = [copy.deepcopy(token(s)['intent'])]

    def assess_flip(s):
        s['dafny'][a]['assess'][0].update(authorized=False, plan=[])

    def issuer_amount(s):
        s['issuer'][a]['body']['intent']['amount'] = str(accept['amount'] + 1)

    return a, r, n, wire, [
        ('m1-exit-1', a, ['M-EXIT'], m1_set(a, exit=1)),
        ('m1-stderr', a, ['M-EXIT'], m1_set(a, stderr=b'x')),
        ('m1-time-limit', a, ['M-EXIT'], m1_set(a, timed_out=True)),
        ('m1-no-output', a, ['M-CLASS', 'REF', 'A-BYTES', 'F-VERDICT'], m1_set(a, stdout=b'')),
        ('m1-authorized-to-rejected', a, ['REF', 'A-BYTES', 'F-VERDICT', 'I-VERDICT'], m1_set(a, stdout=REJECTED_BYTES)),
        ('m1-rejected-to-authorized', r, ['REF', 'A-BYTES', 'F-VERDICT', 'I-VERDICT'],
         m1_set(r, stdout=ok(True, reject['amount'], reject['reason'], reject['charge'], reject['request'], 1))),
        ('m1-amount-plus-one', a, ['A-BYTES', 'F-TOKEN', 'I-TOKEN'],
         m1_set(a, stdout=ok(True, accept['amount'] + 1, accept['reason'], accept['charge'], accept['request'], 1))),
        ('m1-ids-exchanged', a, ['A-BYTES', 'F-TOKEN', 'I-TOKEN'],
         m1_set(a, stdout=ok(True, accept['amount'], accept['reason'], accept['request'], accept['charge'], 1))),
        ('m1-other-reason', a, ['A-BYTES', 'F-TOKEN', 'I-TOKEN'],
         m1_set(a, stdout=ok(True, accept['amount'], next(x for x in APPROVED_REASONS if x != accept['reason']), accept['charge'], accept['request'], 1))),
        ('m1-intent-count-2', a, ['A-BYTES', 'F-TOKEN', 'I-TOKEN'],
         m1_set(a, stdout=ok(True, accept['amount'], accept['reason'], accept['charge'], accept['request'], 2))),
        ('dafny-assess-plan-empty', a, ['A-PLAN'], lambda s: s['dafny'][a]['assess'][0].update(plan=[])),
        ('dafny-assess-rejects', a, ['A-BYTES'], assess_flip),
        ('dafny-honest-refused', a, ['F-VERDICT'], honest_refused),
        ('dafny-token-amount', a, ['F-TOKEN'], token_amount),
        ('dafny-token-post', a, ['F-POST'], lambda s: token(s)['post'].update(remaining=str(accept['remaining'] - accept['amount'] + 1))),
        ('dafny-token-hash', a, ['F-BIND'], lambda s: token(s).update(preStateHash=points('other'))),
        ('dafny-intent-on-refusal', r, ['F-BIND'], lambda s: s['dafny'][r]['finality'][0].update(plan=[{}])),
        ('dafny-tampered-issued', a, ['F-TAMPER'], lambda s: s['dafny'][a]['finality'][1].update(issued=True)),
        ('issuer-refuses', a, ['I-VERDICT'], lambda s: s['issuer'][a].update(ok=False, body=None)),
        ('issuer-token-amount', a, ['I-TOKEN'], issuer_amount),
        ('wire-authorization', wire, ['W-RULE'], m1_set(wire, stdout=ok(True, 61, 'returned_item', 'charge-1', 'request-1', 1))),
        ('reference-flipped', a, ['REF'], lambda s: s['reference'].update({a: False})),
        ('fixture-hol-input', 'R-' + state['recorded']['typed'][0]['name'], ['R-STDIN'],
         lambda s: s['recorded']['typed'][0].update(stdin_hex=s['recorded']['typed'][0]['stdin_hex'] + '20')),
        ('fixture-expected-amount', 'R-' + state['recorded']['typed'][0]['name'], ['R-RENDER'],
         lambda s: s['recorded']['typed'][0]['expected'].update(amount='41')),
        ('fixture-m1-output', 'R-' + state['recorded']['typed'][0]['name'], ['R-STDOUT'],
         m1_set('R-' + state['recorded']['typed'][0]['name'], stdout=REJECTED_BYTES)),
        ('fixture-malformed-output', 'R-' + state['recorded']['malformed'][0]['name'], ['R-MALFORMED'],
         m1_set('R-' + state['recorded']['malformed'][0]['name'], stdout=REJECTED_BYTES)),
        # Added after the review (finding R3): one fault for each sub-condition of a check.
        ('dafny-assess-call-missing', n, ['A-CALLS'], lambda s: s['dafny'][n]['assess'].pop()),
        ('dafny-assess-call-renamed', a, ['A-CALLS'], lambda s: s['dafny'][a]['assess'][0].update(response='Missing')),
        ('dafny-plan-amount', a, ['A-PLAN'], lambda s: s['dafny'][a]['assess'][0]['plan'][0].update(amount=str(accept['amount'] + 1))),
        ('dafny-plan-reason', a, ['A-PLAN'], lambda s: s['dafny'][a]['assess'][0]['plan'][0].update(reason=points('other'))),
        ('dafny-plan-twice', a, ['A-PLAN'], lambda s: s['dafny'][a]['assess'][0]['plan'].append(copy.deepcopy(s['dafny'][a]['assess'][0]['plan'][0]))),
        ('dafny-plan-on-rejection', r, ['A-PLAN'], lambda s: s['dafny'][r]['assess'][0].update(plan=[{'chargeId': [], 'requestId': [], 'amount': '0', 'reason': []}])),
        ('dafny-transition-label', a, ['F-VERDICT'], lambda s: s['dafny'][a]['finality'][1].update(transition='honest')),
        ('dafny-token-post-original', a, ['F-POST'], lambda s: token(s)['post'].update(original=str(accept['original'] + 1))),
        ('dafny-token-post-charge', a, ['F-POST'], lambda s: token(s)['post'].update(chargeId=points(accept['charge'] + 'x'))),
        ('dafny-token-post-enabled', a, ['F-POST'], lambda s: token(s)['post'].update(refundEnabled=False)),
        ('dafny-token-request-id', a, ['F-BIND'], lambda s: token(s).update(requestId=points(accept['request'] + 'x'))),
        ('dafny-plan-not-the-token-intent', a, ['F-BIND'], lambda s: s['dafny'][a]['finality'][0]['plan'][0].update(amount=str(accept['amount'] + 1))),
        ('issuer-token-post', a, ['I-TOKEN'], lambda s: s['issuer'][a]['body']['post'].update(remaining=str(accept['remaining'] - accept['amount'] + 1))),
        ('issuer-token-request-id', a, ['I-TOKEN'], lambda s: s['issuer'][a]['body'].update(requestId=accept['request'] + 'x')),
        ('issuer-token-for-a-rejected-vector', r, ['I-VERDICT'], lambda s: s['issuer'][r].update(ok=True, body=copy.deepcopy(s['issuer'][a]['body']))),
        ('wire-time-limit', wire, ['W-RULE'], m1_set(wire, timed_out=True)),
        ('fixture-m1-exit', 'R-' + state['recorded']['typed'][0]['name'], ['R-STDOUT'], m1_set('R-' + state['recorded']['typed'][0]['name'], exit=1)),
        ('fixture-malformed-exit', 'R-' + state['recorded']['malformed'][0]['name'], ['R-MALFORMED'],
         m1_set('R-' + state['recorded']['malformed'][0]['name'], exit=1)),
    ]


def record_controls(run):
    toolchain(run)
    module, _ = true_core(run)
    state = observe(run, module, with_issuer=True)
    tally = {}
    require(compare(state, tally) == [], 'record controls: the unchanged records already have findings')
    summary(state)
    coverage(tally, with_issuer=True)
    accept, reject, non_candidate, wire, faults = planted_faults(state)
    rows = []
    for name, target, expected, change in faults:
        changed = copy.deepcopy(state)
        change(changed)
        findings = compare(changed)
        found = sorted({finding['check'] for finding in findings})
        require(findings and set(expected) <= set(found), 'control ' + name + ': expected ' + str(expected) + ', found ' + str(found))
        require({finding['vector'] for finding in findings} == {target}, 'control ' + name + ': a finding is at another vector')
        rows.append({'fault': name, 'vector_kind': 'accepted' if target == accept else 'rejected' if target == reject else 'non-candidate' if target == non_candidate else 'wire' if target == wire else 'fixture',
                     'required_checks': expected, 'reported_checks': found, 'result': 'found'})
    # Vacuity: a corpus or a record with one empty side must not pass (review findings R1, R4).
    def restricted(keep):
        changed = copy.deepcopy(state)
        changed['typed'] = [v for v in state['typed'] if keep(v)]
        return changed

    def emptied(**parts):
        changed = copy.deepcopy(state)
        changed.update(parts)
        return changed

    def no_tokens():
        changed = copy.deepcopy(state)
        for answer in changed['issuer'].values():
            answer.update(ok=False, reason='core: Refuse', body=None)
        return changed

    def no_tamper_of_authorized():
        changed = copy.deepcopy(state)
        for v in state['typed']:
            if state['reference'][v['id']] and finality_of(v) is not None:
                del changed['dafny'][v['id']]['finality'][1:]
        return changed

    empty_sides = [
        ('corpus-without-accepted-vectors', restricted(lambda v: not state['reference'][v['id']])),
        ('corpus-without-rejected-vectors', restricted(lambda v: state['reference'][v['id']])),
        ('corpus-without-non-candidate-vectors', restricted(lambda v: v['candidate'])),
        ('corpus-without-the-boundary-group', restricted(lambda v: v['group'] != 'boundary')),
        ('corpus-without-wire-inputs', emptied(wire=[])),
        ('record-without-fixtures', emptied(recorded=dict(state['recorded'], typed=[]))),
        ('record-without-malformed-observations', emptied(recorded=dict(state['recorded'], malformed=[]))),
        ('issuer-without-tokens', no_tokens()),
        ('no-tampered-transition-of-an-authorized-vector', no_tamper_of_authorized()),
    ]
    for name, changed in empty_sides:
        try:
            summary(changed)
            outcome = 'passed'
        except Failed as error:
            outcome = 'refused' if str(error).startswith('VACUITY') else 'other failure'
        require(outcome == 'refused', 'control ' + name + ': an empty side was not refused')
        rows.append({'fault': name, 'vector_kind': 'corpus', 'required_checks': ['VACUITY'], 'reported_checks': ['VACUITY'], 'result': 'refused'})
    for name in ALL_CHECKS:
        try:
            coverage({key: value for key, value in tally.items() if key != name}, with_issuer=True)
            outcome = 'passed'
        except Failed as error:
            outcome = 'refused' if str(error).startswith('VACUITY') else 'other failure'
        require(outcome == 'refused', 'control never-evaluated ' + name + ': not refused')
    rows.append({'fault': 'a-check-that-was-never-evaluated (each of %d checks)' % len(ALL_CHECKS), 'vector_kind': 'corpus',
                 'required_checks': ['VACUITY'], 'reported_checks': ['VACUITY'], 'result': 'refused'})
    changed_fixtures = run.work / 'changed-fixtures.json'
    changed_fixtures.write_bytes((ROOT / RECORDED).read_bytes() + b'\n')
    try:
        load_recorded(changed_fixtures)
        outcome = 'used'
    except Failed as error:
        outcome = 'refused' if str(error).startswith('RECORDED') else 'other failure'
    require(outcome == 'refused', 'control changed fixture file: ' + outcome)
    rows.append({'fault': 'changed-fixture-file', 'vector_kind': 'identity', 'required_checks': ['RECORDED'], 'reported_checks': ['RECORDED'], 'result': 'refused before use'})
    # A substituted executable is refused BEFORE any run. The stand-in is a harmless shell script.
    stand_in = run.work / 'stand-in-executable'
    stand_in.write_bytes(b'#!/bin/sh\nexit 0\n')
    substitute = Run(run.work / 'substituted')
    try:
        observe(substitute, module, with_issuer=False, executable_source=stand_in)
        outcome = 'used'
    except Failed as error:
        outcome = 'refused' if str(error).startswith('EXECUTABLE') and not (substitute.work / 'refund').exists() else 'other failure: ' + str(error)
    require(outcome == 'refused', 'control substituted executable: ' + outcome)
    rows.append({'fault': 'substituted-executable', 'vector_kind': 'identity', 'required_checks': ['EXECUTABLE'], 'reported_checks': ['EXECUTABLE'], 'result': 'refused before any run'})
    changed_module = run.work / 'changed-module.cjs'
    changed_module.write_bytes(Path(module).read_bytes() + b'\n')
    try:
        check_core_module(changed_module)
        outcome = 'used'
    except Failed as error:
        outcome = 'refused' if str(error).startswith('CORE_MODULE') else 'other failure'
    require(outcome == 'refused', 'control changed core module: ' + outcome)
    rows.append({'fault': 'changed-core-module', 'vector_kind': 'identity', 'required_checks': ['CORE_MODULE'], 'reported_checks': ['CORE_MODULE'], 'result': 'refused before use'})
    return rows


def core_controls(run):
    toolchain(run)
    module, _ = true_core(run)
    state = observe(run, module, with_issuer=False)
    require(compare(state) == [], 'core controls: the true core already has findings')
    rows = []
    # Positive control for the 16 rejections below: the TRUE decision in the same folder layout is proved.
    tree = run.work / 'tree-true'
    (tree / 'impl').mkdir(parents=True)
    (tree / 'spec/refund').mkdir(parents=True)
    shutil.copyfile(ROOT / 'impl/Refund.dfy', tree / 'impl/Refund.dfy')
    shutil.copyfile(ROOT / 'spec/refund/RefundSpec.dfy', tree / 'spec/refund/RefundSpec.dfy')
    proved = run.execute([dafny.DAFNY, 'verify', rel(tree / 'impl/Refund.dfy'), *dafny.OPTIONS], 'verify-true-decision')
    require(proved.returncode == 0, 'true decision in the control layout: expected checker exit 0, observed ' + str(proved.returncode))

    def measure(name, wrong_module, required, kind, extra):
        changed = dict(state, dafny=run_driver(run, wrong_module, state['typed'], name))
        findings = compare(changed)
        found = sorted({finding['check'] for finding in findings})
        require(findings and set(required) <= set(found), 'wrong core ' + name + ': expected ' + str(required) + ', found ' + str(found))
        # The M1 side is unchanged: no finding may come from a check that reads the M1 records only.
        # (W-RULE is not in this list: it reads the Dafny result of the base request.)
        require(not {'M-EXIT', 'M-CLASS', 'REF', 'R-STDIN', 'R-RENDER', 'R-STDOUT', 'R-MALFORMED'} & set(found), 'wrong core ' + name + ': a check of the M1 records reported')
        rows.append(dict({'wrong_core': name, 'kind': kind, 'required_checks': required, 'reported_checks': found,
                          'vectors_with_a_finding': len({finding['vector'] for finding in findings}), 'result': 'reported'}, **extra))
        print('  %s: %d vectors with a finding; %s' % (name, rows[-1]['vectors_with_a_finding'], ', '.join(found)), flush=True)

    for name in WRONG_DECISIONS:
        tree = run.work / ('tree-' + name)
        (tree / 'impl').mkdir(parents=True)
        (tree / 'spec/refund').mkdir(parents=True)
        shutil.copyfile(ROOT / FIXTURES / (name + '.dfy'), tree / 'impl/Refund.dfy')
        shutil.copyfile(ROOT / CORE, tree / 'impl/RefundFinality.dfy')
        shutil.copyfile(ROOT / 'spec/refund/RefundSpec.dfy', tree / 'spec/refund/RefundSpec.dfy')
        # The pinned Dafny must not prove the wrong decision against the approved specification.
        verified = run.execute([dafny.DAFNY, 'verify', rel(tree / 'impl/Refund.dfy'), *dafny.OPTIONS], 'verify-' + name, quiet=True)
        require(verified.returncode == 4, 'wrong decision ' + name + ': expected checker exit 4 (not proved), observed ' + str(verified.returncode))
        errors = [line for line in (verified.stdout + verified.stderr).decode('utf-8', 'replace').splitlines() if ': Error: ' in line]
        require(errors and all('a postcondition could not be proved on this return path' in line for line in errors), 'wrong decision ' + name + ': the checker error is not a postcondition error')
        wrong_module, _ = compile_core(run, rel(tree / 'impl/RefundFinality.dfy'), name, verify=False)
        measure(name, wrong_module, ['A-BYTES'], 'wrong decision (Refund.Assess)', {'dafny_verify_exit': verified.returncode, 'dafny_postcondition_errors': len(errors)})
    for name, required in sorted(WRONG_CORES.items()):
        wrong_module, _ = compile_core(run, SLICE1_FIXTURES + '/' + name + '.dfy', name, verify=False)
        measure(name, wrong_module, required, 'wrong checker core (RefundFinality.Check)', {})
    for name in REVIEW_CORES:
        wrong_module, _ = compile_core(run, FIXTURES + '/' + name + '.dfy', name, verify=False)
        measure(name, wrong_module, ['F-TAMPER'], 'wrong checker core found by the review (RefundFinality.Check)', {})
    return rows


def m1_audit():
    """Reads the tracked replay records. Starts no HOL process."""
    plan = read_json(ROOT / REPLAY_PLAN)['C']
    budget = read_json(ROOT / REPLAY_BUDGET)
    classes = {}
    for case in plan['cases']:
        row = classes.setdefault(case['class'], {'cases': 0, 'recorded_exit_0': 0, 'recorded_exit_not_0': 0, 'recorded_wall_seconds': 0.0})
        row['cases'] += 1
        row['recorded_exit_0' if case['recorded_exit'] == 0 else 'recorded_exit_not_0'] += 1
        row['recorded_wall_seconds'] += case['recorded_wall_seconds']
    require(sum(row['cases'] for row in classes.values()) == plan['listed_cases'] == len(plan['cases']), 'm1 audit: the case list does not fit its count')
    require(all(case['state'].startswith('NOT RUN') for case in plan['cases']), 'm1 audit: a listed case is not marked NOT RUN')
    for row in classes.values():
        row['recorded_wall_seconds'] = round(row['recorded_wall_seconds'])
    total = sum(row['recorded_wall_seconds'] for row in classes.values())
    return {'source': REPLAY_PLAN, 'source_sha256': digest((ROOT / REPLAY_PLAN).read_bytes()),
            'state_in_the_record': plan['state'], 'classes': dict(sorted(classes.items())),
            'cases': plan['listed_cases'], 'recorded_wall_seconds_sum': total,
            'longest_recorded_case_seconds': round(max(case['recorded_wall_seconds'] for case in plan['cases'])),
            'packets_with_a_listed_case': len({case['packet'] for case in plan['cases']}),
            'replay_budget_record': {'source': REPLAY_BUDGET, 'sha256': digest((ROOT / REPLAY_BUDGET).read_bytes()), 'content': budget},
            'hol_processes_started_by_this_case': 0,
            'note': 'Sums of wall times that the OLD case records hold. An estimate for a serial replay, not a measurement.'}


def bundle_of(run):
    inputs = SUBJECT + SLICE1 + APPROVED + M1_RECORDS + TRUSTED
    before = snapshot(inputs)
    main = conformance(Run(run.work / 'conformance'))
    records = record_controls(Run(run.work / 'record-controls'))
    cores = core_controls(Run(run.work / 'core-controls'))
    audit = m1_audit()
    require(snapshot(inputs) == before, 'INPUT_CHANGED: a source or trusted input changed during the checks')
    evidence = [{'claim_id': claim, 'statement_plain_english': statement, 'method': method, 'result': 'passed',
                 'tool': 'the M1 executable, node (compiled Dafny core), python3 (comparison)',
                 'artifact': EXECUTABLE + ' and ' + CORE, 'assumptions': ASSUMPTIONS,
                 'reproduce_cmd': 'python3 scripts/exit_m1_conformance.py --case evidence'}
                for claim, method, statement in CLAIMS]
    return {
        'record': 'forge-m1-slice1-refund-conformance', 'format_version': 1,
        'gate_accepted': False, 'policy': None, 'end_to_end': False, 'm1': 'open',
        'producer': 'scripts/exit_m1_conformance.py (a scenario script; not the gate)',
        'note': 'A record of real tool runs. Cross-stack conformance on a finite corpus. It is not gate evidence, '
                'not a compiler proof, not a proof of the JavaScript and not a result of M1. A test count is not a proof.',
        'source_manifest': [{'path': name, 'sha256': before[name]} for name in sorted(SUBJECT)],
        'slice1_inputs_sha256': {name: before[name] for name in SLICE1},
        'approved_inputs_sha256': {name: before[name] for name in APPROVED},
        'm1_record_inputs_sha256': {name: before[name] for name in M1_RECORDS},
        'trusted_input_sha256': {name: before[name] for name in TRUSTED},
        'toolchain': main['toolchain'], 'verification_options': dafny.OPTIONS,
        'evidence': evidence, 'ids': main['ids'], 'compiled_core': main['compiled_core'],
        'm1_environment': main['m1_environment'], 'conformance': {key: main[key] for key in ('counts', 'checks_evaluated', 'findings')},
        'record_controls': records, 'core_controls': cores, 'm1_replay_audit': audit, 'trusted_base': TRUSTED_BASE,
    }


def attempt_folder(case):
    base = ROOT / 'build/m1-conformance' / case
    base.mkdir(parents=True, exist_ok=True)
    number = 1 + max([int(p.name.split('-')[1]) for p in base.glob('attempt-*')] or [0])
    return base / ('attempt-%04d' % number)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--case', required=True, choices=('conformance', 'record-controls', 'core-controls', 'm1-audit', 'evidence'))
    args = parser.parse_args()
    work = attempt_folder(args.case)
    print('M1-CONFORMANCE ' + args.case + ': ' + rel(work), flush=True)
    if args.case == 'conformance':
        result = conformance(Run(work))
        print('  counts: ' + canonical(result['counts']).decode().strip())
        print('  checks evaluated: ' + canonical(result['checks_evaluated']).decode().strip())
        print('  findings: 0')
    elif args.case == 'record-controls':
        rows = record_controls(Run(work))
        print('  planted faults and identity controls: %d of %d found or refused' % (len(rows), len(rows)))
    elif args.case == 'core-controls':
        rows = core_controls(Run(work))
        print('  wrong cores reported: %d of %d' % (len(rows), len(rows)))
    elif args.case == 'm1-audit':
        work.mkdir(parents=True)
        audit = m1_audit()
        (work / 'm1-audit.json').write_bytes(canonical(audit))
        print('  ' + canonical({key: audit[key] for key in ('cases', 'classes', 'recorded_wall_seconds_sum')}).decode().strip())
    else:
        work.mkdir(parents=True)
        bundles = []
        for number in (1, 2):
            print(' run ' + str(number), flush=True)
            run = Run(work / ('run-%d' % number))
            bundles.append(canonical(bundle_of(run)))
            (run.work / 'evidence.json').write_bytes(bundles[-1])
        require(bundles[0] == bundles[1], 'evidence: the two bundles differ')
        (work / 'evidence.json').write_bytes(bundles[0])
        print('  bundle: ' + rel(work / 'evidence.json') + ' sha256 ' + digest(bundles[0]) + ' (two runs, byte-identical)')
    print('M1-CONFORMANCE ' + args.case + ': PASSED; end_to_end=false; M1 open')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Failed as error:
        print('M1-CONFORMANCE FAILED: ' + str(error), file=sys.stderr)
        sys.exit(1)
    except Exception:  # a missing tool or a crash is not a negative result
        traceback.print_exc()
        sys.exit(2)
