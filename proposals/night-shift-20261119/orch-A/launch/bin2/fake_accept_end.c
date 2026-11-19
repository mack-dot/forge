/* TEST-ONLY (W-launch round 2, F-01): reads stdin, writes the EXACT accept frame for the BASE request
   (c r 100 60 True True True 40 returned_item), then ends abnormally: argv-free; the variant is chosen at
   build time: -DEND_EXIT7 -> exit(7); -DEND_ABORT -> abort(). */
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
int main(void) {
  char b[4096]; while (read(0, b, sizeof b) > 0) {}
  const char *f = "(refund-result-v1 True 40 returned_item c r 1)";
  size_t n = strlen(f), w = 0; while (w < n) { ssize_t k = write(1, f + w, n - w); if (k <= 0) break; w += (size_t)k; }
#ifdef END_ABORT
  abort();
#else
  exit(7);
#endif
}
