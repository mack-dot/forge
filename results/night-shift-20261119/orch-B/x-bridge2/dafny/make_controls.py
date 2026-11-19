"""x-bridge2: generate the Bridge2.dfy mutants (one exact replacement each) under controls/<name>/."""
import os, shutil, sys
D = os.path.dirname(os.path.abspath(__file__))
src = open(os.path.join(D, 'Bridge2.dfy')).read()
M = {
  'C1-drop-post': ('        if t.post != post then Refuse("POST_MISMATCH")\n        else if', '        if'),
  'C2-drop-intent': ('        else if t.intent != intent then Refuse("INTENT_MISMATCH")\n', ''),
  'C3-ignore-native': ('      var r := native(x);', '      var r := Some(AuthTuple(x));'),
  'C4-ignore-check': ('    else if !check(pre, t) then Refuse("CHECK_REFUSE")\n', ''),
  'C5-reject-all': ('        else Sign(F.Token(env.h(pre), env.dec(o.4), post, intent))',
                    '        else Refuse("ALL")'),
}
for name, (a, b) in M.items():
    assert src.count(a) == 1, name
    d = os.path.join(D, 'controls', name)
    os.makedirs(d, exist_ok=True)
    open(os.path.join(d, 'Bridge2.dfy'), 'w').write(src.replace(a, b))
    for sub in ('impl', 'spec'):
        if os.path.exists(os.path.join(d, sub)):
            shutil.rmtree(os.path.join(d, sub))
        shutil.copytree(os.path.join(D, sub), os.path.join(d, sub))
    print(name)
