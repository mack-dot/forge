#!/usr/bin/env python3
"""Run a registered checker backend, then enforce evidence identity and policy."""

import argparse
from pathlib import Path
import shlex
import sys
import tempfile
import xml.etree.ElementTree as ET

from common import ROOT, Rejected, canonical, read_json, relative
from dependencies import check_dependencies


def main():
    # Check pins before importing validator code used for acceptance.
    versions = check_dependencies()
    from backends import BACKENDS, DEFAULT_BACKEND, get_backend
    from core import (framework_paths, load_policy, make_bundle, snapshot,
                      validate_evidence, validate_schema)

    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend', choices=sorted(BACKENDS), default=DEFAULT_BACKEND)
    parser.add_argument('--impl', default='impl/Ledger.dfy')
    parser.add_argument('--evidence', default='evidence.json')
    parser.add_argument('--tier', default='critical')
    parser.add_argument('--check-evidence', help='Validate supplied evidence, then reproduce it before acceptance')
    parser.add_argument('--schema-only', metavar='JSON', help='Validate document structure only; never emits accepted evidence')
    args = parser.parse_args()
    if args.schema_only:
        if args.check_evidence:
            raise Rejected('CLI_SCOPE: schema-only and check-evidence cannot be combined')
        validate_schema(read_json((ROOT / args.schema_only).resolve()))
        print('SCHEMA_VALID: structure only; no proof, artifact acceptance, or provenance established')
        return 0

    implementation = (ROOT / args.impl).resolve()
    impl_name = relative(implementation)
    output = (ROOT / args.evidence).resolve()
    output_name = relative(output)
    if output.suffix != '.json' or output_name.split('/')[0] not in ('evidence.json', 'build'):
        raise Rejected('OUTPUT_SCOPE: write evidence.json or a JSON file under build/')
    supplied_path = (ROOT / args.check_evidence).resolve() if args.check_evidence else None
    if supplied_path == output:
        raise Rejected('OUTPUT_SCOPE: supplied evidence must differ from output path')
    output.unlink(missing_ok=True)

    backend = get_backend(args.backend)
    expected, backend_paths = backend.describe(impl_name)
    paths = framework_paths() + backend_paths
    before = snapshot(paths)
    source_paths = {entry['path'] for entry in expected.get('source_manifest', [])}
    trusted = {name: value for name, value in before.items() if name not in source_paths}
    rules, policy_identity = load_policy(args.tier)
    supplied = read_json(supplied_path) if supplied_path else None
    if supplied is not None:
        validate_evidence(supplied, expected, rules, policy_identity, trusted, args.backend)

    # Always run the established checker. Labels, hashes, and valid JSON do not
    # authorize an imported file to claim that a proof or test actually ran.
    raw = backend.verify(impl_name)
    reproduce = ('python3 gate/gate.py --backend ' + shlex.quote(args.backend)
                 + ' --impl ' + shlex.quote(impl_name) + ' --tier ' + shlex.quote(args.tier)
                 + ' --evidence evidence.json')
    bundle = make_bundle(raw, args.backend, policy_identity, trusted, versions, reproduce)
    validate_evidence(bundle, expected, rules, policy_identity, trusted, args.backend)
    if supplied is not None and canonical(supplied) != canonical(bundle):
        raise Rejected('REPRODUCTION_MISMATCH: supplied evidence differs from the fresh checker result')
    if snapshot(paths) != before:
        raise Rejected('INPUT_CHANGED: source, policy, schema, or trusted inputs changed while checking')
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='gate-result-', dir=ROOT / 'build') as temporary:
        candidate = Path(temporary) / 'evidence.json'
        candidate.write_bytes(canonical(bundle))
        candidate.replace(output)
    print('ACCEPTED: ' + ' '.join(sorted(rules['required_claims']))
          + '; backend=' + args.backend + '; tier=' + args.tier + '; end_to_end=false')
    return 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except Rejected as error:
        print(str(error), file=sys.stderr)
        sys.exit(1)
    except (OSError, ValueError, KeyError, RuntimeError, ImportError, ET.ParseError) as error:
        print('GATE_ERROR: ' + str(error), file=sys.stderr)
        sys.exit(2)
