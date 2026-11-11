from pathlib import Path
import hashlib, json, subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent / 'native-readback'
OLD = OUT.parent.parent / 'attempt-0004'
OUT.mkdir(exist_ok=False)
records = []
def run(label, argv, cwd):
    with (OUT / (label + '.stdout')).open('wb') as stdout, (OUT / (label + '.stderr')).open('wb') as stderr:
        result = subprocess.run(argv, cwd=cwd, stdout=stdout, stderr=stderr)
    records.append({'label': label, 'argv': argv, 'cwd': str(cwd), 'actual_exit': result.returncode})
    (OUT / 'commands.json').write_text(json.dumps(records, indent=2) + '\n')
    assert result.returncode == 0, label
run('historical-chain', ['/usr/bin/shasum', '-a', '256', '-c', str(OLD / 'identity-0001/chain.sha256')], OLD / 'identity-0001')
identity = json.loads((OLD / 'identity-0001/result.json').read_text())
builds = []
for item in identity['builds']:
    executable = OLD / item['build'] / 'refund'
    data = executable.read_bytes()
    assert hashlib.sha256(data).hexdigest() == item['executable_sha256']
    code = data[item['code_file_offset']:item['code_file_offset'] + item['code_bytes']]
    bitmap = data[item['bitmap_file_offset']:item['bitmap_file_offset'] + item['bitmap_words'] * 8]
    assert hashlib.sha256(code).hexdigest() == item['code_sha256']
    assert hashlib.sha256(bitmap).hexdigest() == item['bitmap_sha256']
    run(item['build'] + '-signature', ['/usr/bin/codesign', '--verify', '--strict', '--verbose=2', str(executable)], ROOT)
    builds.append(item)
result = {'actual_exit': 0, 'existing_builds': builds,
          'standard_checksum_members': len((OLD / 'identity-0001/chain.sha256').read_text().splitlines()),
          'scope': 'Fresh read-only artifact/signature checks. Offsets reuse the preserved standard-tool layout. No loader or runtime refinement proof; no build, signing or native execution.',
          'end_to_end': False}
(OUT / 'result.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps(result, indent=2))
