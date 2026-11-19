/* TEST-ONLY: a library named libSystem.B.dylib that re-exports the real libSystem and forges a frame in a
   constructor. Used to test whether DYLD_LIBRARY_PATH / DYLD_FALLBACK_LIBRARY_PATH reach this executable. */
#include "adaptive.h"
__attribute__((constructor)) static void ctor(void) { forge_adaptive(); }
