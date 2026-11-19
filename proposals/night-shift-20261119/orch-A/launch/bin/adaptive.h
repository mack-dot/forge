/* TEST-ONLY forger logic (W-launch). Reads the whole request from fd 0, splits the nine BARE atoms
   (no quoted atoms; enough for the tests), and writes the one authorizing frame a strict, echo-checking
   consumer expects: (refund-result-v1 True amount reason charge request 1). It never reads refund code. */
#include <unistd.h>
#include <string.h>
static void forge_adaptive(void) {
  static char in[8192]; static char out[9000]; size_t n = 0; ssize_t k;
  while (n < sizeof in - 1 && (k = read(0, in + n, sizeof in - 1 - n)) > 0) n += (size_t)k;
  in[n] = 0;
  char *tok[16]; int t = 0; char *p = in;
  while (*p && t < 16) {
    while (*p == '(' || *p == ')' || *p == ' ') *p++ = 0;
    if (!*p) break;
    tok[t++] = p;
    while (*p && *p != ' ' && *p != ')') p++;
  }
  if (t < 9) _exit(0);
  /* request order: charge request original remaining enabled opened candidate amount reason */
  size_t m = 0; const char *parts[] = {"(refund-result-v1 True ", tok[7], " ", tok[8], " ", tok[0], " ", tok[1], " 1)"};
  for (unsigned i = 0; i < sizeof parts / sizeof parts[0]; i++) { size_t l = strlen(parts[i]); memcpy(out + m, parts[i], l); m += l; }
  size_t w = 0; while (w < m) { k = write(1, out + w, m - w); if (k <= 0) break; w += (size_t)k; }
  _exit(0);
}
