"""Read LLDB observations and run existing byte comparators; not a verifier."""
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path('/Users/mackianni/forge')
OUT = Path(__file__).resolve().parent
NATIVE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0004'
FIXTURE = ROOT / 'results/refund-native-audit-2026-11-04/attempt-0003/wire/eligible_duplicate.stdout'
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()
expected = {
    'loaded-code.bin': (NATIVE / 'compiled-extraction/code.bin', 130436,
                        '3c67983c93b3f7bbb340c2c517f6315ae2dc6260f2b401fb09d3b5a24ba15deb'),
    'loaded-bitmaps.bin': (NATIVE / 'identity-0001/expected-bitmaps.bin', 20248,
                           '68d3f080066fdaeb12ff1c061a875b1502172be0857a2af02f77f6f18f36fb76'),
    'native.stdout': (FIXTURE, FIXTURE.stat().st_size,
                       '629d44e9f09823060942f4b75007dcf87ddce9c505314a4b74f9ac19d9d84cee'),
}
assert not (OUT / 'capture-readback.json').exists()
observations = {}
for name in ['attempt-0005', 'attempt-repeat']:
    directory = OUT / name
    command = json.loads((directory / 'command.json').read_text())
    assert command['actual_exit'] == 0 and command['executable_unchanged'] is True
    assert command['executable_sha256'] == 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'
    assert sha(directory / 'commands.lldb') == command['commands_sha256']
    assert sha(Path(command['argv'][0])) == command['debugger_sha256']
    assert sha(Path(command['debugserver_path'])) == command['debugserver_sha256']
    log = (directory / 'debugger.log').read_text()
    assert 'error:' not in log
    assert 'stop reason = breakpoint 1.1' in log
    after_launch = log.split('(lldb) process launch ', 1)[1]
    assert 'resolved = true\n      hardware = true\n      hit count = 1' in after_launch
    assert 'target.require-hardware-breakpoint (boolean) = true' in log
    assert 'expression --allow-jit false -- unsigned long long $forge_bitmap = *(unsigned long long *)$x1' in log
    assert re.findall(r'Process (\d+) exited with status = (\d+)', log)
    assert all(code == '0' for _, code in re.findall(r'Process (\d+) exited with status = (\d+)', log))
    comparisons = {}
    for filename, (reference, size, digest) in expected.items():
        assert sha(reference) == digest
        assert (directory / filename).stat().st_size == size
        argv = ['/usr/bin/cmp', str(directory / filename), str(reference)]
        result = subprocess.run(argv, capture_output=True, text=True)
        comparisons[filename] = {'argv': argv, 'actual_exit': result.returncode,
                                  'stdout': result.stdout, 'stderr': result.stderr,
                                  'sha256': sha(directory / filename)}
        assert result.returncode == 0 and sha(directory / filename) == digest
    assert (directory / 'native.stderr').read_bytes() == b''
    blocks = log.split('(lldb) register read ')[1:]
    first = dict((key, int(value, 16)) for key, value in re.findall(
        r'^\s*(x\d+|fp|lr|sp|pc|cpsr) = (0x[0-9a-f]+)', blocks[0].split('(lldb)', 1)[0], re.M))
    last = dict((key, int(value, 16)) for key, value in re.findall(
        r'^\s*(x\d+|fp|lr|sp|pc|cpsr) = (0x[0-9a-f]+)', blocks[1].split('(lldb)', 1)[0], re.M))
    assert len(first) == 34 and len(last) == 9
    assert all(first[k] == value for k, value in last.items())
    header_text = log.split('(lldb) memory read --format hex --size 8 --count 5 $x1\n')[1].split('(lldb)', 1)[0]
    pointers = [int(word, 16) for line in header_text.splitlines()
                for word in re.findall(r'0x[0-9a-f]+', line.split(':', 1)[1])]
    assert len(pointers) == 5
    od_argv = ['/usr/bin/od', '-An', '-tx8', '-v', str(directory / 'heap-header.bin')]
    od = subprocess.run(od_argv, capture_output=True, text=True)
    assert od.returncode == 0 and [int(x, 16) for x in od.stdout.split()] == pointers
    base_match = re.search(r'^\[\s*0\] 5BC31322-6FFB-3F8C-8ECE-14B4C92E95BB (0x[0-9a-f]+) .*?/refund\s*$', log, re.M)
    assert base_match
    module_base = int(base_match.group(1), 16)
    derived = {
        'pc_matches_loaded_file_entry': first['pc'] == module_base + 0x40d0,
        'pc_4_byte_aligned': first['pc'] % 4 == 0,
        'sp_16_byte_aligned': first['sp'] % 16 == 0,
        'entry_x0_equals_pc': first['x0'] == first['pc'],
        'heap_stack_bounds_ordered': first['x1'] < first['x2'] < first['x3'],
        'heap_stack_boundaries_word_aligned': all(first[x] % 8 == 0 for x in ['x1', 'x2', 'x3']),
        'heap_stack_span_at_least_1024_words': first['x3'] - first['x1'] >= 8192,
        'bitmap_bound_is_2531_words': pointers[1] == pointers[0] + 20248,
        'extra_data_words_observed_zero': pointers[2] == pointers[1],
        'code_end_matches_pc_plus_130436': pointers[3] == first['pc'] + 130436,
        'code_buffer_bound_ordered_without_wrap': pointers[3] <= pointers[4] < 2**64,
        'bitmap_interval_disjoint_from_heap_stack': pointers[1] <= first['x1'] or first['x3'] <= pointers[0],
    }
    assert all(derived.values())
    observations[name] = {'debugger_exit': command['actual_exit'], 'native_exit': 0,
        'registers_at_entry': first, 'registers_rechecked_before_resume': last,
        'loaded_module_base': module_base, 'heap_header_pointers': pointers,
        'header_word_reader': {'argv': od_argv, 'actual_exit': od.returncode, 'stdout': od.stdout},
        'comparisons': comparisons, 'derived_scalar_relationships': derived,
        'code_buffer_bytes_observed': pointers[4] - pointers[3],
        'system_control_registers': 'UNOBSERVED', 'complete_installed_relation': 'NOT_ESTABLISHED',
        'universal_concrete_model_correspondence': 'NOT_ESTABLISHED',
        'observer_producer_authentication': 'NOT_ESTABLISHED', 'end_to_end': False}

