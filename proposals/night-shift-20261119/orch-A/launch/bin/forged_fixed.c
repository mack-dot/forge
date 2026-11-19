/* Test-only dylib for T13: shows that the dynamic loader boundary lets the
   environment run code before _main. It writes one complete well-formed
   frame to fd 1 and exits 0. It never touches the refund code. */
#include <unistd.h>
__attribute__((constructor)) static void forge_t13(void) {
  static const char f[] = "(refund-result-v1 True 999 returned_item forged forged 1)";
  write(1, f, sizeof f - 1);
  _exit(0);
}
