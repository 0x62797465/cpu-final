To build you must build with `riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -nostartfiles -ffreestanding -Wl,-T,linker.ld startup.s program.c -o test.elf -O3` and make it raw with ` riscv32-none-elf-objcopy -O binary test.elf program.bin`.

To configure UART please run `stty -F /dev/ttyUSB0 115200 cs8 -cstopb -parenb raw -echo -ixon -ixoff -crtscts -opost`.

You can move over the program with `(printf '\x1c\x1d\x1e\x1f' ; cat program.bin) > /dev/ttyUSB0` where the `printf` statement prints the header (in this case the size is 0x1f1e1d1x).

To do I/O run `picocom --baud 115200 --databits 8 --parity n --stopbits 1 -q --flow n /dev/ttyUSB0`. 
