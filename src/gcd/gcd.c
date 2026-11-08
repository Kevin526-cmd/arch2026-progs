#include "gcd.h"

/* Dummy: returns 0 for every input. Replace with the binary GCD. */
uint32_t gcd_u32(uint32_t a, uint32_t b)
{
    (void) a;
    (void) b;
    // one is zero
    if (!a)
        return b;
    if (!b)
        return a;

    /* both are even so remeber how many two */
    int shift = 0;
    while (!((a | b) & 1)) {
        a >>= 1;
        b >>= 1;
        shift++;
    }

    /*a is odd*/
    while (!(a & 1))
        a >>= 1;

    do {
        /* b is odd */
        while (!(b & 1))
            b >>= 1;
        /*  b >= a */
        if (a > b) {
            uint32_t t = a;
            a = b;
            b = t;
        }
        /*  b >= a */
        b -= a;
    } while (b != 0);

    /* 2 mul back */
    return a << shift;
}
