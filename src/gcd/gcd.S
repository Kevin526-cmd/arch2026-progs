# gcd_u32_asm: binary GCD, hand-written RV32I.
#
# uint32_t gcd_u32_asm(uint32_t a, uint32_t b)   a in a0, b in a1, result in a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tgcd.c.

    .text

    .globl  gcd_u32_asm
    .type   gcd_u32_asm, @function
    .align  2
gcd_u32_asm:
    beqz    a0, g_ret_b            # gcd(0, b) = b
    beqz    a1, g_ret              # gcd(a, 0) = a
    li      a2, 0                  # shift = 0
    or      t0, a0, a1
    andi    t0, t0, 1
    bnez    t0, g_a_check          
g_common:                          # all is even
    srli    a0, a0, 1
    srli    a1, a1, 1
    addi    a2, a2, 1
    or      t0, a0, a1
    andi    t0, t0, 1
    beqz t0, g_common              # still even, continue 
    j       g_a_check
g_a_shift:                         # a is odd
    srli    a0, a0, 1
g_a_check:
    andi    t0, a0, 1
    beqz    t0, g_a_shift
    j       g_b_check
g_b_shift:                         # b is odd
    srli    a1, a1, 1
g_b_check:
    andi    t0, a1, 1
    beqz    t0, g_b_shift
    bltu    a1, a0, g_swap         # b < a：change
    sub     a1, a1, a0             # b = b - a
    bnez    a1, g_b_shift          
    sll     a0, a0, a2             # how many two then mul it
g_ret:
    ret
g_swap:                            # b = a - b
    sub     t0, a0, a1
    mv      a0, a1
    mv      a1, t0
    j       g_b_shift
g_ret_b:
    mv      a0, a1
    ret
    .size   gcd_u32_asm, .-gcd_u32_asm
