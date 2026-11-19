/* TEST-ONLY executable: reads stdin, writes NOTHING, exit 0 (CE-2 shape). */
#include <unistd.h>
int main(void) { char b[4096]; while (read(0, b, sizeof b) > 0) {} return 0; }
