//`define ENABLE_DDR2LP
//`define ENABLE_HSMC_XCVR
//`define ENABLE_SMA
//`define ENABLE_REFCLK
//`define ENABLE_GPIO
`include "types.svh"

module cpu(
/*
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
*/
      input              CLOCK_50_B5B, ///3.3-V LVTTL
/*      input              CLOCK_50_B6A,
      input              CLOCK_50_B7A, ///2.5 V
      input              CLOCK_50_B8A,

      ///////// CPU /////////
      */
      input              CPU_RESET_n, ///3.3V LVTTL
/*
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
`endif

`ifdef ENABLE_GPIO
      ///////// GPIO ///////// 3.3-V LVTTL ///////
      inout       [35:0] GPIO,
`else
      ///////// HEX2 ///////// 1.2 V ///////
      output      [6:0]  HEX2,

      ///////// HEX3 ///////// 1.2 V ///////
      output      [6:0]  HEX3,


`endif

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
`endif 
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
*/
      ///////// LEDR ///////// 2.5 V ///////
      output      [9:0]  LEDR,
/*
`ifdef ENABLE_REFCLK
      ///////// REFCLK ///////// 1.5-V PCML ///////
      input              REFCLK_p0,
      input              REFCLK_p1,
`endif 

      ///////// SD ///////// 3.3-V LVTTL ///////
      output             SD_CLK,
      inout              SD_CMD,
      inout       [3:0]  SD_DAT,

`ifdef ENABLE_SMA
      ///////// SMA ///////// 1.5-V PCML ///////
      input              SMA_GXB_RX_p,
      output             SMA_GXB_TX_p,
`endif 

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
*/
      ///////// UART ///////// 2.5 V ///////
      input              UART_RX,
      output             UART_TX


);

`define CLK CLOCK_50_B5B

reg [31:0] fetch_addr = 32'b0; // pointer to mem for instruction fetch
reg halt;

reg [1:0] [31:0] predecode_instr; 
reg [31:0] [5:0] a_reg_state;

reg STALL_FROM_RENAME = 0;
reg STALL_FROM_ISSUE = 0;
reg flush = 0;
reg loading;
reg [31:0] loaded_word = 0;
reg loaded_valid = 0;

reg next_n_first_valid = 0;
reg n_first_valid = 0;
reg jmp;
reg [31:0] cycle_count = 0;
reg [15:0] misspred_count = 0;
reg [15:0] jump_count = 0;
reg [31:0] load_ptr;
reg [31:0] new_pc = 0;
reg [31:0] new_flush_pc = 0;
reg [31:0] prev_fetch_addr = 0;

reg we1;
reg we2;
reg [31:0] i_buf_one;
reg [31:0] i_buf_two;

reg [31:0] load_ptr_tmp;
reg [31:0] fetch_addr_aligned;

// note: this will get split across two blocks due to the wide read; m10k only support 32 bit for dual port/single port
(* ramstyle = "M10K" *) reg [31:0] mem1 [2047:0]; // memory, 32 * 4096 bits, or 16kb
(* ramstyle = "M10K" *) reg [31:0] mem2 [2047:0];

reg [31:0] tmp_load_word;
assign predecode_instr = {i_buf_two, i_buf_one};
always @(posedge `CLK) begin
      i_buf_one <= mem1[fetch_addr_aligned];
      if (we1)
            mem1[load_ptr_tmp] <= tmp_load_word;
end

