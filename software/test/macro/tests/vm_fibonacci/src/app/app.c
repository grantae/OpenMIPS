/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, wide column.
 *
 * Description:
 *   Test function calling and the stack with a recursive
 *   Fibonacci computation
 */
#include <stdint.h>

uint32_t fib(uint32_t x)
{
    if (x == 0) {
        return 0;
    }
    else if (x == 1) {
        return 1;
    }
    else {
        return fib(x-1) + fib(x-2);
    }
}

int main(void)
{
    uint32_t expected = 377;
    volatile uint32_t result = fib(14);

    if (expected == result) {
        return 1;
    }
    else {
        return 0;
    }
}

