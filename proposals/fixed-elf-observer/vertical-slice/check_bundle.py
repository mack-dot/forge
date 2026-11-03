"""Run the unchanged historical consumer without controller or admission operations."""
import hashlib
import json
from pathlib import Path
import runpy
import sys

SOURCE = Path('/Users/mackianni/forge-stage9-signing-0003/exit-main')
BASE = Path('/Users/mackianni/forge-stage9-signing-0003/artifacts/r1-signed/x')
LOCK = '5f78da2142699d51f4b9b47c41ba3202919196af575fee3ae67bed7f7ad264b0'

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def main():
    assert sys.flags.isolated and sys.flags.no_site and sys.flags.dont_write_bytecode
    assert sys.version_info[:3] == (3, 10, 11)
    expected = {SOURCE/'gate/provenance/implementation.lock':LOCK,
      SOURCE/'gate/provenance/bootstrap.py':'8895a0881586dfcdf844fca8c09ec8bac662cbbc158cadb19084cfc5a5385bbf',
      BASE/'request.json':'16f72dd1e0edd16f818a21e89304ed098a45408bce6d1ff087a3c24a4fa575be',
      BASE/'release.sigstore.json':'cd2a87db8dd780cb1231533dfc214315b8611950d3cc27c94bb77444ed8c5a2a'}
    assert all(sha(p)==h for p,h in expected.items()), 'BASELINE_IDENTITY'
    runpy.run_path(str(SOURCE/'gate/provenance/bootstrap.py'))['check'](LOCK)
    sys.path.insert(0,str(SOURCE/'gate/provenance'))
    from common import Records, Rejected, context, read, signature, write
    from release import verify
    candidate,out=Path(sys.argv[1]).resolve(),Path(sys.argv[2]).resolve()
    out.mkdir(parents=True,exist_ok=False)
    records=Records(out/'commands')
    result={'result':'NOT_ESTABLISHED','controller_read':False,'admitted':False,
            'signed':False,'deployed':False,'cross_run_cache_adopted':False,'end_to_end':False}
    try:
        if len(sys.argv)>3 and sys.argv[3]=='own-artifact-signature':
            policy,_,_=context(LOCK)
            code,_,_=signature(policy,candidate/'release.sigstore.json',
                 BASE/'controls/wrong-digest/different.bin',
                 '624c9fafccd3badaa6a9dd582ae33f1204fb1e3a',records)
            if code:
                result.update(result='rejected',reason='SIGNATURE_REJECTED',gate_exit_code=1)
                return 1
            result.update(result='authenticated_control_signature',signature_exit_code=0,gate_exit_code=0)
            return 0
        verified=verify(candidate,read(BASE/'request.json'),LOCK,records)
        result.update(verified,gate_exit_code=0)
        return 0
    except Rejected as error:
        result.update(result='rejected',reason=error.reason,gate_exit_code=1)
        return 1
    except Exception as error:
        result.update(result='NOT_ESTABLISHED',setup_error=type(error).__name__+': '+str(error))
        raise
    finally:
        write(out/'result.json',result)
        print(json.dumps(result,sort_keys=True))

if __name__=='__main__':
    raise SystemExit(main())
