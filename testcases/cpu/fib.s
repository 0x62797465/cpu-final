.text
.globl _start
_start:
    addi t0, zero, 20 // fib for 20
    addi t1, zero, 0
    addi t2, zero, 1
    addi t3, t0, -1
fib_loop:
    beq  t3, zero, done
    add  t4, t1, t2
    addi t5, t2, 0
    addi t2, t4, 0
    addi t1, t5, 0
    addi t3, t3, -1
    beq  zero, zero, fib_loop
done:
    addi t6, t2, 0
halt:
    beq  zero, zero, halt
