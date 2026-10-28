/* A freestanding Linux/RISC-V self-test. No C runtime is linked.
   The binary claim covers this fixed input pair, not arbitrary GCD inputs. */
void _start(void) {
    unsigned long a = 1071;
    unsigned long b = 462;

    /* Keep the arithmetic loop in the executable. This emits no instruction. */
    __asm__ volatile ("" : "+r"(a), "+r"(b));
    while (b != 0) {
        unsigned long remainder = a % b;
        a = b;
        b = remainder;
    }

    register unsigned long status __asm__("a0") = a == 21 ? 0 : 2;
    register unsigned long syscall_number __asm__("a7") = 94; /* exit_group */
    __asm__ volatile ("ecall" : : "r"(status), "r"(syscall_number) : "memory");
    for (;;) { }
}
