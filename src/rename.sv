`include "types.svh"

/* This module is responsible for renaming registers to reflect
// their physical register indexes, allocating registers that will
// be overwritten. It does this by taking the list of freshly de-alloced
// regs from the ROB, xoring it with an internal free list, then looking
// for free spaces to place registers. The registers it allocates is 
// placed in a list that will be exposed to the commit stage for 
// deallocation. */


module rename (
        input                      clk,
		input                      CPU_RESET_n,
		input                      stall,
		input            [3:0]     head,
		input  var uop_t [1:0]     uops,
		input  reg       [63:0]    f_list_freed,
		input                      flush,
		input  var    [31:0] [5:0] a_reg_state,

		output reg       [63:0]    f_list_allocated, // needed due to wb ready-ing p-regs and ROB freeing using previous physical register, what to do during misspredict?
		output var uop_t [1:0]     renamed,
		output var rob_ent_t [1:0] rob_entries,
		output reg       [1:0]     rob_ent_val,
		output reg       [3:0]     tail,
		output reg                 stall_backwards
);

reg [5:0] allocated_preg;
reg [63:0] f_list_dup;
reg [63:0] f_list;
reg [31:0] [5:0] rename_table; // what register maps to what physical register

always @(posedge clk or negedge CPU_RESET_n) begin
	if (!CPU_RESET_n||flush) begin
		f_list_allocated <= '0;
		rob_entries <= '0;
    	f_list <= {{63{1'b1}},1'b0};
		stall_backwards <= '0;
		for (int reset_rt = 0; reset_rt < 32; reset_rt++) begin
			rename_table[reset_rt] = '0; // read from 0 if unitialized
		end
		renamed <= '{default: '0};
		tail <= '0;
		rob_ent_val <= '0;
		if (flush) begin
			for (int reset_rt = 0; reset_rt < 32; reset_rt++) begin
				rename_table[reset_rt] = a_reg_state[reset_rt];
				f_list[a_reg_state[reset_rt]] <= 1'b0;
			end
		end
	end else if (stall) begin
		f_list <= f_list^f_list_freed;
		f_list_allocated <= '0;
		rob_ent_val <= '0;
	end else if (stall_backwards) begin
		logic [7:0] acum;
		logic [63:0] tmp_flist;
		tmp_flist = (f_list^f_list_freed);
		acum = '0;
		for (int i = 0; i < 64; i++) begin
			acum = acum + tmp_flist[i];
		end
		if (acum >= 3 && (head-tail > 3)) begin
			stall_backwards <= '0;
		end
		f_list <= f_list^f_list_freed;
		f_list_allocated <= '0;
		renamed <= '0; // NOP
		rob_ent_val <= '0;
		// the tail won't be modified, so the ROB entries can remain untouched
	end else begin
		logic [7:0] acum;
		logic [3:0] tail_inc;
		tail_inc = tail;
		acum = '0;
		f_list_allocated <= '0; // for XOR later on flist since commit can free
		f_list_dup = f_list^f_list_freed; // needed to see what can actually be used
		for (int i = 0; i < 64; i++) begin
			acum = acum + f_list_dup[i];
		end
		if (acum <= 3 || ((head-tail <= 3) && (head != tail))) begin // basically tells everything else 
			stall_backwards <= '1;                            // to process remaining instructions
		end // the or condition prevents a perm-stall that would occur
		for (int i = 0; i < 2; i++) begin // operate on all 2 uops
			allocated_preg = 0;
			if (!uops[i].faulted && (|uops[i])) begin // don't fill up rename table if invalid opcode
				rob_ent_val[i] <= 1'b1;
				renamed[i] <= uops[i]; // copy uop
				renamed[i].rob_id <= tail_inc;
				tail_inc = tail_inc + 1;
				if (uops[i].src1_valid) begin
					renamed[i].src1_reg <= rename_table[uops[i].src1_reg]; // update areg to preg
				end
				if (uops[i].src2_valid) begin
					renamed[i].src2_reg <= rename_table[uops[i].src2_reg];
				end
				if (uops[i].dst_valid) begin
					if (uops[i].dst_reg != 0) begin
						for (int a = 0; a < 64; a++) begin // finds free physical register, should be auto-optimized to something better
							if (f_list_dup[a] == 1'b1) begin
								allocated_preg = 6'(a);
								f_list_dup[a] = 1'b0; // allocates it
								f_list_allocated[a] <= 1'b1;
								break;
							end
						end
					end else  
						allocated_preg = 6'b0; // mem to 0 needs to actually execute so we can fault if bad access
					rob_entries[i].finished <= 1'b0;
					rob_entries[i].spec <= (uops[i].op_type == 3'b010 || uops[i].op_type == 3'b100);
					rob_entries[i].store <= (uops[i].op_type == 3'b011);
					rob_entries[i].dst_valid <= 1'b1;
					rob_entries[i].a_dst_reg <= uops[i].dst_reg;
					rob_entries[i].pp_dst_reg <= rename_table[uops[i].dst_reg];
					rob_entries[i].p_dst_reg <= allocated_preg; 
					rob_entries[i].misspredict <= 1'b0;
					rob_entries[i].new_pc <= 32'b0;
					rename_table[uops[i].dst_reg] = allocated_preg; // marks architectural register as pointing to this physical register
					renamed[i].dst_reg <= allocated_preg; // updates uop to reflect real physical register
				end else begin 
					rob_entries[i].finished <= 1'b0;
					rob_entries[i].spec <= (uops[i].op_type == 3'b010 || uops[i].op_type == 3'b100);
					rob_entries[i].store <= (uops[i].op_type == 3'b011);
					rob_entries[i].dst_valid <= 1'b0;
					rob_entries[i].a_dst_reg <= 6'b0;
					rob_entries[i].pp_dst_reg <= 6'b0;
					rob_entries[i].p_dst_reg <= 6'b0; 
					rob_entries[i].misspredict <= 1'b0;
					rob_entries[i].new_pc <= 32'b0;
				end
			end else if (|uops[i]) begin
				rob_ent_val[i] <= 1'b1;
				rob_entries[i] <= '0; 
				rob_entries[i].faulted <= 1'b1;
				renamed[i] <= '0; // replace with NOP
				renamed[i].rob_id <= tail_inc;
				tail_inc = tail_inc + 1;
			end else begin
				renamed[i] <= '0; // we have to pass forward nops
				rob_ent_val[i] <= 1'b0;
			end
		end
		tail <= tail_inc;
		f_list <= f_list_dup;
	end
end
endmodule
