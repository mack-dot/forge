# usage: python3 fsize.py <limit bytes> <cmd...> : RLIMIT_FSIZE in BYTES, SIGXFSZ ignored (write -> short count / EFBIG), exec.
import os, resource, signal, sys
lim = int(sys.argv[1]); signal.signal(signal.SIGXFSZ, signal.SIG_IGN)
resource.setrlimit(resource.RLIMIT_FSIZE, (lim, resource.getrlimit(resource.RLIMIT_FSIZE)[1]))
os.execv(sys.argv[2], sys.argv[2:])
