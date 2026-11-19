/* TEST-ONLY probe: prints the launch state it was given (env, cwd, fds, fd flags, signal mask, dispositions,
   rlimit core) as one line of key=value pairs on stdout. Used to test the spawn primitive of launcher.py. */
#include <stdio.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/stat.h>
#include <sys/resource.h>
#include <string.h>
extern char **environ;
int main(void) {
  char buf[4096]; while (read(0, buf, sizeof buf) > 0) {}
  int ne = 0; for (char **e = environ; *e; e++) ne++;
  printf("env_count=%d", ne);
  for (char **e = environ; *e; e++) if (strncmp(*e, "DYLD_", 5) == 0) printf(" dyld_var=%.40s", *e);
  char cwd[1024]; if (getcwd(cwd, sizeof cwd)) printf(" cwd=%s", cwd);
  printf(" fds=");
  for (int fd = 0; fd < 256; fd++) {
    int fl = fcntl(fd, F_GETFL); if (fl < 0) continue;
    struct stat st; fstat(fd, &st);
    printf("%d:%s%s%s,", fd, S_ISFIFO(st.st_mode) ? "fifo" : S_ISREG(st.st_mode) ? "reg" : S_ISCHR(st.st_mode) ? "chr" : S_ISDIR(st.st_mode) ? "dir" : "other",
           (fl & O_NONBLOCK) ? "+nonblock" : "", ((fl & O_ACCMODE) == O_RDONLY) ? "+ro" : ((fl & O_ACCMODE) == O_WRONLY) ? "+wo" : "+rw");
  }
  sigset_t m; sigprocmask(SIG_SETMASK, NULL, &m);
  printf(" blocked=");
  for (int s = 1; s < 32; s++) if (sigismember(&m, s)) printf("%d,", s);
  printf(" nondefault=");
  for (int s = 1; s < 32; s++) { struct sigaction a; if (sigaction(s, NULL, &a) == 0 && a.sa_handler != SIG_DFL) printf("%d,", s); }
  struct rlimit r; getrlimit(RLIMIT_CORE, &r); printf(" rlimit_core=%llu\n", (unsigned long long)r.rlim_cur);
  return 0;
}
