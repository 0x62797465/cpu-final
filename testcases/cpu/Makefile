all: div_test mul_test stack_test fib_test gcc_basic recursion_gcc clean

div_test:
	riscv32-none-elf-as -march=rv32im div.s -o test.o
	riscv32-none-elf-ld -Ttext=0x0 test.o -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf div.bin


stack_test:
	riscv32-none-elf-as -march=rv32i stack.s -o test.o
	riscv32-none-elf-ld -Ttext=0x0 test.o -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf stack.bin

fib_test:
	riscv32-none-elf-as -march=rv32i fib.s -o test.o
	riscv32-none-elf-ld -Ttext=0x0 test.o -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf fib.bin

mul_test:
	riscv32-none-elf-as -march=rv32im mul.s -o test.o
	riscv32-none-elf-ld -Ttext=0x0 test.o -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf mul.bin


gcc_basic:
	riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -nostartfiles -ffreestanding -Wl,-T,linker.ld startup.s test_gcc_basic.c -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf test_gcc_basic.bin	

recursion_gcc:
	riscv32-none-elf-gcc -march=rv32i -mabi=ilp32 -mstrict-align -nostdlib -nostartfiles -ffreestanding -Wl,-T,linker.ld startup.s recursion_gcc.c -o test.elf
	riscv32-none-elf-objcopy -O binary test.elf recursion.bin	

clean:
	rm test.o test.elf
