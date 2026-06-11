//`define ENABLE_DDR2LP
//`define ENABLE_HSMC_XCVR
//`define ENABLE_SMA
//`define ENABLE_REFCLK
//`define ENABLE_GPIO
`include "types.svh"

module cpu(

      ///////// ADC ///////// 1.2 V ///////
      output             ADC_CONVST,
      output             ADC_SCK,
      output             ADC_SDI,
      input              ADC_SDO,

      ///////// AUD ///////// 2.5 V ///////
      input              AUD_ADCDAT,
      inout              AUD_ADCLRCK,
      inout              AUD_BCLK,
      output             AUD_DACDAT,
      inout              AUD_DACLRCK,
      output             AUD_XCK,

      ///////// CLOCK /////////
      input              CLOCK_125_p, ///LVDS
      input              CLOCK_50_B5B, ///3.3-V LVTTL
      input              CLOCK_50_B6A,
      input              CLOCK_50_B7A, ///2.5 V
      input              CLOCK_50_B8A,

      ///////// CPU /////////
      input              CPU_RESET_n, ///3.3V LVTTL

`ifdef ENABLE_DDR2LP
      ///////// DDR2LP ///////// 1.2-V HSUL ///////
      output      [9:0]  DDR2LP_CA,
      output      [1:0]  DDR2LP_CKE,
      output             DDR2LP_CK_n, ///DIFFERENTIAL 1.2-V HSUL
      output             DDR2LP_CK_p, ///DIFFERENTIAL 1.2-V HSUL
      output      [1:0]  DDR2LP_CS_n,
      output      [3:0]  DDR2LP_DM,
      inout       [31:0] DDR2LP_DQ,
      inout       [3:0]  DDR2LP_DQS_n, ///DIFFERENTIAL 1.2-V HSUL
      inout       [3:0]  DDR2LP_DQS_p, ///DIFFERENTIAL 1.2-V HSUL
      input              DDR2LP_OCT_RZQ, ///1.2 V
`endif /*ENABLE_DDR2LP*/

`ifdef ENABLE_GPIO
      ///////// GPIO ///////// 3.3-V LVTTL ///////
      inout       [35:0] GPIO,
`else
      ///////// HEX2 ///////// 1.2 V ///////
      output      [6:0]  HEX2,

      ///////// HEX3 ///////// 1.2 V ///////
      output      [6:0]  HEX3,


`endif /*ENABLE_GPIO*/

      ///////// HDMI /////////
      output             HDMI_TX_CLK,
      output      [23:0] HDMI_TX_D,
      output             HDMI_TX_DE,
      output             HDMI_TX_HS,
      input              HDMI_TX_INT,
      output             HDMI_TX_VS,

      ///////// HEX0 /////////
      output      [6:0]  HEX0,

      ///////// HEX1 /////////
      output      [6:0]  HEX1,


      ///////// HSMC ///////// 2.5 V ///////
      input              HSMC_CLKIN0,
      input       [2:1]  HSMC_CLKIN_n,
      input       [2:1]  HSMC_CLKIN_p,
      output             HSMC_CLKOUT0,
      output      [2:1]  HSMC_CLKOUT_n,
      output      [2:1]  HSMC_CLKOUT_p,
      inout       [3:0]  HSMC_D,
`ifdef ENABLE_HSMC_XCVR
      input       [3:0]  HSMC_GXB_RX_p, /// 1.5-V PCML
      output      [3:0]  HSMC_GXB_TX_p, /// 1.5-V PCML
`endif /*ENABLE_HSMC_XCVR*/
      inout       [16:0] HSMC_RX_n,
      inout       [16:0] HSMC_RX_p,
      inout       [16:0] HSMC_TX_n,
      inout       [16:0] HSMC_TX_p,


      ///////// I2C ///////// 2.5 V ///////
      output             I2C_SCL,
      inout              I2C_SDA,

      ///////// KEY ///////// 1.2 V ///////
      input       [3:0]  KEY,

      ///////// LEDG ///////// 2.5 V ///////
      output      [7:0]  LEDG,

      ///////// LEDR ///////// 2.5 V ///////
      output      [9:0]  LEDR,

`ifdef ENABLE_REFCLK
      ///////// REFCLK ///////// 1.5-V PCML ///////
      input              REFCLK_p0,
      input              REFCLK_p1,
`endif /*ENABLE_REFCLK*/

      ///////// SD ///////// 3.3-V LVTTL ///////
      output             SD_CLK,
      inout              SD_CMD,
      inout       [3:0]  SD_DAT,

`ifdef ENABLE_SMA
      ///////// SMA ///////// 1.5-V PCML ///////
      input              SMA_GXB_RX_p,
      output             SMA_GXB_TX_p,
`endif /*ENABLE_SMA*/

      ///////// SRAM ///////// 3.3-V LVTTL ///////
      output      [17:0] SRAM_A,
      output             SRAM_CE_n,
      inout       [15:0] SRAM_D,
      output             SRAM_LB_n,
      output             SRAM_OE_n,
      output             SRAM_UB_n,
      output             SRAM_WE_n,

      ///////// SW ///////// 1.2 V ///////
      input       [9:0]  SW,

      ///////// UART ///////// 2.5 V ///////
      input              UART_RX,
      output             UART_TX


);

