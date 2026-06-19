# Status
This is unfinished, and can only run extremely basic programs. The base 32-bit risc-v userspace ISA is implemented, with plans for UART in the future. It is not known (but rather unlikely) that this works on an FPGA, after the UART is added I will begin trying to make it work on an FPGA.

# :star emoji: Features/Details :star emoji:
- The ISA is just base RISCV-32, with only usermode instructions supported. 
- For compilation instructions, refer to testcases/cpu/README.md (or look at the makefile). 
- Future (like possibly tomorrow) support for MMIO (just UART) will be included.
- Loader is embedded in the hardware (mainly agu, connected to fetch), 32 bit size header needs to be transmitted then the rest of the raw program via UART
- Dual fetch, tri-issue (2 ALU 1 AGU), dual retire (can be easily extended)
- Speculative execution works with the architectural register state being copied over to the RAT during a pipeline flush
- out of order execution and renaming and stuff
- A small BTB exists in the decode stage, fed by the retire stage (thrashing possible)
- The decode stage also houses a unit that computes immediate jumps so that there is not a huge cycle penalty from the would-be missprediction penalty
- The AGU contains a load queue for speculative memory writes/reads and UART logic
