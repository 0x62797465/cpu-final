`include "types.svh"

// This module reads from mem/SQ into registers, additonally
// it writes into memory with an ROB id that will be specified 
// by the retire unit. Some notes: the max width of a read 
// is 32 bits, therefore the word width is 32 bits. But since
// there are partial write, we have to do some tricks in 
// order for 16 bit writes to work. 

module agu (
    input            clk,
    input            CPU_RESET_n,
    input var uop_t  uop,
    input            valid,
    input reg [31:0] src_1,
    input reg [31:0] src_2,
    input var [3:0]  retire_rob_id,
    input var        retire_rob_valid [1:0],
    input var [3:0]  rob_head,

    output var post_ex_uop_t uop_out,
    output reg       agu_ready
);

(* ram_style = "block" *) reg [31:0] mem [8191:0]; // 32kb of r/w mem

typedef struct packed {
    logic [3:0]  age; // rob_id and head trick unreliable; this trick should not overflow because the add happens every insertion, which means the oldest instruction is at most 7(?)
    logic [3:0]  rob_id;
    logic [31:0] data;
    logic [31:0] addr;
    logic [3:0]  mask; // 3 is word (32 bit), 2 is half (16 bit), 1 is byte (8 bit), 0 is invalid 
} SQ;

reg [7:0] f_list = '0;
SQ [7:0] queue = '0;
wire [31:0] addr = {src_1+{{20{uop.immediate[11]}}, uop.immediate[11:0]}};
wire [1:0] offset = addr - {addr[31:2], 2'b00};
/*
            for (int i = 0; i < 8; i++) begin
                queue[i].age <= f_list[i] ? 4'b0 : queue[i].age + 1; // should never overflow in theory 
            end
*/
reg [31:0] raw_mem_data = '0;

reg lsq_miss = 0;
reg [3:0] mask;
reg [3:0] mask_needed;
reg [31:0] data;
//always @(posedge clk or negedge )

always @(posedge clk) begin
	raw_mem_data <= mem[addr>>2]; // 32 bit word since true dual port limits us to 16 bits if we do two 8 bit reads
end

always @(posedge clk) begin
    logic [31:0] all_dat; // cause I'm all dat (mic drop!)
    all_dat = 0;
    if (lsq_miss) begin
        all_dat <= {{mask[3] ? {raw_mem_data>>(offset*8)}[31:24] : 8'b0},
                    {mask[2] ? {raw_mem_data>>(offset*8)}[23:16] : 8'b0},
                    {mask[1] ? {raw_mem_data>>(offset*8)}[15:8]  : 8'b0},
                    {mask[0] ? {raw_mem_data>>(offset*8)}[7:0]   : 8'b0}}; 
        case (uop.op)
            4'b0000: // load byte 
                uop_out.dst_val <= {{25{data[7]}}, all_dat[6:0]};
            4'b0001: // load half 
                uop_out.dst_val <= {{25{data[15]}}, all_dat[14:0]};
            4'b0010: // load word
                uop_out.dst_val <= all_dat;
            4'b0100: // load byte unsigned (zero extends)
                uop_out.dst_val <= {{24{1'b0}}, all_dat[7:0]};
            4'b0101: // load half unsigned (zero extends)
                uop_out.dst_val <= {{16{1'b0}}, all_dat[15:0]};                    
            default:
                uop_out.faulted <= 1'b1;
        endcase
        agu_ready <= 1'b1;
        uop_out.valid <= 1'b1;
        uop_out.was_jmp <= 1'b0;
	    uop_out.was_mem <= 1'b1;
        uop_out.unconditional_jmp <= 1'b0;
	    uop_out.dst_reg <= uop.dst_reg;
        uop_out.dst_valid <= 1'b1;
	    uop_out.rob_id <= uop.rob_id;
        lsq_miss <= 1'b0;
    end
end

always @(posedge clk or negedge CPU_RESET_n) begin // mem read
    if (!CPU_RESET_n) begin
        // todo
    end else if (valid && agu_ready && !lsq_miss) begin
        logic [5:0] best_age;
        uop_out.valid <= 1'b0;
        best_age = 5'b11111;
        agu_ready <= 1'b0;
        lsq_miss <= 1'b0;
        uop_out.faulted <= 1'b0;
        if (uop.op_type == 3'b001) begin
            mask = 1'b0;
            // Initially, this was just going to be oldest write to same address applied first
            // BUT there can be writes not alligned with this one. Normally, this would be fine
            // just apply all the writes. But since the writes have to be in order, we would
            // need to sort by age, then apply all matching writes. This does not work due to timing.
            // Instead, we are going to apply the oldest matching write, and during insertion
            // into the queue, we will use the oldest writes in order to make this write. But
            // this introduces a new problem: our writes will all have to be 32 bit aligned
            // and can write to any bytes because writes stack on top of each other in 
            // the LSQ. You may be asking: what about missprediction? It should work, probably. 
            for (int i = 0; i < 8; i++) begin
                if (!(f_list[i]) && (queue[i].addr<<2 == addr<<2) && (queue[i].age <= best_age)) begin
                    mask = queue[i].mask;
                    best_age = queue[i].age;
                    data = queue[i].data>>(offset*8);
                end
            end
            case (uop.op)
                4'b0000, 4'b0100: // load byte // load byte unsigned (zero extends)
                    mask_needed = 4'b0001<<offset; // mask is always 32 bit aligned, this is just adapting to the required offset
                4'b0001, 4'b0101: // load half // load half unsigned (zero extends)
                    mask_needed = 4'b0011<<offset;
                4'b0010: // load word
                    mask_needed = offset ? 4'b0000 : 4'b1111; // manually induce a fault; cause missaligned
                default:
                    uop_out.faulted <= 1'b1;
            endcase
            if (!mask_needed)
                uop_out.faulted <= 1'b1; // our mem line size is 4 bytes, a bit smaller than the standard 64 byte lines
            if ((mask_needed & mask) == mask_needed) begin // if all mask_needed bits are met
                agu_ready <= 1'b1;
                uop_out.valid <= 1'b1;
                uop_out.was_jmp <= 1'b0;
	            uop_out.was_mem <= 1'b1;
                uop_out.unconditional_jmp <= 1'b0;
	            uop_out.dst_reg <= uop.dst_reg;
                uop_out.dst_valid <= 1'b1;
	            uop_out.rob_id <= uop.rob_id;
                case (uop.op)
                    4'b0000: // load byte 
                        uop_out.dst_val <= {{25{data[7]}}, data[6:0]};
                    4'b0001: // load half 
                        uop_out.dst_val <= {{25{data[15]}}, data[14:0]};
                    4'b0010: // load word
                        uop_out.dst_val <= data;
                    4'b0100: // load byte unsigned (zero extends)
                        uop_out.dst_val <= {{24{1'b0}}, data[7:0]};
                    4'b0101: // load half unsigned (zero extends)
                        uop_out.dst_val <= {{16{1'b0}}, data[15:0]};                    
                    default:
                        uop_out.faulted <= 1'b1;
                endcase
            end else
                lsq_miss <= 1'b1; 
        end
    end
end

endmodule