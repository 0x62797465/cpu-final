.text
.globl _start
_start:
    addi x2, x0, 43
    addi x1, x0, 67
    sb   x1, 0(x2)
    lb   x15, 0(x2)
    addi x31, x0, 0xef
loop:
    jal loop
