/* TEST-ONLY (F-07): closes stdin at once (the launcher's request write gets EPIPE), waits 0.2 s, then writes
   the exact accept frame for the BASE request and exits 0. */
#include <unistd.h>
#include <string.h>
int main(void) {
  close(0); usleep(200000);
  const char *f = "(refund-result-v1 True 40 returned_item c r 1)"; write(1, f, strlen(f)); return 0;
}
