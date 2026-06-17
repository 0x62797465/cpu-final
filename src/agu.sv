`include "types.svh"

// This module reads from mem/SQ into registers, additonally
// it writes into memory with an ROB id that will be specified 
// by the retire unit. Some notes: the max width of a read 
// is 32 bits, therefore the word width is 32 bits. But since
// there are partial writes, we have to do some tricks in 
// order for 16 bit/8 bit writes to work. 

// This whole unit is messed up. The standard cache line is
// 64 bytes, ours is 4 bytes due to BRAM restrictions, but 
// true dual port can only do 4 bytes max read/write per 
// cycle. But since each block is about 10kb of data the 
// hope is that synthesizer will split our 32kb block
// in such a way that we are allowed a bandwidth of 
// 3*4 bytes instead of just 4 bytes, which would allow
// for simutaniolus reads/writes of 4 bytes. 

// Writing this after the fact, the read is as follows:
// We simutaniosly issue a read to BRAM and check if 
// the data we need for the read is in the LSQ, if
// there is data in the LSQ that matters to us, we 
// add a mask, but if it doesn't cover the entire thing
// we go to the "LSQ missed" logic. During the next <- this should be extendable to other memory layers
// cycle, in which the read should have completed
// we apply the mask onto the read data, interpret
// the instruction to do propper sign extensions and 
// truncating, then mark the uop as ready and pass it
// down to wb.
// For write:
// We first look for any data in the LSQ that writes
// to the same aligned address, because the newest 
// write has to reflect what the written state should
// be so that when read reads from the LSQ it's 
// completely accurate and doesn't require more than
// O(n) time to find the write needed to apply. 
// Otherwise we would be sorting by age then applying
// writes one by one (or similar.) After obtaining 
// data for a completely valid write, we then allocate
// a free list entry and write to the queue. We also
// "age" all entries by one.
// For commit:
// Simply look for the rob id, when found we commit 
// the mask respecting write to BRAM and free the 
// f_list entry. This works because the window
// between reading the mask and the mask being 
// freed is not large enough for another mask
// to overwrite it, although we should extend this
// to store temporary variables in the future 
// if we do decide to use variable cycle memory. 

module agu (
    input            clk,
    input            CPU_RESET_n,
    input var uop_t  uop,
    input            valid,
    input reg [31:0] src_1,
    input reg [31:0] src_2,
    input var [3:0]  retire_rob_id,
    input var        retire_rob_valid,
    input            flush,

    output var post_ex_uop_t uop_out,
    output reg       agu_ready
);

typedef struct packed {
    logic [3:0]  age; // rob_id and head trick unreliable; this trick should not overflow because the add happens every insertion, which means the oldest instruction is at most 7(?)
    logic [3:0]  rob_id;
    logic [31:0] data;
    logic [31:0] addr;
    logic [3:0]  mask; // 3 is word (32 bit), 2 is half (16 bit), 1 is byte (8 bit), 0 is invalid 
} SQ;

reg [7:0] f_list_allocated = '0;
reg [7:0] f_list_freed = '0;
reg [7:0] f_list = '1;
SQ [7:0] queue = '0;

wire [31:0] addr = {src_1+{{20{uop.immediate[11]}}, uop.immediate[11:0]}}; // immediate is sign extended
wire [1:0] offset = addr - {addr[31:2], 2'b00}; // offset from 4 byte (cache aligned) block
reg [31:0] raw_mem_data = '0; 

reg lsq_miss = 0; // if data written doesn't cover the entire LSQ
reg [3:0] mask;
reg [3:0] mask_needed;
reg [31:0] data;

always @(posedge clk or negedge CPU_RESET_n) begin
    if (!CPU_RESET_n || flush) 
        f_list <= '1;
    else
        f_list <= f_list ^ f_list_freed ^ f_list_allocated;
end
reg [12:0] queue_addr;
reg [3:0] queue_mask;
reg [31:0] queue_data;
reg write_enable;

`ifdef sim
(* ramstyle = "M10K" *) reg [31:0] mem [8191:0]; // 32kb of r/w mem
// Quartus standard turns this into logic cells, so below is used
always @(posedge clk) begin
    if (write_enable) begin
        if (queue_mask[0]) mem[queue_addr][7:0]   <= queue_data[7:0];
        if (queue_mask[1]) mem[queue_addr][15:8]  <= queue_data[15:8];
        if (queue_mask[2]) mem[queue_addr][23:16] <= queue_data[23:16];
        if (queue_mask[3]) mem[queue_addr][31:24] <= queue_data[31:24];
    end
    raw_mem_data <= mem[addr[14:2]];
