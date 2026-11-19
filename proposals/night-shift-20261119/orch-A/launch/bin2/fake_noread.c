/* TEST-ONLY (F-02): never reads stdin; sleeps 30 s. A large request then fills the stdin pipe. */
#include <unistd.h>
int main(void) { sleep(30); return 0; }