`define CLK CLOCK_50_B5B

// note: this will get split across two blocks due to the wide read; m10k only support 32 bit for dual port/single port
(* ram_style = "block" *) reg [31:0] mem [4095:0]; // memory, 32 * 4096 bits, or 16kb

reg [31:0] fetch_addr = 32'b0; // pointer to mem for instruction fetch

reg [1:0] [31:0] predecode_instr; 

always @(posedge `CLK) begin
	predecode_instr <= {mem[(fetch_addr>>2)+1], mem[(fetch_addr>>2)]}; // dual issue, max of 2 instructions which are each 32 bits
end

reg STALL_FROM_RENAME = 0;
reg STALL_FROM_ISSUE = 0;

reg [31:0] prev_fetch_addr = 0;
always @(posedge `CLK or negedge CPU_RESET_n) begin
      prev_fetch_addr <= fetch_addr; // since address is one cycle delayed, this will match the actual predecoded instructions
      if (!(STALL_FROM_RENAME|STALL_FROM_ISSUE)) begin  // on a stall, the predecoded instr will be updated, but will stop progressing, when the stall 
            fetch_addr <= fetch_addr + 8; // is over the decode stage should have valid instructions and addresses to work with
      end
      if (~CPU_RESET_n) begin
            fetch_addr <= 0;
      end
end      

uop_t [1:0] uops_prerename;
decode decode (
	.clk(`CLK),
	.CPU_RESET_n(CPU_RESET_n),
	.instructions(predecode_instr),
	.prev_fetch_addr(prev_fetch_addr),
	.stall(STALL_FROM_RENAME|STALL_FROM_ISSUE), // stall condition, does nothing when it happens (which prevents the uop from being overwritten)
	.uops(uops_prerename)
);

reg [63:0] [31:0] p_regs = '0; // 64 32 bit physical registers
reg [63:0] p_reg_ready = {{63{1'b1}},1'b0}; // written back? set true by wb, set false by ROB (using ppreg), read by issue; 0 for reg[0] which is valid to read from unitiliazed (it feels like this should be inverted ;-;)

reg [63:0] f_list_allocated = '0; // what regs are free
reg [63:0] f_list_freed = '0; // for ROB
reg [3:0] tail = 0; // for ROB
reg [3:0] head = 0;

uop_t [1:0] uops_renamed = '0;
rob_ent_t [1:0] rob_entries = '0;
rename rename (
      // inputs
	.clk(`CLK),
	.CPU_RESET_n(CPU_RESET_n),
      .head(head),
	.uops(uops_prerename),
      .f_list_freed(f_list_freed),
      .stall(STALL_FROM_ISSUE),

      // outputs
      .f_list_allocated(f_list_allocated), // list of pregs allocated by rename
	.renamed(uops_renamed),
      .rob_entries(rob_entries),
      .tail(tail),
	.stall_backwards(STALL_FROM_RENAME) // incase not enough free regs are available
);

uop_t alu_1_uop = '0;
uop_t alu_2_uop = '0;
uop_t agu_uop = '0;

reg alu_1_valid = '0;
reg alu_2_valid = '0;
reg agu_valid = '0;

reg agu_ready = '1; // is unit ready

issue issue (
      // inputs
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uops_renamed(uops_renamed),
      .agu_ready(agu_ready), // needed because variable-cycle since we check LSQ and BRAM
      .p_reg_ready(p_reg_ready), // signals what's ready, all units are single cycle (except mem, which is flip-flopped) so their status is not passed through
      .head(head), // needed for oldest-instruction calculation
      // no stall input needed; it can only stall itself; may be wrong due to loading stage needing everything to shut up

      // outputs
      .alu_1_uop(alu_1_uop),
      .alu_1_valid(alu_1_valid),
      .alu_2_uop(alu_2_uop),
      .alu_2_valid(alu_2_valid),
      .agu_uop(agu_uop),
      .agu_valid(agu_valid),
      .stall_backwards(STALL_FROM_ISSUE)
);

typedef struct packed {
	logic        was_jmp; // if it was a jump type instruction
      logic        unconditional_jmp;
      logic [31:0] new_pc; // since RISC-V's JAL uses both a dest reg and changes PC
	logic [31:0] dst_val; // new reg val
	logic [5:0]  dst_reg; // same as above for destination
	logic        dst_valid;
      logic        pred_taken; // for later use, currently always not taken to simplify fetching
      logic        taken;   // if we're wrong
	logic        faulted;
	logic [3:0]  rob_id; // lets ROB know what entry it is
      logic        valid; // if it was even set this cycle
} post_ex_uop_t;

post_ex_uop_t [2:0] ex_uops = '0;
alu alu_1 (
      // inputs
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uop(alu_1_uop),
      .valid(alu_1_valid),
      .src_1(p_regs[alu_1_uop.src1_reg]),
      .src_2(p_regs[alu_1_uop.src2_reg]),

      // outputs
      .uop_out(ex_uops[0])
);

endmodule