end
`else
altsyncram mem (
    .clock0(clk),
    .address_a(queue_addr),
    .data_a(queue_data),
    .wren_a(write_enable),
    .byteena_a(queue_mask),

    .address_b(addr[14:2]),
    .q_b(raw_mem_data)
);
defparam
    mem.operation_mode = "DUAL_PORT",
    mem.width_a = 32,
    mem.width_b = 32,
    mem.numwords_a = 8192,
    mem.numwords_b = 8192,
    mem.widthad_a = 13,
    mem.widthad_b = 13,
    mem.width_byteena_a = 4,
    mem.address_reg_b = "CLOCK0",
    mem.outdata_reg_b = "CLOCK0",
    mem.ram_block_type = "M10K";
`endif

always @(posedge clk or negedge CPU_RESET_n) begin // Commit writes
    if (!CPU_RESET_n || flush) begin 
        write_enable <= '0;
        f_list_freed <= '0;
    end else begin
        logic [7:0] f_list_tmp;
        write_enable <= 0;
        queue_mask <= '0;
        queue_addr <= '0;
        queue_data <= '0;
        f_list_tmp = f_list ^ f_list_freed ^ f_list_allocated;
        f_list_freed <= '0;
        if (retire_rob_valid) begin
            write_enable <= 1;
            for (int i = 0; i < 8; i++) begin
                if (queue[i].rob_id == retire_rob_id && !f_list_tmp[i]) begin
                    queue_mask <= queue[i].mask;
                    queue_addr <= queue[i].addr>>2;
                    queue_data <= queue[i].data;
                    f_list_freed[i] <= 1'b1;
                    break;
                end
            end
        end
    end
end

logic [6:0] f_count;
logic n_stall;
always_comb begin
    f_count = '0;
    for (int i = 0; i < 8; i++) begin
        f_count = f_count + f_list[i];
    end
end
assign n_stall = ( f_count > 2); // prevents LSQ overflow

