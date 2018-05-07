#ifndef KERNEL_H
#define KERNEL_H

// Barebones "system calls" for bridging user/kernel modes
#define SYS_MODE 0
#define SYS_INT 1
#define SYS_TIMER 2
#define SYS_SCRATCH 3

// Second argument for certain system calls
#define MODE_KERNEL 0
#define MODE_USER 1
#define INT_HW5 0x8000
#define INT_HW4 0x4000
#define INT_HW3 0x2000
#define INT_HW2 0x1000
#define INT_HW1 0x0800
#define INT_HW0 0x0400
#define INT_SW1 0x0200
#define INT_SW0 0x0100
#define INT_ALL 0xff00
#define INT_NONE 0x000
#define INT_TIMER INT_HW5
#define INT_ENABLE 0x1
#define INT_DISABLE 0x0
#define TIMER_SET 0
#define TIMER_GET_COUNT 1
#define TIMER_GET_BELLS 2
#define SCRATCH_SET 0
#define SCRATCH_GET 1

// System call wrappers
void kernel_mode(void);
void user_mode(void);
void enable_int(int which);
void disable_int(int which);
void set_timer_cycles(int cycles);
unsigned int get_count_reg(void);
unsigned int get_timer_bells(void);
void set_scratch(unsigned int val);
unsigned int get_scratch(void);

// System call interface
unsigned int syscall_1(int arg0);
unsigned int syscall_2(int arg0, int arg1);
unsigned int syscall_3(int arg0, int arg1, int arg2);

#endif  // KERNEL_H
