`include "types.svh"

module decode (
        input              clk,
		input              CPU_RESET_n,
		input              flush,
		input              stall,
		input  [31:0]      prev_fetch_addr,
		input              n_valid,
		input [1:0] [31:0] instructions,
		output uop_t [1:0] uops,
		output reg [31:0]  new_pc,
		output reg         jmp
);

localparam R_type = 7'b0110011; // register-register arithmatic
localparam I_type = 7'b0010011; // register-constant
localparam I_mem_type = 7'b0000011; // mem-to-reg
localparam I_jmp_type = 7'b1100111; // jmp to pc+reg
localparam S_type = 7'b0100011; // store in mem
localparam B_type = 7'b1100011; // conditional branching
localparam J_type = 7'b1101111; // maybe move to predecode? jmp to immediate+PC
localparam U_type = 7'b0110111; // load immediate
localparam U_secondary_type = 7'b0010111; // load immediate plus PC
integer i;

// todo:
// handle jumps imediatly
// multiply extension
// atomic extension
// environment calls/breaks
// some I/O instructions(?)

reg [31:0] prev_prev_fetch_addr = '0;
reg just_jumped = 0;

always @(posedge clk or negedge CPU_RESET_n) begin
	if (!CPU_RESET_n || flush) begin
		uops <= '0;
		just_jumped <= '1; // cycle delay during reset
	end else begin
		if ((just_jumped && !stall)) begin
			just_jumped <= 1'b0;
			new_pc <= 1'b0;
			uops <= '0;
			jmp <= 1'b0;
		end else if (!stall) begin
			logic jumped;
			jumped = 0;
			uops <= '0;
			for (i = 0; i < 2; i = i + 1) begin // despite the for loop, this is done in parellel
				uops[i].pc <= prev_fetch_addr + (i*4); // 4 bytes
				uops[i].faulted <= 0;
				if ((instructions[i][1:0]) == 2'b11 && !jumped && (i != 0 || !n_valid)) begin // non-compressed
					case (instructions[i][6:0])
						R_type : begin // assigns src1, src2, and dst
								uops[i].op_type <= 3'b0; // ALU
								uops[i].op <= {instructions[i][30], instructions[i][14:12]}; // extracts operation type from funct3/7
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_reg <= instructions[i][24:20];
								uops[i].src2_valid <= 1'b1;
								uops[i].dst_valid <= 1'b1;
								uops[i].dst_reg <= instructions[i][11:7];
								if ((instructions[i][31:25] != 7'h00) && // possibly invalid funct7
									!((instructions[i][31:25] == 7'h20) && // valid for certain instructions
									((instructions[i][14:12] == 3'h0) || (instructions[i][14:12] == 3'h5)))) begin // only opcodes which it makes sense
									uops[i].faulted <= 1;
								end
							end
						I_type : begin // assigns src1, dst, and immediate
								uops[i].op_type <= 3'b0; // ALU
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].dst_valid <= 1'b1;
								uops[i].immediate <= instructions[i][31:20];
								if (((instructions[i][31:25] != 7'h20) && (instructions[i][31:25] != 7'h00))
									&& (instructions[i][14:12] == 3'h5)) begin // due to dual use as immediate
									uops[i].faulted <= 1;
								end
								if ((instructions[i][14:12] == 3'b101) || (instructions[i][14:12] == 3'b001))
									uops[i].op <= {instructions[i][30], instructions[i][14:12]}; // extracts operation type from funct3/immediate
								else begin // converts addi into subi if the MSB is one (if the number is negative)	
									uops[i].op <= {1'b0, instructions[i][14:12]};
								end 
							end
						I_mem_type : begin // assigns src1, dst, and immediate
								uops[i].op_type <= 3'b1; // memory read
								uops[i].op <= {1'b0, instructions[i][14:12]}; // extracts operation type from funct3
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].dst_valid <= 1'b1;
								uops[i].immediate <= instructions[i][31:20];
							end
						I_jmp_type : begin // assigns src1, dst, and immediate
								uops[i].op_type <= 3'b10; // jmp+reg type
								uops[i].op <= {1'b0, instructions[i][14:12]}; // extracts operation type from funct3
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].dst_valid <= 1'b1;
								uops[i].immediate <= instructions[i][31:20];
								if (instructions[i][14:12] != 3'b0)
									uops[i].faulted <= 1;
							end
						S_type : begin // assigns src1, src2, and immediate
								uops[i].op_type <= 3'b11; // memory write
								uops[i].op <= {1'b0, instructions[i][14:12]}; // extracts operation type from funct3
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_reg <= instructions[i][24:20];
								uops[i].src2_valid <= 1'b1;
								uops[i].dst_valid <= 1'b0;
								uops[i].immediate <= {instructions[i][31:25], instructions[i][11:7]};
								if (instructions[i][14:12] == 3'b111 || instructions[i][14:12] == 3'b110)
									uops[i].faulted <= 1;
							end
						B_type : begin // assigns src1, src2, and immediate
								uops[i].op_type <= 3'b100; // branch type
								uops[i].op <= {1'b0, instructions[i][14:12]}; // extracts operation type from funct3
								uops[i].src1_reg <= instructions[i][19:15];
								uops[i].src1_valid <= 1'b1;
								uops[i].src2_reg <= instructions[i][24:20];
								uops[i].src2_valid <= 1'b1;
								uops[i].dst_valid <= 1'b0;
								uops[i].immediate <= {8'b0, instructions[i][31], instructions[i][7], instructions[i][30:25], instructions[i][11:8]}; // why
							end
						J_type : begin // assigns immediate, dst1
								just_jumped <= 1'b1; // so next cycle inserts bubbles
								jumped = 1; // so next instruction becomes bubble
								jmp <= 1'b1; // so fetch knows to update PC
								new_pc <= prev_fetch_addr + (i*4) + {{12{instructions[i][31]}}, instructions[i][19:12], instructions[i][20], instructions[i][30:21], 1'b0};
								uops[i].op_type <= 3'b101; // jmp pc+imm type
								uops[i].src1_valid <= 1'b0;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_valid <= 1'b1;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].immediate <= {instructions[i][31], instructions[i][19:12], instructions[i][20], instructions[i][30:21]};
							end
						U_type : begin // b0110111
								uops[i].op_type <= 3'b110; // load type
								uops[i].src1_valid <= 1'b0;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_valid <= 1'b1;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].immediate <= instructions[i][31:12];
							end
						U_secondary_type : begin // b0010111
								uops[i].op_type <= 3'b111; // load+pc type
								uops[i].src1_valid <= 1'b0;
								uops[i].src2_valid <= 1'b0;
								uops[i].dst_valid <= 1'b1;
								uops[i].dst_reg <= instructions[i][11:7];
								uops[i].immediate <= instructions[i][31:12];
							end
						default:
							uops[i].faulted <= 1;
					endcase
				end else if (jumped||(i==0 && n_valid)) 
					uops[i] <= '0;
				else // compressed
					uops[i].faulted <= 1;
			end
		end
	end
end
endmodule
