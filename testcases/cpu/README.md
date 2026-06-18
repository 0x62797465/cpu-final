To run program on the CPU, you must assemble as follows:
riscv32-none-elf-as -march=rv32i test.s -o test.o
riscv32-none-elf-ld -Ttext=0x0 test.o -o test.elf
riscv32-none-elf-objcopy -O binary test.elf test.bin

Format is as follows:
tests.txt lists the test name (e.g fib.bin) and the expected x31 value at the end of X cycles