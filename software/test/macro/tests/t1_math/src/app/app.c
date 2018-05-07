/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   C99, 4 soft tab, wide column.
 *
 * Description:
 *   Compute e^(pi*i) = -1
 */
#include <math.h>
#include <complex.h>
#include <stdint.h>

uint64_t expected = 0xbff0000000000000ULL;

int main(void)
{
    volatile double complex i = I;
    volatile double complex pi = M_PI;
    volatile double complex product;
    volatile double product_real;
    volatile uint64_t *hex_ptr;
    volatile uint64_t hex;

    product = cexp(pi * i);
    product_real = creal(product);
    hex_ptr = (uint64_t *) &product_real;
    hex = *hex_ptr;

    /* Return 1 if the computation succeeded */
    if (hex == expected) {
        return 1;
    }
    else {
        return 0;
    }
}

