`include "types.svh"

module issue (
        input                      clk,
		input                      CPU_RESET_n,
		input  var uop_t [1:0]     uops_renamed,
	    input  reg       [63:0]    p_reg_ready,
        input                      agu_ready,
        input                      flush,

        output var uop_t           alu_1_uop,
        output reg                 alu_1_valid,
        output var uop_t           alu_2_uop,
        output reg                 alu_2_valid,
        output var uop_t           agu_uop,
        output reg                 agu_valid,
        output reg                 stall_backwards
);

uop_t [15:0] mem_issue_queue = '0;
reg [3:0] mem_head = '0;
// reg [3:0] mem_spec_head = '0; // cool trick for out of order mem
reg [3:0] mem_tail = '0;

uop_t [1:0] [7:0] alu_issue_queue = '0;
reg [1:0] [7:0] alu_uops_fl = '1;

always @(posedge clk or negedge CPU_RESET_n) begin // places uops into IQ
    if (!CPU_RESET_n) begin
        alu_uops_fl <= '1;
        mem_head <= '0;
        mem_tail <= '0;
        mem_issue_queue <= '0;
        alu_issue_queue <= '0;
        alu_1_uop <= '0;
        alu_2_uop <= '0;
        alu_1_valid <= '0;
        alu_2_valid <= '0;
        agu_uop <= '0;
        agu_valid <= '0;
        stall_backwards <= '0;
    end else if (flush) begin
        alu_uops_fl <= '1;
        mem_head <= '0;
        mem_tail <= '0;
        mem_issue_queue <= '0;
        alu_issue_queue <= '0;
        alu_1_uop <= '0;
        alu_2_uop <= '0;
        alu_1_valid <= '0;
        alu_2_valid <= '0;
        agu_uop <= '0;
        agu_valid <= '0;
        stall_backwards <= '0;
    end else begin
        logic [1:0] [3:0] acum_alu;
        acum_alu[0] = '0;
        for (int i = 0; i < 8; i++) begin
			acum_alu[0] = acum_alu[0] + alu_uops_fl[0][i];
		end
        acum_alu[1] = '0;
        for (int i = 0; i < 8; i++) begin
			acum_alu[1] = acum_alu[1] + alu_uops_fl[1][i];
		end

        // Prevent IQ from being filled up

        if ((acum_alu[0] <= 3) || (acum_alu[1] <= 3)
            || ((mem_tail+3) == (mem_head))
            || ((mem_tail+2) == (mem_head))
            || ((mem_tail+1) == (mem_head))
            || (((mem_tail) == (mem_head)) &&
            |mem_issue_queue[mem_head])) begin // this cycle=2, next cycle=2; at most 4 get consumed, but we don't want the count to jump from 5 to 3 and then stall too late
            stall_backwards <= 1'b1;
        end else begin 
            stall_backwards <= 1'b0;
        end

        // START ALU ISSUE
        alu_1_valid <= 1'b0;
        alu_2_valid <= 1'b0;
        
        for (int a = 0; a < 8; a = a + 1) begin
            if ((!alu_uops_fl[0][a]) && (!alu_issue_queue[0][a].src1_valid || p_reg_ready[alu_issue_queue[0][a].src1_reg]) &&
                (!alu_issue_queue[0][a].src2_valid || p_reg_ready[alu_issue_queue[0][a].src2_reg])) begin // if valid and sources are ready
                alu_uops_fl[0][a] = 1'b1;
                alu_1_uop <= alu_issue_queue[0][a];
                alu_1_valid <= 1;
                break;
            end
        end 
        for (int a = 0; a < 8; a = a + 1) begin
            if ((!alu_uops_fl[1][a]) && (!alu_issue_queue[1][a].src1_valid || p_reg_ready[alu_issue_queue[1][a].src1_reg]) &&
                (!alu_issue_queue[1][a].src2_valid || p_reg_ready[alu_issue_queue[1][a].src2_reg])) begin // if valid and sources are ready
                alu_uops_fl[1][a] = 1'b1;
                alu_2_uop <= alu_issue_queue[1][a];
                alu_2_valid <= 1;
                break;
            end
        end
        // END ALU ISSUE

        // START MEM ISSUE
        if (agu_ready && (!agu_valid)) begin
            if (!(mem_issue_queue[mem_head]))
                agu_valid <= '0;
            else begin
                if ((!mem_issue_queue[mem_head].src1_valid || p_reg_ready[mem_issue_queue[mem_head].src1_reg]) &&
                    (!mem_issue_queue[mem_head].src2_valid || p_reg_ready[mem_issue_queue[mem_head].src2_reg])) begin
                        agu_valid <= '1;
                        agu_uop <= mem_issue_queue[mem_head];
                        mem_issue_queue[mem_head] <= '0;
                        mem_head = mem_head + 1;
                        // mem_spec_head = mem_head;
                end else 
                    agu_valid <= '0;
                /* the following is a cool OoO trick that we can not use until we add squashing for the AGU
                end else if ((!mem_issue_queue[mem_spec_head+1].src1_valid || p_reg_ready[mem_issue_queue[mem_spec_head+1].src1_reg]) &&
                            (!mem_issue_queue[mem_spec_head+1].src2_valid || p_reg_ready[mem_issue_queue[mem_spec_head+1].src2_reg]) &&
                            !(mem_issue_queue[mem_spec_head])) begin
                        agu_valid <= '1;
                        agu_uop <= mem_issue_queue[mem_spec_head+1];
                        mem_issue_queue[mem_spec_head+1] <= '0;
                        mem_spec_head = mem_spec_head + 1; 
                end*/
            end
            // END MEM ISSUE 
        end else begin
            agu_valid <= '0;
        end
        if (!stall_backwards) begin // should have cycle delay since stall_insertion is non-blocking
            // START ISSUE INSERTION
            for (int i = 0; i < 2; i = i + 1) begin
                if (|uops_renamed[i]) begin // do not insert NOPs
                    if (uops_renamed[i].op_type == 3'b010 || uops_renamed[i].op_type == 3'b100 || uops_renamed[i].op_type == 3'b110 // inside statements seemingly unsupported by synth
                        || uops_renamed[i].op_type == 3'b111  || uops_renamed[i].op_type == 3'b000  || uops_renamed[i].op_type ==  3'b101) begin // ALU
                        for (int a = 0; a < 8; a = a + 1) begin // finds free IQ entry, should be auto-optimized to something better
                            if (alu_uops_fl[i][a] == 1'b1) begin
                                alu_issue_queue[i][a] <= uops_renamed[i];
                                alu_uops_fl[i][a] = 1'b0; // allocates it
                                break;
                            end
                        end
                    end else begin
                        mem_issue_queue[mem_tail] <= uops_renamed[i];
                        mem_tail = mem_tail + 1;
                    end
                end
            end
            // END ISSUE INSERTION
        end
    end
end
endmodule