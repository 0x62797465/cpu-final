.globl _start
_start:
    addi x2, x0, 43
    addi x1, x0, -67
    mul x15, x1, x2
    mulh x3, x1, x2
    mulhsu x4, x1, x2
    mulhu x5, x1, x2
    xor x15, x15, x3
    xor x15, x15, x4
    xor x15, x15, x5
    addi x31, x0, 0xef

loop:
    jal loop
