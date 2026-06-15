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

		output reg       [63:0]    f_list_allocated, // needed due to ROB freeing p-regs, what to do during misspredict?
		output var uop_t [1:0]     renamed,
		output var rob_ent_t [1:0] rob_entries,
		output reg       [3:0]     tail,
		output reg                 stall_backwards
);

integer reset_rt;
integer i;
integer a;

reg [1:0] stall_backwards_conf;
reg [5:0] allocated_preg;
reg [63:0] f_list_dup;
reg [63:0] f_list;
reg [31:0] [5:0] rename_table_dup;
reg [31:0] [5:0] rename_table; // what register maps to what physical register

always @(posedge clk or negedge CPU_RESET_n) begin
	if (!CPU_RESET_n) begin
		f_list_allocated = '0;
		rob_entries = '0;
    	f_list = {{63{1'b1}},1'b0};
		stall_backwards <= '0;
		stall_backwards_conf <= '0;  
		for (reset_rt = 0; reset_rt < 32; reset_rt = reset_rt + 1) begin
			rename_table[reset_rt] <= '0; // read from 0 if unitialized
		end
		renamed <= '{default: '0};
		tail <= '0;
	end else if (stall) begin
		f_list <= f_list^f_list_freed;
		f_list_allocated <= '0;
	end else if (stall_backwards_conf == 2) begin
		logic [7:0] acum;
		logic [63:0] tmp_flist;
		tmp_flist = (f_list^f_list_freed);
		acum = '0;
		for (int i = 0; i < 64; i++) begin
			acum = acum + tmp_flist[i];
		end
		if (acum >= 6) begin
			stall_backwards_conf <= '0;
			stall_backwards <= '0;
		end
		f_list <= f_list^f_list_freed;
		f_list_allocated <= '0;
		renamed <= '0; // TODO; NOP
		// the tail won't be modified, so the ROB entries can remain untouched
	end else begin
		logic [7:0] acum;
		acum = '0;
		rename_table_dup = rename_table; // idk
		f_list_allocated = '0; // for XOR later on flist since commit can free
		f_list_dup = f_list^f_list_freed; // needed to see what can actually be used
		for (int i = 0; i < 64; i++) begin
			acum = acum + f_list_dup[i];
		end
		if (stall_backwards||(acum <= 5)) begin // basically tells everything else 
			stall_backwards_conf <= stall_backwards_conf + 1; // to stop and allows the rename stage
			stall_backwards <= '1;                            // to process remaining instructions
		end // the or condition prevents a perm-stall that would occur
		for (i = 0; i < 2; i = i + 1) begin // operate on all 2 uops
			allocated_preg = 0;
			if (!uops[i].faulted) begin // don't fill up rename table if invalid opcode
				renamed[i] <= uops[i]; // copy uop
				renamed[i].rob_id <= tail;
				tail = tail + 1;
				if (uops[i].src1_valid) begin
					renamed[i].src1_reg <= rename_table_dup[uops[i].src1_reg]; // update areg to preg
				end
				if (uops[i].src2_valid) begin
					renamed[i].src2_reg <= rename_table_dup[uops[i].src2_reg];
				end
				if (uops[i].dst_valid && (uops[i].dst_reg != 0)) begin
					for (a = 0; a < 64; a = a + 1) begin // finds free physical register, should be auto-optimized to something better
						if (f_list_dup[a] == 1'b1) begin
							allocated_preg = 6'(a);
							f_list_dup[a] = 1'b0; // allocates it
							f_list_allocated[a] = 1'b1;
							break;
						end
					end
					rob_entries[i].finished <= 1'b0;
					rob_entries[i].spec <= (uops[i].op_type == 3'b010 || uops[i].op_type == 3'b100 || uops[i].op_type == 3'b101);
					rob_entries[i].store <= (uops[i].op_type == 3'b011);
					rob_entries[i].dst_valid <= 1'b1;
					rob_entries[i].a_dst_reg <= uops[i].dst_reg;
					rob_entries[i].pp_dst_reg <= rename_table_dup[uops[i].dst_reg];
					rob_entries[i].p_dst_reg <= allocated_preg; 
					rob_entries[i].misspredict <= 1'b0;
					rob_entries[i].new_pc <= 32'b0;
					rename_table_dup[uops[i].dst_reg] = allocated_preg; // marks architectural register as pointing to this physical register
					renamed[i].dst_reg <= allocated_preg; // updates uop to reflect real physical register
				end else begin 
					rob_entries[i].finished <= 1'b0;
					rob_entries[i].spec <= (uops[i].op_type == 3'b010 || uops[i].op_type == 3'b100 || uops[i].op_type == 3'b101);
					rob_entries[i].store <= (uops[i].op_type == 3'b011);
					rob_entries[i].dst_valid <= 1'b0;
					rob_entries[i].a_dst_reg <= 6'b0;
					rob_entries[i].pp_dst_reg <= 6'b0;
					rob_entries[i].p_dst_reg <= 6'b0; 
					rob_entries[i].misspredict <= 1'b0;
					rob_entries[i].new_pc <= 32'b0;
				end
			end else begin
				rob_entries[i] <= '1; // will check in ROB
				renamed[i] <= uops[i]; // TODO: replace with NOP
				renamed[i].rob_id <= tail;
				tail = tail + 1;
			end
		end
		f_list <= f_list_dup;
		rename_table <= rename_table_dup;
	end
end
endmodule
