`include "types.svh"

module issue (
        input                      clk,
		input                      CPU_RESET_n,
		input  var uop_t [1:0]     uops_renamed,
		input  reg       [63:0]    p_reg_ready,
        input  reg       [3:0]     head,
        input                      agu_ready,

        output var uop_t           alu_1_uop,
        output reg                 alu_1_valid,
        output var uop_t           alu_2_uop,
        output reg                 alu_2_valid,
        output var uop_t           agu_uop,
        output reg                 agu_valid,
        output reg                 stall_backwards
);

uop_t [15:0] mem_issue_queue = '0;
reg [15:0] mem_uops_fl = '1;

uop_t [7:0] alu_issue_queue = '0;
reg [7:0] alu_uops_fl = '1;
int i, a;
reg [15:0] [15:0] valid_mem_ages; // this is wrong, but we are gonna refractor mem logic anyways so :shrug:
reg [15:0] mem_age_valid;
always @(posedge clk or negedge CPU_RESET_n) begin // places uops into IQ
    if (!CPU_RESET_n) begin
        alu_uops_fl <= '1;
        mem_uops_fl <= '1;
        mem_issue_queue <= '0;
        alu_issue_queue <= '0;
        valid_mem_ages <= '0;
        mem_age_valid <= '0;
        alu_issue_queue <= '0;
        alu_1_uop <= '0;
        alu_2_uop <= '0;
        alu_1_valid <= '0;
        alu_2_valid <= '0;
        agu_uop <= '0;
        agu_valid <= '0;
        stall_backwards <= '0;
    end
    else begin
        logic [3:0] acum_alu;
        logic [7:0] acum_agu;
        acum_alu = '0;
        acum_agu = '0;
		for (int i = 0; i < 16; i++) begin
			acum_agu = acum_agu + mem_uops_fl[i];
		end
        for (int i = 0; i < 8; i++) begin
			acum_alu = acum_alu + alu_uops_fl[i];
		end
        // Prevent IQ from being filled up

        if ((acum_alu <= 5) || (acum_agu <= 5)) begin // this cycle=2, next cycle=2; at most 4 get consumed, but we don't want the count to jump from 5 to 3 and then stall too late
            stall_backwards <= 1'b1;
        end else begin 
            stall_backwards <= 1'b0;
        end

        // START ALU ISSUE
        alu_1_valid <= 1'b0;
        alu_2_valid <= 1'b0;
        
        for (a = 0; a < 8; a = a + 1) begin
            if ((!alu_uops_fl[a]) && (!alu_issue_queue[a].src1_valid || p_reg_ready[alu_issue_queue[a].src1_reg]) &&
                (!alu_issue_queue[a].src2_valid || p_reg_ready[alu_issue_queue[a].src2_reg])) begin // if valid and sources are ready
                alu_uops_fl[a] = 1'b1;
                alu_1_uop <= alu_issue_queue[a];
                alu_1_valid <= 1;
                break;
            end
        end 
        for (a = 0; a < 8; a = a + 1) begin
            if ((!alu_uops_fl[a]) && (!alu_issue_queue[a].src1_valid || p_reg_ready[alu_issue_queue[a].src1_reg]) &&
                (!alu_issue_queue[a].src2_valid || p_reg_ready[alu_issue_queue[a].src2_reg])) begin // if valid and sources are ready
                alu_uops_fl[a] = 1'b1;
                alu_2_uop <= alu_issue_queue[a];
                alu_2_valid <= 1;
                break;
            end
        end
        // END ALU ISSUE

        // START MEM ISSUE
        if (agu_ready && (!agu_valid)) begin // note this is going to be replaced by a simple head/tail buffer
            for (a = 0; a < 16; a = a + 1) begin // finds oldest mem-access
                if (mem_uops_fl[a] == 1'b0) begin
                    valid_mem_ages[a] = mem_issue_queue[a].rob_id - head;
                    mem_age_valid[a] = 1'b1;
                end else
                    mem_age_valid[a] = 1'b0;
            end
            for (a = 0; a < 8; a = a + 1) begin // sort
                if (mem_age_valid[a*2] && mem_age_valid[a*2+1]) begin
                    valid_mem_ages[a*2] = valid_mem_ages[a*2+(valid_mem_ages[a*2+1] < valid_mem_ages[a*2])]; // puts younger entry into every other entry
                end // else if (mem_age_valid[a*2]) // don't need to do anything
                else if (mem_age_valid[a*2+1]) begin
                    valid_mem_ages[a*2] = valid_mem_ages[a*2+1];
                    mem_age_valid[a*2] = 1;
                end
            end
            for (a = 0; a < 4; a = a + 1) begin // sort
                if (mem_age_valid[a*4] && mem_age_valid[a*4+2]) begin
                    valid_mem_ages[a*4] = valid_mem_ages[a*4+(2*(valid_mem_ages[a*4+2] < valid_mem_ages[a*4]))]; // puts younger entry into every other entry
                end // else if (mem_age_valid[a*2]) // don't need to do anything
                else if (mem_age_valid[a*4+2]) begin
                    valid_mem_ages[a*4] = valid_mem_ages[a*4+2];
                    mem_age_valid[a*4] = 1;
                end
            end
            for (a = 0; a < 2; a = a + 1) begin // sort
                if (mem_age_valid[a*8] && mem_age_valid[a*8+4]) begin
                    valid_mem_ages[a*8] = valid_mem_ages[a*8+(4*(valid_mem_ages[a*8+4] < valid_mem_ages[a*8]))]; // puts younger entry into every other entry
                end // else if (mem_age_valid[a*2]) // don't need to do anything
                else if (mem_age_valid[a*8+4]) begin
                    valid_mem_ages[a*8] = valid_mem_ages[a*8+4];
                    mem_age_valid[a*8] = 1;
                end
            end
            if (mem_age_valid[0] && mem_age_valid[8]) begin
                valid_mem_ages[0] = valid_mem_ages[8*(valid_mem_ages[8] < valid_mem_ages[0])]; // puts younger entry into every other entry
            end // else if (mem_age_valid[a*2]) // don't need to do anything
            else if (mem_age_valid[8]) begin
                valid_mem_ages[0] = valid_mem_ages[8];
                mem_age_valid[0] = 1;
            end
            if (!(mem_age_valid[0]))
                agu_valid <= '0;
            else begin
                for (a = 0; a < 16; a = a + 1) begin
                    if ((mem_issue_queue[a].rob_id-head) == valid_mem_ages[0]) begin
                        if ((!mem_issue_queue[a].src1_valid || p_reg_ready[mem_issue_queue[a].src1_reg]) &&
                                (!mem_issue_queue[a].src2_valid || p_reg_ready[mem_issue_queue[a].src2_reg])) begin
                            agu_valid <= '1;
                            agu_uop <= mem_issue_queue[a];
                            mem_uops_fl[a] = 1'b1;
                        end else 
                            agu_valid <= '0; 
                    end
                end
            end
            // END MEM ISSUE 
        end else begin
            agu_valid <= '0;
        end
        if (!stall_backwards) begin // should have cycle delay since stall_insertion is non-blocking
            // START ISSUE INSERTION
            for (i = 0; i < 2; i = i + 1) begin
                if (uops_renamed[i].op_type == 3'b010 || uops_renamed[i].op_type == 3'b100 || uops_renamed[i].op_type == 3'b110 // inside statements seemingly unsupported by synth
                     || uops_renamed[i].op_type == 3'b111  || uops_renamed[i].op_type == 3'b000  || uops_renamed[i].op_type ==  3'b101) begin // ALU
                    for (a = 0; a < 8; a = a + 1) begin // finds free IQ entry, should be auto-optimized to something better
                        if (alu_uops_fl[a] == 1'b1) begin
                            alu_issue_queue[a] <= uops_renamed[i];
                            alu_uops_fl[a] = 1'b0; // allocates it
                            break;
                        end
                    end
                end else begin 
                    for (a = 0; a < 16; a = a + 1) begin // finds free IQ entry, should be auto-optimized to something better
                        if (mem_uops_fl[a] == 1'b1) begin
                            mem_issue_queue[a] <= uops_renamed[i];
                            mem_uops_fl[a] = 1'b0; // allocates it
                            break;
                        end
                    end
                end
            end
            // END ISSUE INSERTION
        end
    end
end
endmodule