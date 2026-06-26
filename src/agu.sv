`include "types.svh"

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
    input            UART_RX,

    output var post_ex_uop_t uop_out,
    output reg       loaded_valid,
    output reg [3:0] [7:0] loaded_word, 
    output reg [3:0] [7:0] header,
    output reg       loading,
    output reg       agu_ready,
    output reg       UART_TX
);

typedef struct packed {
    logic [3:0]  rob_id;
    logic [31:0] data;
    logic [31:0] addr;
    logic [3:0]  mask; // 3 is word (32 bit), 2 is half (16 bit), 1 is byte (8 bit), 0 is invalid 
} SQ;

SQ [7:0] queue = '0;
reg [2:0] qhead;
reg [2:0] qtail;

wire [31:0] addr = {src_1+{{20{uop.immediate[11]}}, uop.immediate[11:0]}}; // immediate is sign extended
wire [1:0] offset = addr - {addr[31:2], 2'b00}; // offset from 4 byte (cache aligned) block
reg [31:0] raw_mem_data = '0; 

reg lsq_miss = 0; // if data written doesn't cover the entire LSQ
reg [3:0] mask;
reg [3:0] mask_needed;
reg [31:0] data;

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
    mem.outdata_reg_b = "UNREGISTERED",
    mem.ram_block_type = "M10K";
`endif

reg prev_written;
reg [2:0] prev_written_id;

reg rc_done;

reg [1:0] [1:0] new_status;
reg [7:0] TXDATA;
reg [1:0] [7:0] RXDATA;
reg [1:0] [1:0] STATUS;

char_in char_in (
    .clk(clk),
    .CPU_RESET_n(CPU_RESET_n),
    .UART_RX(UART_RX),
    .rc_done(rc_done),
    .chr(RXDATA[1])
);

reg dat_out_ready;
reg out_ready;
reg prev_out_ready;
reg prev_rc_done;

char_out char_out (
    .chr_ready(dat_out_ready),
    .clk(clk),
    .CPU_RESET_n(CPU_RESET_n),
    .chr(TXDATA),
    .tm_ready(out_ready),
    .UART_TX(UART_TX)
);

reg [31:0] load_ptr;
reg header_loaded;
reg byte_written;
reg loading_done;
reg [1:0] load_word_ptr;

