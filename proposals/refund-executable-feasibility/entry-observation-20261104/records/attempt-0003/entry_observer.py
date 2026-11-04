"""Read one stopped process with LLDB. This does not prove machine semantics."""
import hashlib
import json
from pathlib import Path

import lldb

OUT = Path(__file__).resolve().parent
EXE_SHA = 'b8ed5ec2e34f4124af8368e4e8503e7b18c5476af9195765c55f85ca39007bb8'


def save(name, value):
    path = OUT / name
    assert not path.exists(), name
    path.write_text(json.dumps(value, indent=2) + '\n')


def capture(debugger, command, result, internal_dict):
    try:
        target = debugger.GetSelectedTarget()
        process = target.GetProcess()
        assert process.GetState() == lldb.eStateStopped
        thread = process.GetSelectedThread()
        assert thread.GetStopReason() == lldb.eStopReasonBreakpoint
        frame = thread.GetFrameAtIndex(0)
        breakpoint = target.GetBreakpointAtIndex(0)
        assert target.GetNumBreakpoints() == 1 and breakpoint.IsHardware()
        assert breakpoint.GetNumLocations() == 1
        stop_id = process.GetStopID()
        exe = Path(str(target.GetExecutable()))
        assert hashlib.sha256(exe.read_bytes()).hexdigest() == EXE_SHA

        entry = target.GetModuleAtIndex(0).ResolveFileAddress(0x1000040d0)
        assert entry.IsValid()
        pc = frame.GetPC()
        assert pc == entry.GetLoadAddress(target)
        registers = {}
        names = ['x' + str(i) for i in range(29)] + ['fp', 'lr', 'sp', 'pc', 'cpsr']
        for name in names:
            value = frame.FindRegister(name)
            assert value.IsValid() and value.GetError().Success(), name
            registers[name] = value.GetValueAsUnsigned()

        def read(address, size, filename):
            error = lldb.SBError()
            data = process.ReadMemory(address, size, error)
            assert error.Success() and len(data) == size, str(error)
            path = OUT / filename
            assert not path.exists()
            path.write_bytes(data)
            return {'address': address, 'bytes': size,
                    'sha256': hashlib.sha256(data).hexdigest(), 'file': filename}

        heap = registers['x1']
        header = read(heap, 40, 'heap-header.bin')
        pointers = []
        for index in range(5):
            error = lldb.SBError()
            address = process.ReadPointerFromMemory(heap + 8 * index, error)
            assert error.Success(), str(error)
            pointers.append(address)
        code = read(pc, 130436, 'loaded-code.bin')
        bitmaps = read(pointers[0], 2531 * 8, 'loaded-bitmaps.bin')

        regions = []
        addresses = sorted(set([pc, pc + 130435, heap, registers['x2'],
                                registers['x3'] - 1] + pointers))
        for address in addresses:
            info = lldb.SBMemoryRegionInfo()
            error = process.GetMemoryRegionInfo(address, info)
            assert error.Success(), str(error)
            regions.append({'queried_address': address,
                            'base': info.GetRegionBase(), 'end': info.GetRegionEnd(),
                            'mapped': info.IsMapped(), 'readable': info.IsReadable(),
                            'writable': info.IsWritable(), 'executable': info.IsExecutable()})
        modules = []
        for index in range(target.GetNumModules()):
            module = target.GetModuleAtIndex(index)
            modules.append({'path': str(module.GetFileSpec()),
                            'uuid': module.GetUUIDString(),
                            'header_load_address': module.GetObjectFileHeaderAddress().GetLoadAddress(target)})
        assert process.GetState() == lldb.eStateStopped and process.GetStopID() == stop_id
        record = {'actual_exit': 0, 'method': 'LLDB finite entry-state observation',
                  'executable': str(exe), 'executable_sha256': EXE_SHA,
                  'process_id': process.GetProcessID(), 'stop_id': stop_id,
                  'hardware_breakpoint': breakpoint.IsHardware(),
                  'pc': pc, 'entry_file_address': entry.GetFileAddress(),
                  'address_bytes': target.GetAddressByteSize(),
                  'registers': registers, 'heap_header': header,
                  'header_pointers': pointers, 'code': code, 'bitmaps': bitmaps,
                  'regions': regions, 'modules': modules,
                  'system_control_registers': 'UNOBSERVED',
                  'universal_runtime_correspondence': 'NOT_ESTABLISHED',
                  'end_to_end': False}
        save('entry-observation.json', record)
        result.AppendMessage('FORGE_ENTRY_OBSERVATION_COMPLETE')
    except Exception as error:
        save('entry-observation-error.json', {'actual_exit': 1, 'error': repr(error),
                                             'end_to_end': False})
        result.SetError(repr(error))


def finish(debugger, command, result, internal_dict):
    process = debugger.GetSelectedTarget().GetProcess()
    if process.GetState() != lldb.eStateExited:
        result.SetError('Target did not reach an observed process exit')
        return
    save('process-exit.json', {'actual_exit': process.GetExitStatus(),
                               'state': 'EXITED', 'end_to_end': False})
    result.AppendMessage('FORGE_OBSERVED_PROCESS_EXIT ' + str(process.GetExitStatus()))



def begin(debugger, command, result, internal_dict):
    try:
        target = debugger.GetSelectedTarget()
        debugger.SetAsync(False)
        entry = target.GetModuleAtIndex(0).ResolveFileAddress(0x1000040d0)
        assert entry.IsValid()
        bp = target.BreakpointCreateBySBAddress(entry)
        assert bp.IsValid() and bp.IsHardware() and bp.GetNumLocations() == 1
        launch = lldb.SBLaunchInfo([])
        launch.SetEnvironmentEntries(['LANG=C', 'LC_ALL=C', 'CML_HEAP_SIZE=256', 'CML_STACK_SIZE=256'], False)
        launch.SetWorkingDirectory(str(OUT))
        launch.SetLaunchFlags(lldb.eLaunchFlagDebug)
        stdin = '/Users/mackianni/forge/results/refund-native-audit-2026-11-04/attempt-0003/wire/eligible_duplicate.stdin'
        assert launch.AddOpenFileAction(0, stdin, True, False)
        assert launch.AddOpenFileAction(1, str(OUT / 'native.stdout'), False, True)
        assert launch.AddOpenFileAction(2, str(OUT / 'native.stderr'), False, True)
        error = lldb.SBError()
        process = target.Launch(launch, error)
        assert error.Success() and process.IsValid(), str(error)
        assert process.GetState() == lldb.eStateStopped
        result.AppendMessage('FORGE_ENTRY_LAUNCH_STOPPED')
    except Exception as error:
        save('launch-error.json', {'actual_exit': 1, 'error': repr(error), 'end_to_end': False})
        result.SetError(repr(error))


def resume(debugger, command, result, internal_dict):
    process = debugger.GetSelectedTarget().GetProcess()
    error = process.Continue()
    if error.Fail():
        result.SetError(str(error))
        return
    finish(debugger, command, result, internal_dict)


def __lldb_init_module(debugger, internal_dict):
    debugger.HandleCommand('command script add -f entry_observer.begin forge-entry-begin')
    debugger.HandleCommand('command script add -f entry_observer.capture forge-entry-observe')
    debugger.HandleCommand('command script add -f entry_observer.resume forge-entry-resume')