always @(posedge clk or negedge CPU_RESET_n) begin // unified to prevent multiple drivers
    if (!CPU_RESET_n || flush) begin
        queue = '0;
        f_list_allocated <= 1'b0;
        agu_ready <= 1;
        lsq_miss <= 0;
        uop_out <= '0;
    end else begin // store
        logic [7:0] f_list_tmp;
        f_list_tmp = f_list ^ f_list_freed ^ f_list_allocated;
        f_list_allocated <= 1'b0;
        if ((uop.op_type == 3'b011) && valid && agu_ready && !lsq_miss) begin
            logic [3:0] mask_ins;
            logic [3:0] mask_needed_ins;
            logic [31:0] data_ins;
            logic [31:0] all_dat;
            logic [5:0] best_age;
            logic [31:0] src_2_shifted;
            data_ins = '0;
            mask_needed_ins = '0;
            mask_ins = '0;
            uop_out.valid <= 1'b0;
            best_age = 5'b11111;
            agu_ready <= n_stall;
            lsq_miss <= 1'b0;
            uop_out.faulted <= 1'b0;
            for (int i = 0; i < 8; i++) begin
                if (!(f_list_tmp[i]) && (queue[i].addr>>2 == addr>>2) && (queue[i].age <= best_age)) begin
                    mask_ins = queue[i].mask;
                    best_age = queue[i].age;
                    data_ins = queue[i].data;
                end
            end
            for (int i = 0; i < 8; i++) begin
                queue[i].age <= f_list_tmp[i] ? 4'b0 : queue[i].age + 1; // should never overflow in theory 
            end
            case (uop.op)
                4'b0000: // store byte
                    mask_needed_ins = 4'b0001<<offset; // mask is always 32 bit aligned, this is just adapting to the required offset
                4'b0001: // store half 
                    mask_needed_ins = 4'b0011<<offset;
                4'b0010: // store word
                    mask_needed_ins = offset ? 4'b0000 : 4'b1111; // manually induce a fault; cause missaligned
                default:
                    uop_out.faulted <= 1'b1;
            endcase
            
            if (!mask_needed_ins)
                uop_out.faulted <= 1'b1; 
            src_2_shifted = src_2<<(offset*8);
            all_dat = {{mask_needed_ins[3] ? src_2_shifted[31:24] : data_ins[31:24]},
                        {mask_needed_ins[2] ? src_2_shifted[23:16] : data_ins[23:16]},
                        {mask_needed_ins[1] ? src_2_shifted[15:8]  : data_ins[15:8] },
                        {mask_needed_ins[0] ? src_2_shifted[7:0]   : data_ins[7:0]  }};
            for (int i = 0; i < 8; i++) begin
                if (f_list_tmp[i]) begin
                    f_list_allocated[i] <= 1'b1;
                    queue[i].age <= 1'b0;
                    queue[i].rob_id <= uop.rob_id;
                    queue[i].data <= all_dat;
                    queue[i].addr <= {addr>>2, 2'b00};
                    queue[i].mask <= mask_needed_ins|mask_ins;
                    break;
                end
            end
            uop_out.valid <= 1'b1;
            uop_out.was_jmp <= 1'b0;
            uop_out.was_mem <= 1'b1;
            uop_out.unconditional_jmp <= 1'b0;
            uop_out.dst_reg <= uop.dst_reg;
            uop_out.dst_valid <= 1'b0;
            uop_out.rob_id <= uop.rob_id;
        end else if (lsq_miss) begin
            logic [31:0] all_dat; // cause I'm all dat (mic drop!)
            logic [31:0] raw_mem_shifted;
            logic [3:0] mask_shifted; // can't index bits of shifted regs for some reason?
            all_dat = 0;
            mask_shifted = mask>>offset;
            raw_mem_shifted = raw_mem_data>>(offset*8);
            all_dat =  {{mask_shifted[3] ? data[31:24] : raw_mem_shifted[31:24]},
                        {mask_shifted[2] ? data[23:16] : raw_mem_shifted[23:16]},
                        {mask_shifted[1] ? data[15:8]  : raw_mem_shifted[15:8]},
                        {mask_shifted[0] ? data[7:0]   : raw_mem_shifted[7:0]}}; 
            case (uop.op)
                4'b0000: // load byte 
                    uop_out.dst_val <= {{25{all_dat[7]}}, all_dat[6:0]};
                4'b0001: // load half 
                    uop_out.dst_val <= {{25{all_dat[15]}}, all_dat[14:0]};
                4'b0010: // load word
                    uop_out.dst_val <= all_dat;
                4'b0100: // load byte unsigned (zero extends)
                    uop_out.dst_val <= {{24{1'b0}}, all_dat[7:0]};
                4'b0101: // load half unsigned (zero extends)
                    uop_out.dst_val <= {{16{1'b0}}, all_dat[15:0]};                    
                default:
                    uop_out.faulted <= 1'b1;
            endcase
            agu_ready <= n_stall;
            uop_out.valid <= 1'b1;
            uop_out.was_jmp <= 1'b0;
            uop_out.was_mem <= 1'b1;
            uop_out.unconditional_jmp <= 1'b0;
            uop_out.dst_reg <= uop.dst_reg;
            uop_out.dst_valid <= 1'b1;
            uop_out.rob_id <= uop.rob_id;
            lsq_miss <= 1'b0;
        end else if ((uop.op_type == 3'b001) && valid && agu_ready && !lsq_miss) begin
            logic [5:0] best_age;
            uop_out.valid <= 1'b0;
            best_age = 5'b11111;
            agu_ready <= 1'b0;
            lsq_miss <= 1'b0;
            uop_out.faulted <= 1'b0;
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
                if (!(f_list_tmp[i]) && (queue[i].addr>>2 == addr>>2) && (queue[i].age <= best_age)) begin
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
                agu_ready <= n_stall;
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
        end else begin
            agu_ready <= n_stall;
            uop_out.valid <= 1'b0;
        end
    end
end

endmodule
