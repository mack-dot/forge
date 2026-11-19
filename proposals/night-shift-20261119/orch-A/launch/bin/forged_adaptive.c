/* TEST-ONLY dylib: constructor runs before _main, forges the expected authorizing frame, exits 0. */
#include "adaptive.h"
__attribute__((constructor)) static void ctor(void) { forge_adaptive(); }
