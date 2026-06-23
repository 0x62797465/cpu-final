.globl _start
_start:
    addi x2, x0, 100
    addi x1, x0, -7

    div x3, x2, x1
    divu x4, x2, x1
    rem x5, x2, x1
    remu x6, x2, x1

    xor x15, x3, x4
    xor x15, x15, x5
    xor x15, x15, x6

    addi x31, x0, 0xef

loop:
    jal loop
