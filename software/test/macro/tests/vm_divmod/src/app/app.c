/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, wide column.
 *
 * Description:
 *   A sanity check for quotient and remainders.
 */
#include <stdint.h>

int main(void)
{
    uint32_t a, b;
    volatile uint32_t c, d;

    a = 29;
    b = 7;

    c = a / b;      // 4
    d = a % b;      // 1

    if ((c == 4) && (d == 1)) {
        return 1;
    }
    else {
        return 0;
    }
}

