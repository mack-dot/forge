"""Install/check pinned public Cosign; never sign or authorize a release here."""
import argparse
import os
from pathlib import Path
import platform
import urllib.request

from common import (ROOT, HERE, Records, context, digest, fetch, parse, read,
                    require, sha, write)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--implementation-sha256', required=True)
    parser.add_argument('--producer-run')
    args = parser.parse_args()
    job = os.environ.get('GITHUB_JOB')
    require(job in ['proof', 'sign', 'negative'], 'APPROVED_JOB')
    records = Records(ROOT / ('results/stage9/producer-output/bootstrap-' + job))
    policy, _, _ = context(args.implementation_sha256)
    try:
        require(platform.system() == 'Darwin' and platform.machine() == 'arm64', 'RUNNER_PLATFORM')
        listener = Path(os.environ['RUNNER_WORKSPACE']).parents[1] / 'bin/Runner.Listener'
        _, version, _ = records.run([listener, '--version'], 'runner-version')
        pins = read(HERE / 'runtime.json')
        require(version.decode().strip() == pins['actions_runner']['version'], 'RUNNER_VERSION')
        request = parse(os.environ['FORGE_STAGE9_REQUEST'])
        require(os.environ['GITHUB_SHA'] == request['expected_source_commit'], 'DISPATCH_COMMIT')
        require(Path(os.environ['FORGE_STAGE7_ROOT']).resolve() != ROOT, 'PERSISTENT_PREREQUISITES_OUTSIDE_CHECKOUT')
        if args.producer_run:
            require(args.producer_run.isdecimal(), 'PRODUCER_RUN_ID')
            run = parse(fetch('https://api.github.com/repos/mack-dot/forge/actions/runs/' + args.producer_run,
                              records, 'producer-run'))
            require(run['conclusion'] == 'success' and run['event'] == 'workflow_dispatch'
                    and run['head_sha'] == request['expected_source_commit']
                    and run['path'] == '.github/workflows/provenance.yml'
                    and run['head_branch'] == 'main'
                    and run['repository']['id'] == policy['signer']['repository_id'], 'PRODUCER_RUN_IDENTITY')
        binary = ROOT / '.toolchain/stage9/cosign'
        expected = policy['signature']['executable_sha256']['darwin-arm64']
        if not binary.exists():
            url = 'https://github.com/sigstore/cosign/releases/download/v3.1.4/cosign-darwin-arm64'
            binary.parent.mkdir(parents=True, exist_ok=True)
            with urllib.request.urlopen(url) as response:
                data = response.read()
            require(sha(data) == expected, 'COSIGN_DOWNLOAD_DIGEST')
            staging = binary.with_suffix('.download')
            staging.write_bytes(data)
            staging.chmod(0o755)
            staging.replace(binary)
            write(records.directory / 'download.json', {'url': url, 'sha256': sha(data),
                                                       'authentication': 'approved_digest_and_https_bootstrap'})
        require(digest(binary) == expected, 'COSIGN_EXECUTABLE_DIGEST')
        records.run([binary, 'version', '--json'], 'cosign-version')
        write(records.directory / 'result.json', {'result': 'toolchain_inventory_only', 'end_to_end': False})
        return 0
    except Exception as error:
        write(records.directory / 'result.json', {'result': 'blocked', 'reason': str(error), 'end_to_end': False})
        raise


if __name__ == '__main__':
    raise SystemExit(main())
