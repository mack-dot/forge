/* A23 unit harness: calls one basis_ffi.c FFI function per forked child with a chosen argument shape.
   Prints: case id, outcome (RET or SIG<n> or EXIT<n>), and the hex of the allocated array (guards included).
   FINITE TEST, not a proof. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <sys/mman.h>
typedef void (*ffi_t)(unsigned char *, long, unsigned char *, long);
void ffiread(unsigned char *, long, unsigned char *, long);
void ffiwrite(unsigned char *, long, unsigned char *, long);
void fficlose(unsigned char *, long, unsigned char *, long);
void ffiopen_in(unsigned char *, long, unsigned char *, long);
#define G 8
int main(int argc, char **argv) {
  /* line format (stdin): id fn clen confhex alen buflen arrhex */
  char id[64], fn[16], confhex[256], arrhex[512]; long clen, alen, buflen;
  int devnull = open("/dev/null", O_WRONLY);
  while (scanf("%63s %15s %ld %255s %ld %ld %511s", id, fn, &clen, confhex, &alen, &buflen, arrhex) == 7) {
    fflush(stdout);
    int out[2]; pipe(out);
    int in[2]; pipe(in); write(in[1], "HELLO-STDIN", 11); close(in[1]);
    pid_t p = fork();
    if (p == 0) {
      dup2(in[0], 0); dup2(devnull, 1); dup2(devnull, 2);
      unsigned char conf[128]; memset(conf, 0, sizeof conf);
      size_t cl = strcmp(confhex, "-") ? strlen(confhex) / 2 : 0;
      for (size_t i = 0; i < cl; i++) sscanf(confhex + 2 * i, "%2hhx", &conf[i]);
      unsigned char *buf = calloc(buflen + 2 * G, 1);
      memset(buf, 0xEE, buflen + 2 * G);
      size_t al = strcmp(arrhex, "-") ? strlen(arrhex) / 2 : 0;
      for (size_t i = 0; i < al && i < (size_t) buflen; i++) sscanf(arrhex + 2 * i, "%2hhx", &buf[G + i]);
      ffi_t f = !strcmp(fn, "read") ? ffiread : !strcmp(fn, "write") ? ffiwrite :
                !strcmp(fn, "close") ? fficlose : ffiopen_in;
      f(conf, clen, buf + G, alen);
      char line[4096]; int k = 0;
      for (long i = 0; i < buflen + 2 * G && k < 4000; i++) k += sprintf(line + k, "%02x", buf[i]);
      write(out[1], line, k);
      _exit(0);
    }
    close(out[1]); close(in[0]);
    char res[4096]; int n = 0, r;
    while ((r = read(out[0], res + n, sizeof res - 1 - n)) > 0) n += r;
    res[n] = 0; close(out[0]);
    int st; waitpid(p, &st, 0);
    if (WIFSIGNALED(st)) printf("%s SIG%d -\n", id, WTERMSIG(st));
    else if (n == 0) printf("%s EXIT%d -\n", id, WEXITSTATUS(st));
    else printf("%s RET %s\n", id, res);
  }
  return 0;
}