always @(posedge `CLK) begin
      i_buf_two <= mem2[fetch_addr_aligned];
      if (we2)
            mem2[load_ptr_tmp] <= tmp_load_word;
end

// missunderstood BRAM; this is combinational now

always @(*) begin
      fetch_addr = prev_fetch_addr;
      next_n_first_valid = 0;
      fetch_addr_aligned = 0;
      if (loading) begin

      end else if (flush) begin
            next_n_first_valid = 1'b0;
            fetch_addr = {new_flush_pc >> 3, 3'b000}; 
            if ({new_flush_pc >> 3, 3'b000} != new_flush_pc)
                  next_n_first_valid = 1'b1;
      end else begin
            if (!(STALL_FROM_RENAME|STALL_FROM_ISSUE)) begin
                  next_n_first_valid = 1'b0;
                  if (jmp) begin
                        fetch_addr = {new_pc >> 3, 3'b000}; 
                        if ({new_pc >> 3, 3'b000} != new_pc)
                              next_n_first_valid = 1'b1;
                  end else begin
                        fetch_addr = prev_fetch_addr + 8;
                  end
            end 
      end
      fetch_addr_aligned = fetch_addr >> 3;
end      

always @(posedge `CLK or negedge CPU_RESET_n) begin
      if (!CPU_RESET_n) begin
            load_ptr <= 0;
            cycle_count <= 0;
            n_first_valid <= 0;
            jump_count <= 0;
            prev_fetch_addr <= -8;
            misspred_count <= 0;
            we1 <= 1'b0;
            we2 <= 1'b0;
      end else if (loading) begin
            we1 <= 1'b0;
            we2 <= 1'b0;
            if (loaded_valid) begin
                  if (load_ptr <= 4095) begin
                        tmp_load_word <= loaded_word;
                        load_ptr <= load_ptr + 1;
                        load_ptr_tmp <= {load_ptr} >> 1;
                        if (load_ptr[0]) // even
                              we2 <= 1'b1;
                        else 
                              we1 <= 1'b1;
                  end
            end
      end else if (flush) begin
            n_first_valid <= next_n_first_valid;
            prev_fetch_addr <= {new_flush_pc >> 3, 3'b000};
            misspred_count <= misspred_count + 1;
            cycle_count <= cycle_count + 1;
      end else begin
            cycle_count <= cycle_count + 1;
            if (!(STALL_FROM_RENAME|STALL_FROM_ISSUE)) begin
                  n_first_valid <= next_n_first_valid;
                  if (jmp) begin
                        jump_count <= jump_count + 1;
                        prev_fetch_addr <= {new_pc >> 3, 3'b000};
                  end else begin
                        prev_fetch_addr <= fetch_addr;
                  end
            end 
      end
end
reg [1:0] update_btb;
reg [1:0] [1:0] taken;
uop_t [1:0] uops_prerename;
decode decode (
	.clk(`CLK),
      .flush(flush),
      .loading(loading),
	.CPU_RESET_n(CPU_RESET_n),
      .update_btb(update_btb),
      .taken(taken),
      .n_valid(n_first_valid),
	.instructions(predecode_instr),
	.prev_fetch_addr(prev_fetch_addr),
	.stall(STALL_FROM_RENAME|STALL_FROM_ISSUE), // stall condition, does nothing when it happens (which prevents the uop from being overwritten)
	
      .uops(uops_prerename),
      .new_pc(new_pc),
      .jmp(jmp)
);

reg [63:0] [31:0] p_regs; // 64 32 bit physical registers
// every register is initally pointing towards the 0th reg
// so when we need to write somwhere we change the preg to
// something marked as not written back for a safe initial 
// state
reg [63:0] p_reg_ready; // written back

reg [63:0] f_list_allocated; // what regs are free
reg [63:0] f_list_freed; // for ROB
reg [3:0] tail; // for ROB
reg [3:0] head;

uop_t [1:0] uops_renamed;
rob_ent_t [1:0] rob_entries;
reg [1:0] rob_ent_val;
rename rename (
      // inputs
	.clk(`CLK),
	.CPU_RESET_n(CPU_RESET_n),
      .head(head),
	.uops(uops_prerename),
      .f_list_freed(f_list_freed),
      .stall(STALL_FROM_ISSUE),
      .a_reg_state(a_reg_state),
      .flush((flush|loading)),

      // outputs
      .f_list_allocated(f_list_allocated), // list of pregs allocated by rename
	.renamed(uops_renamed),
      .rob_entries(rob_entries),
      .rob_ent_val(rob_ent_val),
      .tail(tail),
	.stall_backwards(STALL_FROM_RENAME) // incase not enough free regs are available
);

uop_t alu_1_uop;
uop_t alu_2_uop;
uop_t agu_uop;

reg alu_1_valid;
reg alu_2_valid;
reg agu_valid;

reg agu_ready; // is unit ready

issue issue (
      // inputs
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uops_renamed(uops_renamed),
      .agu_ready(agu_ready), // needed because variable-cycle since we check LSQ and BRAM
      .p_reg_ready(p_reg_ready), // signals what's ready
      .flush((flush|loading)),

      // outputs
      .alu_1_uop(alu_1_uop),
      .alu_1_valid(alu_1_valid),
      .alu_2_uop(alu_2_uop),
      .alu_2_valid(alu_2_valid),
      .agu_uop(agu_uop),
      .agu_valid(agu_valid),
      .stall_backwards(STALL_FROM_ISSUE)
);

post_ex_uop_t [2:0] ex_uops = '0;
alu alu_1 (
      // inputs
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uop(alu_1_uop),
      .valid(alu_1_valid),
      .src_1(p_regs[alu_1_uop.src1_reg]),
      .src_2(p_regs[alu_1_uop.src2_reg]),
      .flush((flush|loading)),

      // outputs
      .uop_out(ex_uops[0])
);

alu alu_2 (
      // inputs
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uop(alu_2_uop),
      .valid(alu_2_valid),
      .src_1(p_regs[alu_2_uop.src1_reg]),
      .src_2(p_regs[alu_2_uop.src2_reg]),
      .flush((flush|loading)),

      // outputs
      .uop_out(ex_uops[1])
);

reg [3:0] retire_rob_id;
reg retire_rob_valid;

agu agu (
      .clk(`CLK),
      .CPU_RESET_n(CPU_RESET_n),
      .uop(agu_uop),
      .valid(agu_valid),
      .src_1(p_regs[agu_uop.src1_reg]),
      .src_2(p_regs[agu_uop.src2_reg]),
      .retire_rob_id(retire_rob_id),
      .retire_rob_valid(retire_rob_valid),
      .flush((flush)),
      .UART_RX(UART_RX),

      .uop_out(ex_uops[2]),
      .loaded_valid(loaded_valid),
      .loaded_word(loaded_word),
      .loading(loading),
      .agu_ready(agu_ready)
);

// writeback; very simple so no module
always @(posedge `CLK or negedge CPU_RESET_n) begin
      if (!CPU_RESET_n) begin
            p_regs <= '0;
            p_reg_ready <= {{63{1'b0}},1'b1};
      end else if (!(flush|loading)) begin 
            logic [63:0] p_reg_ready_tmp;
            p_reg_ready_tmp = p_reg_ready & ~f_list_allocated; // just allocated == not yet ready
            for (int i = 0; i < 3; i++) begin
                  if (ex_uops[i].valid 
                  && ex_uops[i].dst_valid 
                  && !ex_uops[i].faulted
                  && (ex_uops[i].dst_reg != 0)) begin
                        p_regs[ex_uops[i].dst_reg] <= ex_uops[i].dst_val;
                        p_reg_ready_tmp[ex_uops[i].dst_reg] = 1'b1;
                  end
            end
            p_reg_ready <= p_reg_ready_tmp;
      end
end 
assign LEDR = p_regs;
retire retire (
      .clk(`CLK),
      .reset(CPU_RESET_n),
      .rob_entries(rob_entries),
      .rob_ent_val(rob_ent_val),
      .ex_uops(ex_uops),

      .head(head),
      .a_reg_state(a_reg_state), 
      .new_pc(new_flush_pc),
      .flush(flush), // misspred handiling
      .halt(halt), // if we retire faulted
      .f_list_freed(f_list_freed),
      .retire_rob_id(retire_rob_id),
      .retire_rob_valid(retire_rob_valid),
      .update_btb(update_btb),
      .taken(taken)
);

endmodule
