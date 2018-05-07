#include "kernel.h"

void kernel_mode(void) {
  syscall_2(SYS_MODE, MODE_KERNEL);
}

void user_mode(void) {
  syscall_2(SYS_MODE, MODE_USER);
}

void enable_int(int which) {
  int mask = which | INT_ENABLE;
  syscall_2(SYS_INT, mask);
}

void disable_int(int which) {
  int mask = which | INT_DISABLE;
  syscall_2(SYS_INT, mask);
}

void set_timer_cycles(int cycles) {
  // Note: Does not enable timer interrupt (INT_TIMER)
  syscall_3(SYS_TIMER, TIMER_SET, cycles);
}

unsigned int get_count_reg(void) {
  return syscall_2(SYS_TIMER, TIMER_GET_COUNT);
}

unsigned int get_timer_bells(void) {
  return syscall_2(SYS_TIMER, TIMER_GET_BELLS);
}

void set_scratch(unsigned int val) {
  syscall_3(SYS_SCRATCH, SCRATCH_SET, val);
}

unsigned int get_scratch(void) {
  return syscall_2(SYS_SCRATCH, SCRATCH_GET);
}

unsigned int syscall_1(int arg0) {
  register unsigned int res asm ("v0");
  asm volatile(
      "move $a0, %[val]\n\t"
      "syscall\n\t"
      : "=r" (res)
      : [val] "r" (arg0)
      : "a0"
     );
  return res;
}

unsigned int syscall_2(int arg0, int arg1) {
  register unsigned int res asm ("v0");
  asm volatile(
      "move $a0, %[val0]\n\t"
      "move $a1, %[val1]\n\t"
      "syscall\n\t"
      : "=r" (res)
      : [val0] "r" (arg0), [val1] "r" (arg1)
      : "a0", "a1"
     );
  return res;
}

unsigned int syscall_3(int arg0, int arg1, int arg2) {
  register unsigned int res asm ("v0");
  asm volatile(
      "move $a0, %[val0]\n\t"
      "move $a1, %[val1]\n\t"
      "move $a2, %[val2]\n\t"
      "syscall\n\t"
      : "=r" (res)
      : [val0] "r" (arg0), [val1] "r" (arg1), [val2] "r" (arg2)
      : "a0", "a1", "a2"
     );
  return res;
}
