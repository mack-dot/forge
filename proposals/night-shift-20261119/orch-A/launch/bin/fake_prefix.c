/* TEST-ONLY executable: reads stdin, writes a strict PREFIX of an authorizing frame (CE-1 shape), exit 0.
   argv[1] = "empty" writes nothing (CE-2 shape). */
#include <unistd.h>
#include <string.h>
int main(int argc, char **argv) {
  char b[4096]; while (read(0, b, sizeof b) > 0) {}
  if (argc > 1 && strcmp(argv[1], "empty") == 0) return 0;
  const char *f = "(refund-result-v1 True 40 retu"; write(1, f, strlen(f)); return 0;
}
