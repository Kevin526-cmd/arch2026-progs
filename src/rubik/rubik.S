    .data
weight: .half 720, 120, 24, 6, 2, 1, 0
p_arr:  .byte 0, 0, 0, 0, 0, 0, 0, 7
o_arr:  .zero 8              
    .align 1                 
stP:       .zero 32
stO:       .zero 32
stA:       .zero 16
stB:       .zero 16
cur_face:  .zero 16
cur_turn:  .zero 16
path_face: .zero 16
path_turn: .zero 16  

    .align 2
rows:
    .word   permutation, orientation, cubie_move
    .word   permutation + 10080, orientation + 1458, cubie_move + 28
    .word   permutation + 20160, orientation + 2916, cubie_move + 56

face_ch:    .string "RBD"
    .text
    .globl  rubik_solve_asm
    .type   rubik_solve_asm, @function
    .align  2

rubik_solve_asm:
    addi    sp, sp, -64
    sw      ra, 0(sp)
    sw      s0, 4(sp)
    sw      s1, 8(sp)
    sw      s2, 12(sp)
    sw      s3, 16(sp)
    sw      s4, 20(sp)
    sw      s5, 24(sp)
    sw      s6, 28(sp)
    sw      s7, 32(sp)
    sw      s8, 36(sp)
    sw      s9, 40(sp)
    sw      s10, 44(sp)
    sw      s11, 48(sp)
    sw      a1, 52(sp)      
    sw      a2, 56(sp)      
    mv   t0, a0             
    addi t1, a0, 14
len_loop:
    lbu  t2, 0(t0)
    beqz t2, bad_state
    addi t0, t0, 1
    bne  t0, t1, len_loop
    lbu  t2, 0(t0)
    bnez t2, bad_state
    mv   t0, a0            
    la   t1, p_arr             
    la   t2, o_arr              
    li   t3, 0                  
    li   t4, 7
    li   a4, 0               
    li   a5, 0               

loop1:
    lbu  t5, 0(t0)              
    addi t5, t5, -49            
    sb   t5, 0(t1)              
    lbu  t6, 7(t0)              
    addi t6, t6, -49
    sb   t6, 0(t2)              
    li   a3, 6
    bgtu t5, a3, bad_state   
    li   a3, 2
    bgtu t6, a3, bad_state   
    li   a3, 1
    sll  a3, a3, t5
    and  a2, a4, a3
    bnez a2, bad_state       
    or   a4, a4, a3
    add  a5, a5, t6          
    slli a1, t3, 2
    add  a1, a1, t6
    bnez t5, skip_a
    mv   s2, a1

skip_a:
    li   a2, 1       
    bne  t5, a2, skip_b
    mv   s3, a1
skip_b:

    addi t0, t0, 1             
    addi t1, t1, 1
    addi t2, t2, 1
    addi t3, t3, 1              
    blt  t3, t4, loop1 
    li   a3, 3         
mod3:
    bltu a5, a3, mod3_done
    sub  a5, a5, a3
    j    mod3
mod3_done:
    bnez a5, bad_state         
    li   s1, 0                 
    la   t2, o_arr             
    li   t3, 0                 
    li   t4, 6      

loop2:
    lbu  t6, 0(t2)             
    slli a1, s1, 1             
    add  a1, a1, s1            
    add  s1, a1, t6             
    addi t2, t2, 1
    addi t3, t3, 1
    blt  t3, t4, loop2

    li   s0, 0
    la   t1, p_arr
    la   t2, weight
    li   t3, 0
    li   t4, 7
loop_i:
    add  a1, t1, t3
    lbu  t5, 0(a1)
    slli a2, t3, 1
    add  a2, a2, t2
    lhu  a3, 0(a2)
    addi a4, t3, 1
loop_j:
    bge  a4, t4, next_i
    add  a5, t1, a4
    lbu  t6, 0(a5)
    bgeu t6, t5, skip_add
    add  s0, s0, a3
skip_add:
    addi a4, a4, 1
    j    loop_j
next_i:
    addi t3, t3, 1
    blt  t3, t4, loop_i

    la   s10, dist_po
    la   s11, dist_o
    la   s9, stP
    la   a6, rows           
    mv   a0, s0
    mv   a1, s1
    mv   a2, s2
    mv   a3, s3
    jal  ra, solve
    mv   s8, a0              
    lw   a1, 52(sp)          
    lw   a2, 56(sp)          
    li   t0, 1               
    li   t1, 0               
need_loop:
    bge  t1, s8, need_done
    add  t2, s9, t1
    lbu  t3, 144(t2)         
    addi t0, t0, 1           
    beqz t3, need_no_suffix
    addi t0, t0, 1           
need_no_suffix:
    beqz t1, need_no_space
    addi t0, t0, 1           
need_no_space:
    addi t1, t1, 1
    j    need_loop
need_done:
    bleu t0, a2, write_out
    beqz a2, too_small
    sb   zero, 0(a1)
too_small:
    li   a0, -2
    j    done

write_out:
    la   t4, face_ch
    li   t1, 0
write_loop:
    bge  t1, s8, write_end
    beqz t1, write_face
    li   t5, 32              
    sb   t5, 0(a1)
    addi a1, a1, 1
write_face:
    add  t2, s9, t1
    lbu  t3, 128(t2)         
    add  t3, t4, t3
    lbu  t5, 0(t3)
    sb   t5, 0(a1)
    addi a1, a1, 1
    lbu  t3, 144(t2)         
    beqz t3, write_next
    li   t5, 50              
    li   t6, 1
    beq  t3, t6, write_suffix
    li   t5, 39              
