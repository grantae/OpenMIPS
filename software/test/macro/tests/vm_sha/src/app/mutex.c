#include "mutex.h"

void mutex_init(int *mutex) {
  *mutex = 0;
}

void mutex_lock(int *mutex) {
  int val, tmp;
  asm volatile(
      ".set noreorder\n\t"
      "$test_and_set_%=:\n\t"
      "ll %[val], 0(%[mutex])\n\t"
      "bnez %[val], $test_and_set_%=\n\t"
      "li %[tmp], 0x1\n\t"
      "sc %[tmp], 0(%[mutex])\n\t"
      "beqz %[tmp], $test_and_set_%=\n\t"
      "nop\n\t"
      ".set reorder\n\t"
      : [val] "=&r" (val), [tmp] "=&r" (tmp)
      : [mutex] "r" (mutex)
      : "memory"
  );
}
bool mutex_try_lock(int *mutex) {
  int val, tmp;
  bool locked;
  asm volatile(
      ".set noreorder\n\t"
      "li %[locked], 0\n\t"
      "$test_and_set_%=:\n\t"
      "ll %[val], 0(%[mutex])\n\t"
      "bnez %[val], $done_%=\n\t"
      "li %[tmp], 0x1\n\t"
      "sc %[tmp], 0(%[mutex])\n\t"
      "beqz %[tmp], $test_and_set_%=\n\t"
      "nop\n\t"
      "li %[locked], 0x1\n\t"
      "$done_%=:\n\t"
      ".set reorder\n\t"
      : [val] "=&r" (val), [tmp] "=&r" (tmp), [locked] "=r" (locked)
      : [mutex] "r" (mutex)
      : "memory"
  );
  return locked;
}

void mutex_unlock(int *mutex) {
  *mutex = 0;
}
