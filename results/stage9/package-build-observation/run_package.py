"""Run only the installed producer.package() step under the approved lock.

No kernel replay, signature, workflow or container start. Exit 0 means the
installed gate accepted its own package identity checks. It is not a Stage 9
EXIT result.
"""
import argparse
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT / 'gate/provenance'))

from common import Records, Rejected, clean_environment, context  # noqa: E402
import producer  # noqa: E402


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    args.output.mkdir(parents=True, exist_ok=False)
    result = {'end_to_end': False, 'scope': 'producer.package() only'}
    try:
        clean_environment()
        policy, _, _ = context(args.implementation_sha256)
        records = Records(args.output / 'commands')
        descriptor = producer.package(policy, args.output, records)
        result.update({'accepted': True, 'descriptor': descriptor})
    except Rejected as error:
        result.update({'accepted': False, 'rejection': str(error)})
    (args.output / 'result.json').write_text(json.dumps(result, indent=2, sort_keys=True) + '\n')
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result['accepted'] else 1


if __name__ == '__main__':
    sys.exit(main())
