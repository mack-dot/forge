/* TEST-ONLY caller wrapper (W-launch round 2, F-03). Sets a task exception port on ITSELF (a receive right it
   owns and never services) for EXC_MASK_BAD_ACCESS|EXC_MASK_BAD_INSTRUCTION|EXC_MASK_SOFTWARE|EXC_MASK_BREAKPOINT,
   prints the kern_return to stderr, then execv(argv[1], argv+1). It never handles a message and never
   obtains another task's port. Used only to see whether the setting is inherited down to the launcher's child. */
#include <stdio.h>
#include <unistd.h>
#include <mach/mach.h>
int main(int argc, char **argv) {
  if (argc < 2) return 2;
  mach_port_t p = MACH_PORT_NULL;
  kern_return_t a = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &p);
  kern_return_t b = mach_port_insert_right(mach_task_self(), p, p, MACH_MSG_TYPE_MAKE_SEND);
  kern_return_t c = task_set_exception_ports(mach_task_self(),
      EXC_MASK_BAD_ACCESS | EXC_MASK_BAD_INSTRUCTION | EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT,
      p, EXCEPTION_DEFAULT, THREAD_STATE_NONE);
  fprintf(stderr, "excport_exec: alloc=%d insert=%d set=%d\n", a, b, c);
  execv(argv[1], argv + 1);
  perror("execv"); return 127;
}
