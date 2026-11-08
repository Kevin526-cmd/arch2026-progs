# BFloat16 routines: hand-written RV32I.
#
# uint16_t bf16_from_f32_asm(uint32_t f32bits)   a0 -> a0
# uint16_t bf16_mul_asm(uint16_t a, uint16_t b)  a0, a1 -> a0
# uint16_t bf16_sqrt_asm(uint16_t a)             a0 -> a0
#
# RV32I and Zicsr only: no mul, div, rem, no floating point, no compressed
# instructions. Tests: tests/tbf16.c.

    .text

    .globl  bf16_from_f32_asm
    .type   bf16_from_f32_asm, @function
    .align  2
bf16_from_f32_asm:
    lui     a2, 0x7F800          
    and     a1, a0, a2             
    beq     a1, a2, 1f        
    srli    a1, a0, 16       
    andi    a1, a1, 1        
    add     a0, a0, a1           
    lui     a2, 0x8              
    addi    a2, a2, -1        
    add     a0, a0, a2             
1:  srli    a0, a0, 16 
    ret
    .size   bf16_from_f32_asm, .-bf16_from_f32_asm

    .globl  bf16_mul_asm
    .type   bf16_mul_asm, @function
    .align  2

bf16_mul_asm:
    xor     a7, a0, a1
    srli    a7, a7, 15
    slli    a7, a7, 15

    # exp / mantissa
    srli    a2, a0, 7
    andi    a2, a2, 0xFF       
    srli    a3, a1, 7
    andi    a3, a3, 0xFF        
    andi    a4, a0, 0x7F          
    andi    a5, a1, 0x7F           

    # special case Inf / NaN
    li      t0, 0xFF
    beq     a2, t0, m_a_special
    beq     a3, t0, m_b_special

    slli    t1, a0, 17
    beqz    t1, m_zero
    slli    t1, a1, 17
    beqz    t1, m_zero
    li      a6, 0                 
    beqz    a2, m_a_denorm
    ori     a4, a4, 0x80
m_a_done:
    beqz    a3, m_b_denorm
    ori     a5, a5, 0x80
m_b_done:
    li      t2, 0

m_loop:
    andi    t1, a5, 1            
    beqz    t1, 1f                 
    add     t2, t2, a4    
            
1:  slli    a4, a4, 1              
    srli    a5, a5, 1              
    bnez    a5, m_loop   
    
    # exp add          
    add     a2, a2, a3
    add     a2, a2, a6
    addi    a2, a2, -127          
    
    # normalization
    srli    t1, t2, 15             
    beqz    t1, 2f
    srli    t2, t2, 8              
    addi    a2, a2, 1
    j       3f
2:  srli    t2, t2, 7    
3:  andi    t2, t2, 0x7F

    # overflow/underflow
    bge     a2, t0, m_inf         
    blez    a2, m_under            

    slli    a2, a2, 7
    or      a0, a7, a2
    or      a0, a0, t2
    ret

m_under:
    li      t1, -6
    blt     a2, t1, m_zero        
    li      t1, 1
    sub     t1, t1, a2            
    srl     t2, t2, t1
    or      a0, a7, t2            
    ret
m_zero:
    mv      a0, a7                 
    ret
m_inf:
    li      t0, 0x7F80
    or      a0, a7, t0             
    ret
m_nan:
    li      a0, 0x7FC0
    ret

m_a_special:
    bnez    a4, m_ret             
    slli    t1, a1, 17
    beqz    t1, m_nan              
    j       m_inf
m_b_special:
    bnez    a5, m_ret_b            
    slli    t1, a0, 17
    beqz    t1, m_nan              
    j       m_inf
m_ret_b:
    mv      a0, a1
m_ret:
    ret

m_a_denorm:                       
    andi    t1, a4, 0x80
    bnez    t1, 4f
    slli    a4, a4, 1
    addi    a6, a6, -1
    j       m_a_denorm
4:  li      a2, 1                  
    j       m_a_done
m_b_denorm:
    andi    t1, a5, 0x80
    bnez    t1, 5f
    slli    a5, a5, 1
    addi    a6, a6, -1
    j       m_b_denorm
5:  li      a3, 1
    j       m_b_done
    .size   bf16_mul_asm, .-bf16_mul_asm



    .globl  bf16_sqrt_asm
    .type   bf16_sqrt_asm, @function
    .align  2

bf16_sqrt_asm:
    srli    a1, a0, 7
    andi    a1, a1, 0xFF           # exp
    andi    a2, a0, 0x7F           # mant

    # 特殊情況
    li      t0, 0xFF
    beq     a1, t0, s_special      # Inf / NaN
    slli    t1, a0, 17
    beqz    t1, s_zero             # +0 或 -0
    srli    t1, a0, 15
    bnez    t1, s_nan              
    beqz    a1, s_zero            

    # exp / 2
    addi    a1, a1, -127        # e = exp - 127
    ori     a2, a2, 0x80           
    andi    t1, a1, 1
    beqz    t1, 1f                 # e is even jump
    slli    a2, a2, 1              # e is odd , e * 2 
    addi    a1, a1, -1             
1:  srai    a1, a1, 1        # e / 2
    addi    a1, a1, 127            # new_exp

    # N = 128 * m + 127 ( check N < (r+bit)² ) 
    slli    a2, a2, 7
    ori     a2, a2, 127

    # decide the square root by bit by bit
    li      a3, 128                # r
    lui     a4, 0x4                # r² 
    li      a5, 64                 # bit
    li      a6, 7                  # k + 1
    li      a7, 4096               # bit²
s_loop:
    sll     t1, a3, a6             # 2·r·bit
    add     t1, t1, a4             #  r²
    add     t1, t1, a7             #  bit² 
    bltu    a2, t1, 2f             # N < (r+bit)²
    or      a3, a3, a5             # stay bit
    mv      a4, t1                 # update r²
2:  srli    a5, a5, 1             
    addi    a6, a6, -1
    srli    a7, a7, 2       
    bnez    a5, s_loop             

    andi    a3, a3, 0x7F
    slli    a1, a1, 7
    or      a0, a1, a3
    ret

s_special:
    bnez    a2, 3f                 
    srli    t1, a0, 15
    bnez    t1, s_nan              
3:  ret                            
s_zero:
    li      a0, 0
    ret
s_nan:
    li      a0, 0x7FC0
    ret
    .size   bf16_sqrt_asm, .-bf16_sqrt_asm
