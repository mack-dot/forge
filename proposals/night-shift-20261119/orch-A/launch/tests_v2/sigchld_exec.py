"""TEST caller wrapper (W-launch round 2, F-01). usage: sigchld_exec.py MODE PROG ARGS...
MODE ign      : signal(SIGCHLD, SIG_IGN) then execv.
MODE nocldwait: sigaction(SIGCHLD, {SIG_DFL, SA_NOCLDWAIT}) via ctypes, then execv.
MODE none     : execv only (control)."""
import ctypes, os, signal, sys
mode, argv = sys.argv[1], sys.argv[2:]
if mode == 'ign':
    signal.signal(signal.SIGCHLD, signal.SIG_IGN)
elif mode == 'nocldwait':
    class SA(ctypes.Structure):     # macOS struct sigaction (user): handler, mask (uint32), flags (int)
        _fields_ = [('handler', ctypes.c_void_p), ('mask', ctypes.c_uint32), ('flags', ctypes.c_int)]
    libc = ctypes.CDLL('/usr/lib/libSystem.B.dylib', use_errno=True)
    sa = SA(None, 0, 0x0020)       # SA_NOCLDWAIT = 0x0020 (sys/signal.h)
    rc = libc.sigaction(signal.SIGCHLD, ctypes.byref(sa), None)
    sys.stderr.write('sigchld_exec: sigaction rc=%d errno=%d\n' % (rc, ctypes.get_errno()))
os.execv(argv[0], argv)
