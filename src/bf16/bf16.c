#include "bf16.h"

/* Dummies: every function returns 0. Replace with the real routines. */
uint16_t bf16_from_f32(uint32_t f32bits)
{
    (void) f32bits;
    if (((f32bits >> 23) & 0xFF) == 0xFF) {
        return (uint16_t) (f32bits >> 16);
    }
    f32bits += ((f32bits >> 16) & 1) + 0x7FFF;
    return (uint16_t) (f32bits >> 16);
}

uint16_t bf16_mul(uint16_t a, uint16_t b)
{
    (void) a;
    (void) b;
    uint16_t sign_a = (a >> 15) & 1, sign_b = (b >> 15) & 1;
    int16_t exp_a = (a >> 7) & 0xFF, exp_b = (b >> 7) & 0xFF;
    uint16_t mant_a = a & 0x7F, mant_b = b & 0x7F;
    uint16_t result_sign = sign_a ^ sign_b;

    if (exp_a == 0xFF) {
        if (mant_a)
            return a;
        if (!exp_b && !mant_b)
            return 0x7FC0;
        return (uint16_t) ((result_sign << 15) | 0x7F80);
    }
    if (exp_b == 0xFF) {
        if (mant_b)
            return b;
        if (!exp_a && !mant_a)
            return 0x7FC0;
        return (uint16_t) ((result_sign << 15) | 0x7F80);
    }
    if ((!exp_a && !mant_a) || (!exp_b && !mant_b))
        return (uint16_t) (result_sign << 15);

    int16_t exp_adjust = 0;
    if (!exp_a) {
        while (!(mant_a & 0x80)) {
            mant_a <<= 1;
            exp_adjust--;
        }
        exp_a = 1;
    } else {
        mant_a |= 0x80;
    }
    if (!exp_b) {
        while (!(mant_b & 0x80)) {
            mant_b <<= 1;
            exp_adjust--;
        }
        exp_b = 1;
    } else {
        mant_b |= 0x80;
    }

    uint32_t result_mant = (uint32_t) mant_a * mant_b;
    int32_t result_exp = (int32_t) exp_a + exp_b - 127 + exp_adjust;

    if (result_mant & 0x8000) {
        result_mant = (result_mant >> 8) & 0x7F;
        result_exp++;
    } else {
        result_mant = (result_mant >> 7) & 0x7F;
    }

    if (result_exp >= 0xFF)
        return (uint16_t) ((result_sign << 15) | 0x7F80);
    if (result_exp <= 0) {
        if (result_exp < -6)
            return (uint16_t) (result_sign << 15);
        result_mant >>= (1 - result_exp);
        result_exp = 0;
    }

    return (uint16_t) ((result_sign << 15) | ((result_exp & 0xFF) << 7) |
                       (result_mant & 0x7F));
}

uint16_t bf16_sqrt(uint16_t a)
{
    (void) a;
    uint16_t sign = (a >> 15) & 1;
    int16_t exp = (a >> 7) & 0xFF;
    uint16_t mant = a & 0x7F;

    if (exp == 0xFF) {
        if (mant)
            return a;
        if (sign)
            return 0x7FC0;
        return a;
    }
    if (!exp && !mant)
        return 0x0000;
    if (sign)
        return 0x7FC0;

    if (!exp)
        return 0;

    int32_t e = exp - 127;
    int32_t new_exp;
    uint32_t m = 0x80 | mant;

    if (e & 0x0001) {
        m <<= 1;
        new_exp = ((e - 1) >> 1) + 127;
    } else {
        new_exp = (e >> 1) + 127;
    }

    uint32_t low = 90, high = 256, result = 128;
    while (low <= high) {
        uint32_t mid = (low + high) >> 1;
        uint32_t sq = (mid * mid) / 128;
        if (sq <= m) {
            result = mid;
            low = mid + 1;
        } else {
            high = mid - 1;
        }
    }

    if (result >= 256) {
        result >>= 1;
        new_exp++;
    } else if (result < 128) {
        while (result < 128 && new_exp > 1) {
            result <<= 1;
            new_exp--;
        }
    }

    if (new_exp >= 0xFF)
        return 0x7F80;
    if (new_exp <= 0)
        return 0;
    return (uint16_t) (((new_exp & 0xFF) << 7) | (result & 0x7F));
}
