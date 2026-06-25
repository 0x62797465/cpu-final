# :star emoji: Features/Details :star emoji:
- Works on an FPGA at 50MHz
- The ISA is just RV32IM, with only usermode instructions supported. 
- For compilation instructions, refer to testcases/cpu/README.md (or look at the makefile)
- support for MMIO (just UART) is included
- Loader is embedded in the hardware (mainly AGU, connected to fetch), 32 bit size header needs to be transmitted then the rest of the raw program via UART
- Dual fetch, tri-issue (2 ALU 1 AGU), can retire up to 6 instructions at a time
- Speculative execution works with the architectural register state being copied over to the RAT during a pipeline flush
- Full out-of-order execution works
- A small BHT exists in the decode stage, fed by the retire stage
- The decode stage also houses a unit that computes immediate jumps so that there is not a huge cycle penalty from the would-be misprediction penalty
- The AGU contains a store queue for speculative memory writes/reads and UART logic
- Roughly ~1.6 IPC

# Misc details
- Targets Cyclone V GX Starter Kit
- 115200 baud rate
- `0x10000000` holds UART_TX, `0x10000004` UART_RX, `0x10000008` UART status
- 16kb instruction memory, 32kb data memory

# Status
The first prototype is finished and can run many programs on an FPGA, although more changes are likely to be made. The 32-bit RISCV userspace ISA (RV32IM) is implemented. 

# TODO
- Finish writeups (see https://brew.is-not-a.dev/)
- Many testbenches are stale and need to be extended
- Clean up the code base, there are unused variables, code with stale comments, code with no comments, etc
- Create special cases for NOP instructions
- Handle register moves more gracefully
- Prevent extra cycle delay from AGU
- Extend to use other memory (like external SRAM and DDR)
- Improve timing, the small amount of stages leads to bad timing
