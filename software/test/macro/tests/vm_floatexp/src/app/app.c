/*
 * File         : app.c
 * Project      : MIPS32r1
 * Creator(s)   : Grant Ayers (ayers@cs.stanford.edu)
 *
 * Standards/Formatting:
 *   GNU99, 4 soft tab, wide column.
 *
 * Description:
 *   Compute a single exponentiation e^pi
 */
#include <math.h>

int main(void)
{
    volatile double pi = M_PI;
    volatile double res;

    res = exp(pi);

    if ((res - 23.140692633) < 0.00001) {
        return 1;
    }
    else {
        return 0;
    }
}

