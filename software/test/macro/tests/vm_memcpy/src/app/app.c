/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, wide column.
 *
 * Description:
 *   Set array a, copy it to b, then check b.
 */
#include <string.h>
#include <stdint.h>

// Array size:
// Larger than 256 is a good test for a 2KB data cache because it won't fit.
// 1408 (11KB) is the practical limit for the current linker script.
#define SIZE 1408

volatile uint32_t a[SIZE] = {0};
volatile uint32_t b[SIZE] = {0};

int main(void) {
    uint32_t i;
    volatile uint32_t sum_in = 0;
    volatile uint32_t sum_out = 0;

    for (i=0; i<SIZE; i++) {
        a[i] = i;
        sum_in += i;
    }

    memcpy((void *)b, (void *)a, SIZE*sizeof(uint32_t));

    for (i=0; i<SIZE; i++) {
        sum_out += b[i];
    }
    if (sum_in == sum_out) {
        return 1;
    }
    else {
        return 0;
    }
}

