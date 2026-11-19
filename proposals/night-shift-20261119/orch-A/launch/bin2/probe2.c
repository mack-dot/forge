/* TEST-ONLY probe v2 (W-launch round 2): prints the launch state on stdout, one line: env count, cwd, fds,
   O_NONBLOCK, mask, non-default dispositions, sid==pid, pgid==pid, controlling tty, umask, rlimits
   (CORE, STACK, FSIZE, CPU, NOFILE, DATA), task exception ports that are not MACH_PORT_NULL (count and masks),
   and EXC_MASK_ALL. Reads and closes nothing it did not open. */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <string.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <mach/mach.h>
extern char **environ;
static void rl(const char *n, int r) { struct rlimit x; getrlimit(r, &x);
  printf(" %s=%lld/%lld", n, x.rlim_cur == RLIM_INFINITY ? -1LL : (long long)x.rlim_cur,
         x.rlim_max == RLIM_INFINITY ? -1LL : (long long)x.rlim_max); }
int main(void) {
  char buf[4096]; while (read(0, buf, sizeof buf) > 0) {}
  int ne = 0; for (char **e = environ; *e; e++) ne++;
  printf("env_count=%d", ne);
  char cwd[1024]; if (getcwd(cwd, sizeof cwd)) printf(" cwd=%s", cwd);
  printf(" fds=");
  for (int fd = 0; fd < 1024; fd++) { int fl = fcntl(fd, F_GETFL); if (fl < 0) continue;
    struct stat st; fstat(fd, &st); printf("%d:%s%s,", fd, S_ISFIFO(st.st_mode) ? "fifo" : "other", (fl & O_NONBLOCK) ? "+nb" : ""); }
  sigset_t m; sigprocmask(SIG_SETMASK, NULL, &m); printf(" blocked=");
  for (int s = 1; s < 32; s++) if (sigismember(&m, s)) printf("%d,", s);
  printf(" nondefault=");
  for (int s = 1; s < 32; s++) { struct sigaction a; if (sigaction(s, NULL, &a) == 0 && (a.sa_handler != SIG_DFL || (a.sa_flags & SA_NOCLDWAIT))) printf("%d,", s); }
  pid_t p = getpid(); printf(" sid_is_pid=%d pgid_is_pid=%d", getsid(0) == p, getpgrp() == p);
  int t = open("/dev/tty", O_RDWR | O_NOCTTY); printf(" ctty=%d", t >= 0); if (t >= 0) close(t);
  mode_t um = umask(0); umask(um); printf(" umask=%03o", um);
  rl("core", RLIMIT_CORE); rl("stack", RLIMIT_STACK); rl("fsize", RLIMIT_FSIZE); rl("cpu", RLIMIT_CPU);
  rl("nofile", RLIMIT_NOFILE); rl("data", RLIMIT_DATA);
  exception_mask_t masks[32]; mach_msg_type_number_t cnt = 32; mach_port_t ports[32];
  exception_behavior_t beh[32]; thread_state_flavor_t fl[32];
  kern_return_t kr = task_get_exception_ports(mach_task_self(), EXC_MASK_ALL | EXC_MASK_CRASH | EXC_MASK_CORPSE_NOTIFY,
                                              masks, &cnt, ports, beh, fl);
  int set = 0; printf(" excports_kr=%d excports_set_masks=", kr);
  if (kr == KERN_SUCCESS) for (unsigned i = 0; i < cnt; i++) if (MACH_PORT_VALID(ports[i])) { set++; printf("0x%x,", masks[i]); }
  printf(" excports_set=%d exc_mask_all=0x%x\n", set, (unsigned)EXC_MASK_ALL);
  return 0;
}
