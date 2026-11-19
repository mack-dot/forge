/* TEST-ONLY executable: reads stdin then aborts like the C FFI does on a bad configuration length. */
#include <unistd.h>
#include <stdlib.h>
int main(void) { char b[4096]; while (read(0, b, sizeof b) > 0) {} abort(); }
