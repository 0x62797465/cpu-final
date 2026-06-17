`include "types.svh"

module retire (
    input clk,
    input reset,
    input var rob_ent_t [1:0] rob_entries,
    input [1:0] rob_ent_val,
    input var post_ex_uop_t [2:0] ex_uops,
    //input tail,

    output reg [3:0] head,
    output reg [5:0] [31:0] a_reg_state,
    output reg [31:0] new_pc,
    output reg flush, // misspred handiling
    output reg halt, // if we retire faulted
    output reg [63:0] f_list_freed,
    output reg [3:0] retire_rob_id,
    output reg retire_rob_valid
);

rob_ent_t [15:0] rob = '0;
reg [3:0] tail = '0;

// insertion for new & completed instructions
always @(posedge clk or negedge reset) begin
    if (!reset||flush) begin
        rob <= '0;
        tail <= '0;
    end else begin
        logic [3:0] tmp_tail;
        tmp_tail = tail; 
        for (int i = 0; i < 2; i++) begin
            if (rob_ent_val[i]) begin
                rob[tmp_tail] <= rob_entries[i];
                tmp_tail = tmp_tail + 1;
            end
        end
        tail <= tmp_tail;
        for (int i = 0; i < 3; i++) begin
            if (ex_uops[i].valid) begin
                rob[ex_uops[i].rob_id].misspredict <= (ex_uops[i].was_jmp && 
                    (ex_uops[i].pred_taken != ex_uops[i].taken));
                rob[ex_uops[i].rob_id].finished <= 1'b1;
                rob[ex_uops[i].rob_id].new_pc <= rob[ex_uops[i].rob_id].new_pc;
            end
        end
    end
end

always @(posedge clk or negedge reset) begin
    if (!reset||flush) begin
        head <= '0;
        retire_rob_valid <= '0;
        f_list_freed = '0;
        flush <= '0;
        new_pc <= '0;
        if (!reset) begin
            a_reg_state = '0;
        end
    end else begin
        logic prev_ready;
        logic [3:0] tmp_head;
        f_list_freed <= '0;
        tmp_head = head;
        prev_ready = 1;
        retire_rob_valid <= 0;
        for (int i = 0; i < 2; i++) begin // subject to change
            if (prev_ready && rob[tmp_head].finished) begin
                if (rob[tmp_head].store) begin
                    prev_ready = 0;
                    retire_rob_valid <= 1;
                    retire_rob_id <= tmp_head;
                end else if (rob[tmp_head].misspredict) begin
                    flush <= 1'b1; // comment
                    prev_ready = 0;
                    new_pc <= rob[tmp_head].new_pc;
                end
                if (rob[tmp_head].dst_valid) begin // not an else statement because misspredicted jumps can set regs
                    f_list_freed[rob[tmp_head].pp_dst_reg] <= 1'b1;
                    a_reg_state[rob[tmp_head].a_dst_reg] <= rob[tmp_head].p_dst_reg;
                end
                tmp_head = tmp_head + 1;
            end else 
                prev_ready = 0;
        end
        head <= tmp_head;
    end
end

endmodule