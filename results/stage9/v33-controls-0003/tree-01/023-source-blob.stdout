"""Observe actual deployed bytes. No guest execution or deployment proof claim."""
import argparse
from pathlib import Path
import sqlite3

from common import Rejected, Records, context, parse, require, sha, write
from producer import runtime
from release import pending, verify


def observe(policy, request, container, records):
    _, data, _ = records.run(['docker', 'inspect', container], 'inspect-before')
    before = parse(data)[0]
    require(before['Id'] == container and before['State']['Running'], 'DEPLOYMENT_NOT_RUNNING')
    # Read through the actual running namespace, including any effective mount.
    _, observed, _ = records.run(['docker', 'exec', '--user', '1000:1000', container,
                                  'cat', policy['deployment']['path']], 'observed-elf')
    _, data, _ = records.run(['docker', 'inspect', container], 'inspect-after')
    after = parse(data)[0]
    observation = {'container_id': container, 'path': policy['deployment']['path'],
                   'observed_sha256': sha(observed), 'expected_sha256': request['artifact_sha256'],
                   'actual_image': before['Image'], 'expected_image': 'sha256:' + request['package_sha256'],
                   'mounts_before': before['Mounts'], 'mounts_after': after['Mounts'],
                   'scope': 'deployed_file_identity', 'end_to_end': False,
                   'riscv_execution_claimed': False, 'deployment_correctness_proved': False,
                   'challenge': request['challenge']}
    write(records.directory / 'observation.json', observation)
    require(sha(observed) == policy['release_artifact']['sha256'] == request['artifact_sha256'],
            'DEPLOYED_ARTIFACT_MISMATCH')
    require(before['Id'] == after['Id'] and before['Image'] == after['Image']
            and after['State']['Running'], 'DEPLOYMENT_CHANGED')
    require(before['Image'] == 'sha256:' + request['package_sha256'], 'DEPLOYED_PACKAGE_MISMATCH')
    require(before['Mounts'] == after['Mounts'] == [], 'DEPLOYMENT_MOUNT_OBSCURES_IDENTITY')
    for state in [before, after]:
        require(state['Config']['User'] == '1000:1000'
                and state['HostConfig']['ReadonlyRootfs']
                and state['HostConfig']['NetworkMode'] == 'none'
                and state['HostConfig']['Privileged'] is False, 'DEPLOYMENT_ISOLATION')
    return observation


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--candidate', type=Path, required=True)
    p.add_argument('--controller', type=Path, required=True)
    p.add_argument('--challenge', required=True)
    p.add_argument('--implementation-sha256', required=True)
    p.add_argument('--records', type=Path, required=True)
    p.add_argument('--case', choices=['accepted', 'substitution'], required=True)
    args = p.parse_args()
    records = Records(args.records)
    container = None
    try:
        policy, _, _ = context(args.implementation_sha256)
        runtime(records)
        require(not args.controller.resolve().is_relative_to(args.candidate.resolve()), 'CONTROLLER_LOCATION')
        connection = sqlite3.connect('file:' + str(args.controller.resolve()) + '?mode=rw', uri=True)
        try:
            connection.execute('BEGIN IMMEDIATE')
            if args.case == 'accepted':
                request = pending(connection, args.challenge)
            else:
                # Test-only additional container for the already admitted request.
                # It is labelled as a security fixture, never as another release.
                row = connection.execute('SELECT request,state FROM requests WHERE challenge=?',
                                         (args.challenge,)).fetchone()
                require(row is not None and row[1] == 'consumed', 'NEGATIVE_REQUIRES_PRIOR_ADMISSION')
                request = parse(row[0])
            verification = Records(args.records / 'signature')
            verify(args.candidate, request, args.implementation_sha256, verification)
            if args.case == 'accepted':
                connection.execute("UPDATE requests SET state='consumed' WHERE challenge=?", (args.challenge,))
                connection.commit()
            else:
                connection.rollback()
        finally:
            connection.close()
        command = ['docker', 'create', '--platform', 'linux/amd64', '--network', 'none',
                   '--read-only', '--user', '1000:1000', '--cap-drop', 'ALL',
                   '--security-opt', 'no-new-privileges:true', '--cpuset-cpus', '0',
                   '--memory', '256m', '--memory-swap', '256m', '--pids-limit', '64',
                   '--label', 'forge.stage9.role=' + args.case]
        if args.case == 'substitution':
            wrong = args.records.resolve() / 'substituted.elf'
            wrong.write_bytes(b'Actual Stage 9 deployed substitution control\n')
            wrong.chmod(0o444)
            command += ['--mount', f'type=bind,source={wrong},target={policy["deployment"]["path"]},readonly']
        command += ['sha256:' + request['package_sha256']]
        _, data, _ = records.run(command, 'deployment-create')
        container = data.decode().strip()
        records.run(['docker', 'start', container], 'deployment-start')
        result = observe(policy, request, container, records)
        require(args.case == 'accepted', 'SUBSTITUTION_CONTROL_UNEXPECTEDLY_ACCEPTED')
        write(args.records / 'result.json', {'result': 'observed_deployed_file_identity',
                                           'observation': result, 'end_to_end': False})
        return 0
    except (Rejected, OSError, ValueError, KeyError, sqlite3.Error) as error:
        write(args.records / 'result.json', {'result': 'rejected', 'reason': str(error),
                                           'end_to_end': False})
        return 1
    finally:
        if container:
            # Stop only this invocation's idle fixture; retain its filesystem.
            records.run(['docker', 'stop', container], 'deployment-stop', check=False)


if __name__ == '__main__':
    raise SystemExit(main())
