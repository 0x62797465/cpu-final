_start:
    lui sp, 0x4
    addi sp, sp, -8
    la ra, hang
    sw   ra, 0(sp)
    j main

hang:
    addi x31, x0, 0xef
    j hang
