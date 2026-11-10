# op1, op2, op3 and q_mul: hand-written RV32I.
#
# uint32_t op1_asm(uint32_t a, uint32_t b, int *n)   a0, a1, a2 -> a0
# uint32_t op2_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# uint32_t op3_asm(uint32_t a, uint32_t b)           a0, a1 -> a0
# int32_t  q_mul_asm(int32_t a, int32_t b)           a0, a1 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. q_mul forms a 64-bit product in a register pair. Tests:
# tests/tfixed.c.

    .text

    .globl  op1_asm
    .type   op1_asm, @function
    .align  2
op1_asm:
    li      t1, 0            
    beqz    a1, 2f                
1:  and     t0, a0, a1             
    xor     a0, a0, a1             
    slli    a1, t0, 1              
    addi    t1, t1, 1              
    bnez    a1, 1b                
2:  sw      t1, 0(a2)            
    ret
    .size   op1_asm, .-op1_asm

    .globl  op2_asm
    .type   op2_asm, @function
    .align  2
op2_asm:
    sub     a0, a0, a1
    ret
    .size   op2_asm, .-op2_asm

    .globl  op3_asm
    .type   op3_asm, @function
    .align  2
op3_asm:
    and     t0, a0, a1             
    xor     a0, a0, a1             
    srli    a0, a0, 1              
    add     a0, a0, t0
    ret
    .size   op3_asm, .-op3_asm

    .globl  q_mul_asm
    .type   q_mul_asm, @function
    .align  2
q_mul_asm:
    li      a4, 0                  # lo
    li      a5, 0                  # hi
    mv      a2, a0                 # multiplier, lo
    li      a3, 0                  # multiplier，high
    mv      a6, a1                 # multiplicand
    beqz    a6, 3f
1:  andi    t0, a6, 1              
    beqz    t0, 2f                 
    add     a4, a4, a2             
    sltu    t1, a4, a2            
    add     a5, a5, a3
    add     a5, a5, t1
2:  srli    t1, a2, 31              
    slli    a3, a3, 1
    or      a3, a3, t1
    slli    a2, a2, 1
    srli    a6, a6, 1              
    bnez    a6, 1b


3:  srai    t0, a0, 31             
    and     t0, t0, a1             
    sub     a5, a5, t0
    srai    t0, a1, 31             
    and     t0, t0, a0             
    sub     a5, a5, t0


    lui     t0, 0x80               # t0 = 2^19
    add     t1, a4, t0             # lo2 = lo + 2^19
    sltu    t0, t1, a4            
    add     a5, a5, t0
    srli    t1, t1, 20             # lo2 >> 20
    slli    a5, a5, 12             # hi << 12
    or      a0, a5, t1
    ret
    .size   q_mul_asm, .-q_mul_asm