always @(posedge clk or negedge CPU_RESET_n) begin // Commit writes
    if (!CPU_RESET_n) begin
        load_ptr <= '0;
        loading_done <= 0;
        header_loaded <= 0;
        header <= '0;
        load_word_ptr <= '0;
        write_enable <= '0;
        qhead <= '0;
        prev_written <= '0;
        prev_written_id <= '0;
        loading <= 1;
        loaded_valid <= 0;
        loaded_word <= 0;
        byte_written <= 1;
        new_status[1] <= 2'b00;
        prev_rc_done <= 1'b1;
        prev_out_ready <= 1'b1;
        STATUS[1] <= 2'b01;
    end else begin if (loading) begin
        logic [3:0] [7:0] tmp_word;
        tmp_word = loaded_word; 
        write_enable <= '0;
        if (loaded_valid) begin
            loaded_valid <= '0;
            loaded_word <= '0;
        end
        if (loading_done)
            loading <= 1'b0;
        else if (!rc_done)
            byte_written <= 0;
        else if (rc_done && !byte_written) begin
            if (!header_loaded) begin
                byte_written <= 1;
                header[load_word_ptr] <= RXDATA[1];
                load_word_ptr <= load_word_ptr + 1;
                if (load_word_ptr == 2'b11)
                    header_loaded <= 1'b1;
            end else begin
                byte_written <= 1;
                tmp_word[load_word_ptr] = RXDATA[1];
                loaded_word[load_word_ptr] <= RXDATA[1];
                load_word_ptr <= load_word_ptr + 1;
                header <= header - 1;
                if (load_word_ptr == 2'b11 || !(header-1)) begin
                    loaded_valid <= 1'b1;
                    write_enable <= '1;
                    queue_data <= tmp_word;
                    queue_mask <= 4'b1111;
                    load_ptr <= load_ptr + 1;
                    queue_addr <= load_ptr;
                end
                if (header == 1) begin
                    loading_done <= 1'b1;
                end
            end
        end    
    end else begin
        logic [2:0] t_qhead;
        t_qhead = qhead;
        prev_rc_done <= rc_done;
        prev_out_ready <= out_ready;
        dat_out_ready <= '0;
        if (!STATUS[1][1] && (!prev_rc_done) && (rc_done)) begin
            new_status[1][1] <= !new_status[1][1];
            STATUS[1][1] <= 1'b1;
            RXDATA[0] <= RXDATA[1];
        end
        if (!STATUS[1][0] && (!prev_out_ready) && (out_ready)) begin
            new_status[1][0] <= !new_status[1][0];
            STATUS[1][0] <= 1'b1;
        end
        if (prev_written) begin
            t_qhead = t_qhead + 1;
            qhead <= qhead + 1;
            prev_written <= 1'b0;
        end
        write_enable <= 0;
        queue_mask <= '0;
        queue_addr <= '0;
        queue_data <= '0;
        if ((queue[t_qhead].addr == 32'h10000000 ||
                queue[t_qhead].addr == 32'h10000004) && retire_rob_valid) begin
            prev_written <= 1'b1;
            case (queue[t_qhead].addr) 
                32'h10000000 : begin
                    TXDATA <= queue[t_qhead].data;
                    dat_out_ready <= 1'b1;
                    STATUS[1][0] <= 1'b0;
                    new_status[1][0] <= !new_status[1][0];
                end
                32'h10000004 : begin
                    STATUS[1][1] <= 1'b0;
                    new_status[1][1] <= !new_status[1][1];
                end
            endcase
        end else if (retire_rob_valid) begin
            write_enable <= 1;
            queue_mask <= queue[t_qhead].mask;
            queue_addr <= queue[t_qhead].addr>>2;
            queue_data <= queue[t_qhead].data;
            prev_written <= 1'b1;     
        end
    end
    if (flush) begin
        prev_rc_done <= rc_done;
        prev_out_ready <= out_ready;
        dat_out_ready <= '0;
        if (!STATUS[1][1] && (!prev_rc_done) && (rc_done)) begin
            new_status[1][1] <= !new_status[1][1];
            STATUS[1][1] <= 1'b1;
            RXDATA[0] <= RXDATA[1];
        end
        if (!STATUS[1][0] && (!prev_out_ready) && (out_ready)) begin
            new_status[1][0] <= !new_status[1][0];
            STATUS[1][0] <= 1'b1;
        end
        qhead <= '0;
        prev_written <= '0;
        prev_written_id <= '0;
    end
    end
end

logic [6:0] f_count;
logic n_stall;

assign n_stall = ( (qhead-qtail) > 2 || (qhead==qtail)); // prevents LSQ overflow

always @(posedge clk or negedge CPU_RESET_n) begin // unified to prevent multiple drivers
    if (!CPU_RESET_n) begin
        queue = '0;
        agu_ready <= 1;
        lsq_miss <= 0;
        qtail <= '0;
        uop_out <= '0;
        STATUS[0] <= 2'b01;
        new_status[0] <= 2'b00; 
    end else if (flush) begin
        new_status[0] <= new_status[1];
        STATUS[0] <= STATUS[1];
        queue = '0;
        qtail <= '0;
        agu_ready <= 1;
        lsq_miss <= 0;
        uop_out <= '0; 
    end else if ((addr == 32'h10000000 || addr == 32'h10000004 
            || addr == 32'h10000008) && valid && agu_ready && !lsq_miss) begin
        // If the address is one of 3 designated UART addresses...
        // If it's write we write to sp eculative transmittion buffer,
        // on retire we move the speculative transmittion buffer into 
        // the real one and copy over the speculative state.
        logic [1:0] status; 
        agu_ready <= n_stall;
        status = STATUS[0];
        if (new_status[1][1] != new_status[0][1]) begin
            STATUS[0][1] <= STATUS[1][1];
            new_status[0][1] <= new_status[1][1];
            status[1] = STATUS[1][1];
        end if (new_status[1][0] != new_status[0][0]) begin
            STATUS[0][0] <= STATUS[1][0];
            new_status[0][0] <= new_status[1][0];
            status[0] = STATUS[1][0];
        end

        uop_out.was_uart <= 1'b1;
        uop_out.valid <= 1'b1;
        uop_out.was_jmp <= 1'b0;
        uop_out.faulted <= 1'b0;
        uop_out.was_mem <= 1'b1;
        uop_out.unconditional_jmp <= 1'b0;
        uop_out.dst_reg <= uop.dst_reg;
        uop_out.dst_valid <= uop.dst_valid;
        uop_out.rob_id <= uop.rob_id;
        queue[qtail].rob_id <= uop.rob_id;
        queue[qtail].data <= src_2;
        queue[qtail].addr <= {addr>>2, 2'b00};
        if (addr == 32'h10000000) begin
            qtail <= qtail + 1;
            STATUS[0][0] <= 1'b0;
        end else if (addr == 32'h10000004) begin
            qtail <= qtail + 1;
            case (uop.op)
                4'b0000: // load byte 
                    uop_out.dst_val <= {{25{RXDATA[0][7]}}, RXDATA[0][6:0]};
                4'b0001: // load half 
                    uop_out.dst_val <= {{24{1'b0}}, RXDATA[0][6:0]};
                4'b0010: // load word
                    uop_out.dst_val <= {{24{1'b0}}, RXDATA[0][6:0]};
                4'b0100: // load byte unsigned (zero extends)
                    uop_out.dst_val <= {{24{1'b0}}, RXDATA[0][7:0]};
                4'b0101: // load half unsigned (zero extends)
                    uop_out.dst_val <= {{24{1'b0}}, RXDATA[0][6:0]};              
                default:
                    uop_out.faulted <= 1'b1;
            endcase
            STATUS[0][1] <= 1'b0;
        end else if (addr == 32'h10000008) begin
            uop_out.was_uart <= 1'b0;
            uop_out.dst_val <= {{30{1'b0}}, status};
        end
    end else begin // store
        uop_out.was_uart <= 1'b0;
        if ((uop.op_type == 3'b011) && valid && agu_ready && !lsq_miss) begin
            logic [3:0] mask_ins;
            logic [3:0] mask_needed_ins;
            logic [31:0] data_ins;
            logic [31:0] all_dat;
            logic [31:0] src_2_shifted;
            data_ins = '0;
            mask_needed_ins = '0;
            mask_ins = '0;
            uop_out.valid <= 1'b0;
            agu_ready <= n_stall;
            lsq_miss <= 1'b0;
            uop_out.faulted <= 1'b0;
            if (qhead != qtail) begin 
                for (int i = 0; i < 8; i++) begin
                    logic [2:0] q_ptr;
                    q_ptr = qhead+i[2:0];
                    if (q_ptr == qtail)
                        break;
                    if ((queue[q_ptr].addr>>2 == addr>>2) && (q_ptr != qtail)) begin
                        mask_ins = queue[q_ptr].mask;
                        data_ins = queue[q_ptr].data;
                    end
                end
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
            queue[qtail].rob_id <= uop.rob_id;
            queue[qtail].data <= all_dat;
            queue[qtail].addr <= {addr>>2, 2'b00};
            queue[qtail].mask <= mask_needed_ins|mask_ins;
            qtail <= qtail + 1;
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
            uop_out.was_uart <= 1'b0;
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
            uop_out.was_uart <= 1'b0;
            uop_out.valid <= 1'b0;
            agu_ready <= 1'b0;
            lsq_miss <= 1'b0;
            uop_out.faulted <= 1'b0;
            mask = 1'b0;
            for (int i = 0; i < 8; i++) begin
                logic [2:0] q_ptr;
                q_ptr = qhead+i[2:0];
                if (q_ptr == qtail)
                    break;
                if ((queue[q_ptr].addr>>2 == addr>>2) && (q_ptr != qtail)) begin
                    mask = queue[q_ptr].mask;
                    data = queue[q_ptr].data>>(offset*8);
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