write_suffix:
    sb   t5, 0(a1)
    addi a1, a1, 1
write_next:
    addi t1, t1, 1
    j    write_loop
write_end:
    sb   zero, 0(a1)
    mv   a0, s8
    j    done

bad_state:
    li   a0, -1

done:
    lw      ra, 0(sp)
    lw      s0, 4(sp)
    lw      s1, 8(sp)
    lw      s2, 12(sp)
    lw      s3, 16(sp)
    lw      s4, 20(sp)
    lw      s5, 24(sp)
    lw      s6, 28(sp)
    lw      s7, 32(sp)
    lw      s8, 36(sp)
    lw      s9, 40(sp)
    lw      s10, 44(sp)
    lw      s11, 48(sp)
    addi    sp, sp, 64
    ret
    .size   rubik_solve_asm, .-rubik_solve_asm
    
heur:
    andi t0, a2, 3            
    andi t1, a3, 3           
    slli t2, a0, 3              
    add  t2, t2, a0             
    slli t3, t0, 1              
    add  t3, t3, t0            
    add  t2, t2, t3
    add  t2, t2, t1
    add  t2, t2, s10           
    lbu  t2, 0(t2)           
    add  t3, s11, a1           
    lbu  t3, 0(t3)             
    mv   a0, t2
    bgeu  t2, t3, heur_done
    mv a0, t3      

heur_done:
    ret    


search_iter:
    addi sp, sp, -4
    sw   ra, 0(sp)          

    li   s4, 0              
    li   s6, 99             

    sh   a0, 0(s9)              
    sh   a1, 32(s9)              
    sb   a2, 64(s9)             
    sb   a3, 80(s9)              
    sb   x0, 96(s9)             
    sb   x0, 112(s9)             
    bnez a0, si_loop        
    bnez a1, si_loop        
    li   a0, 0              
    j    si_ret

si_loop:
    li   a0, -1
    bltz s4, si_ret              
    add  a4, s9, s4
    slli a5, s4, 1
    add  a5, s9, a5
    lbu  s7, 96(a4)

    li   t0, 3
    bne  s7, t0, face_ok
    addi s4, s4, -1
    j    si_loop

face_ok:
    lbu  s8, 112(a4)             
    bnez s8, not_same
    blez s4, not_same
    lbu  t0, 127(a4)             
    bne  s7, t0, not_same
    addi t0, s7, 1
    sb   t0, 96(a4)             
    j    si_loop

not_same:
    li   t0, 2
    bne  s8, t0, turn_inc
    addi t0, s7, 1
    sb   t0, 96(a4)              
    sb   x0, 112(a4)            
    j    adv_done
turn_inc:
    addi t0, s8, 1
    sb   t0, 112(a4)            

adv_done:
    mv   t5, a4
    mv   t2, a5
    beqz s8, src_ok
    addi t5, a4, 1
    addi t2, a5, 2

src_ok:
    slli t6, s7, 2           
    slli t0, s7, 3          
    add  t6, t6, t0          
    add  t6, t6, a6          
    lw   t0, 0(t6)           
    lw   t1, 4(t6)          
    lw   t4, 8(t6)           

    lhu  t3, 0(t2)           
    lhu  a1, 32(t2)
    lbu  a2, 64(t5)
    lbu  a3, 80(t5)
    slli t3, t3, 1           
    slli a1, a1, 1
    add  t3, t0, t3
    add  a1, t1, a1
    add  a2, t4, a2
    add  a3, t4, a3
    lhu  a0, 0(t3)           
    lhu  a1, 0(a1)
    lbu  a2, 0(a2)
    lbu  a3, 0(a3)
    sh   a0, 2(a5)          
    sh   a1, 34(a5)
    sb   a2, 65(a4)
    sb   a3, 81(a4)

    andi t0, a2, 3           
    andi t1, a3, 3           
    slli t2, a0, 3
    add  t2, t2, a0          
    slli t3, t0, 1
    add  t3, t3, t0          
    add  t2, t2, t3
    add  t2, t2, t1
    add  t2, t2, s10
    add  t3, s11, a1        
    lbu  t2, 0(t2)
    lbu  a0, 0(t3)
    addi t6, s4, 1           
    bgeu a0, t2, h_ok
    mv   a0, t2

h_ok:
    add  t0, a0, t6              
    ble  t0, s5, no_prune        
    bge  t0, s6, si_loop         
    mv   s6, t0                  
    j    si_loop

no_prune:
    sb   s7, 128(a4)             
    sb   s8, 144(a4)             

    bnez a0, go_deeper
    addi a0, s4, 1
    j    si_ret

go_deeper:
    addi s4, s4, 1
    sb   x0, 97(a4)              
    sb   x0, 113(a4)             
    j    si_loop

si_ret:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret

solve:
    addi sp, sp, -4
    sw   ra, 0(sp)
    mv   a0, s0
    mv   a1, s1
    mv   a2, s2
    mv   a3, s3
    jal  ra, heur
    mv   s5, a0
    
solve_loop:
    mv   a0, s0
    mv   a1, s1
    mv   a2, s2
    mv   a3, s3
    jal  ra, search_iter
    bgez a0, solve_done
    mv   s5, s6
    j    solve_loop

solve_done:
    lw   ra, 0(sp)
    addi sp, sp, 4
    ret
