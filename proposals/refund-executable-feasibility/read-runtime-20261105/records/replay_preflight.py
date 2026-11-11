from pathlib import Path
import hashlib, json, subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
OLD = OUT.parent / 'attempt-0009'
TC = ROOT / '.toolchain/experiments/refund-cakeml-20261104'
def sha(p):
    h = hashlib.sha256()
    with Path(p).open('rb') as f:
        for b in iter(lambda: f.read(1048576), b''): h.update(b)
    return h.hexdigest()

prep = json.loads((OLD / 'replay-preparation.json').read_text())
sources = prep['source_files']
assert len(sources) == 21
for name, item in sources.items():
    assert sha(item['original_path']) == item['sha256'], name
    assert sha(OLD / item['snapshot']) == item['sha256'], name
commands = []
for repo, pin in [('cakeml','cd9155694c16831373ab695a670794f23282ed62'),
                  ('HOL','9783a49979c94c401ff8c0e51b2eefae7ea95ae3'),
                  ('polyml','4557554077078decce4ce5f90da00a713cfc32e4')]:
    for args in [['rev-parse','HEAD'],['diff','--exit-code','HEAD','--']]:
        argv = ['git','-C',str(TC / repo)] + args
        r = subprocess.run(argv, capture_output=True, text=True)
        commands.append({'argv':argv,'actual_exit':r.returncode,'stdout':r.stdout,'stderr':r.stderr})
        (OUT / 'replay-preflight-commands.json').write_text(json.dumps(commands,indent=2)+'\n')
        assert r.returncode == 0, argv
        if args[0] == 'rev-parse': assert r.stdout.strip() == pin
pins = {
    str(TC / 'HOL/bin/hol'):'736c669e220381ddb6042fda624db79326aaa0075fe6ff9de4751bad75e8c4dd',
    str(TC / 'cakeml/misc/cakeml-heap'):'36f7c254cab336ae1a331a76024c94925e03f9f6774ef545742be5cf9ebd8247'}
for p,h in pins.items(): assert sha(p) == h, p
result = {
    'actual_exit':0,'source_snapshots_verified':21,'source_files':sources,
    'tool_identities_verified':pins,
    'source_git_checks':commands,
    'reviewer_controlled_clean_environment':'NOT_ESTABLISHED',
    'independent_source_acquisition_and_bootstrap_provenance':'NOT_ESTABLISHED',
    'cold_rebuild_with_published_build_machinery':'NOT_RUN',
    'independent_full_chain_replay':'NOT_RUN',
    'replay_gate':'NO_GO',
    'existing_environment_failure':'U301 records Docker socket operation not permitted. No changed environment is established; no retry or alternate access was attempted.',
    'next_action':'Validate an authorized reviewer-controlled ARM64/macOS environment and independent source/bootstrap provenance. Rebuild standard dependencies there without producer heaps or proof caches, then follow the unchanged 21-snapshot replay plan.',
    'scope':'Identity preflight only. Local git objects and producer hashes do not establish independent provenance or replay.',
    'end_to_end':False}
(OUT / 'replay-preflight.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps({k:v for k,v in result.items() if k not in ['source_files','source_git_checks']},indent=2))
