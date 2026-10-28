"""Run only the installed producer.replay() step on a hosted runner.

Measurement only. No package, statement, signature or deployment. Exit 0 means
the fresh proof ran and its receipt passed the installed validate_receipt().
It is not a Stage 9 EXIT result.
"""
import argparse
import json
import os
import secrets
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'gate/provenance'))

from common import Records, Rejected, clean_environment, context  # noqa: E402
import producer  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    result = {'end_to_end': False, 'scope': 'producer.replay() only'}
    try:
        clean_environment()
        policy, lock, implementation = context(args.implementation_sha256)
        request = {'challenge': secrets.token_hex(32),
                   'expected_source_commit': os.environ['GITHUB_SHA']}
        records = Records(args.output / 'commands')
        producer.replay(policy, lock, implementation, request, args.output, records)
        result.update({'accepted': True, 'expected_source_commit': request['expected_source_commit']})
    except Rejected as error:
        result.update({'accepted': False, 'rejection': error.reason})
    except Exception as error:  # setup error, not a security rejection
        result.update({'accepted': False, 'setup_error': type(error).__name__ + ': ' + str(error)})
    (args.output / 'result.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result['accepted'] else 1


if __name__ == '__main__':
    sys.exit(main())