assert (OUT / 'attempt-0005/run.py').read_bytes() == (OUT / 'attempt-repeat/run.py').read_bytes()
assert observations['attempt-0005']['registers_at_entry']['pc'] != observations['attempt-repeat']['registers_at_entry']['pc']
controls = OUT / 'capture-controls'
controls.mkdir()
mutant = controls / 'altered-code.bin'
data = bytearray((OUT / 'attempt-0005/loaded-code.bin').read_bytes())
data[0] ^= 1
mutant.write_bytes(data)
argv = ['/usr/bin/cmp', str(mutant), str(expected['loaded-code.bin'][0])]
negative = subprocess.run(argv, capture_output=True, text=True)
assert negative.returncode == 1 and 'differ:' in negative.stdout
result = {'actual_exit': 0, 'scope': 'Finite observations and exact byte identity only',
    'observations': observations,
    'corrupted_observation_control': {'argv': argv, 'actual_exit': negative.returncode,
        'stdout': negative.stdout, 'stderr': negative.stderr, 'mutant_sha256': sha(mutant),
        'mutant_execution': 'NOT RUN'},
    'historical_substituted_bitmap_comparison_exit': 1,
    'observer_source_reproduced': True, 'distinct_observed_load_addresses': True,
    'end_to_end': False}
(OUT / 'capture-readback.json').write_text(json.dumps(result, indent=2) + '\n')
print(json.dumps({'actual_exit': 0, 'captures': list(observations),
    'comparison_exits': [x['actual_exit'] for v in observations.values() for x in v['comparisons'].values()],
    'corrupted_observation_exit': negative.returncode, 'end_to_end': False}))
