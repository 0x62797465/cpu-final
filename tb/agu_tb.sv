// Since the AGU is the most complex component so far, this testbench will 
// use randomized testing. 
`include "../src/types.svh"

module agu_tb;
    reg clk = 0;
    reg CPU_RESET_n = 0;
    uop_t uop = '0;
    reg valid = 0;
    reg [31:0] src_1 = '0;
    reg [31:0] src_2 = '0;
    reg [3:0]  retire_rob_id = '0;
    reg retire_rob_valid = 0;

    post_ex_uop_t uop_out;
    reg agu_ready;

    always #10 clk = ~clk;

    reg prev_mem_valid = 0;
    reg [3:0] rob_head = '0;
    reg [3:0] rob_tail = '0;
    reg [1:0] [15:0] rob = '0;
    reg [15:0] [31:0] pregs_tb = '0;
    reg [15:0] [31:0] pregs_internal = '0; // Amount of pregs is not relevant to AGU
    reg [32767:0] [7:0] internal_mem = '0;
    reg [31:0] addr = '0;

    agu dut (.clk(clk), .CPU_RESET_n(CPU_RESET_n), .uop(uop), .valid(valid), 
        .src_1(src_1), .src_2(src_2), .retire_rob_id(retire_rob_id), 
        .retire_rob_valid(retire_rob_valid), .uop_out(uop_out), 
        .agu_ready(agu_ready));
    
    task reset_unit();
        CPU_RESET_n = 0;
        @(posedge clk);
        for (int i = 0; i < 8192; i++) begin
            dut.mem[i] = {32{1'b0}}; 
        end
        for (int i = 0; i < 8192*4; i++) begin
            internal_mem[i] = 8'b00000000; 
        end
        internal_mem = '0;
        CPU_RESET_n = 1;
    endtask

    task randomized_testing();
        // Only should be valid accesses,
        // delay between write and ROB
        // retire will be randomly (0-32)
        // (arbitrary) delayed. Likewise,
        // chances of a read/write happening
        // will be random (around 50% of the
        // time). At the end of every 100 
        // or so cycles, we will commit 
        // everything and check register
        // states and the memory state.
        for (int i = 0; i < 8192*4; i++) begin
            internal_mem[i] = 8'b00000000; 
        end
        rob_head = '0;
        rob_tail = '0;
        rob = '0;
        pregs_internal = '0;
        pregs_tb = '0;
        addr = '0;
        for (int a = 0; a < 1000000; a++) begin
            @(negedge clk);
            if (rob_tail == rob_head) begin
                if (prev_mem_valid) begin
                    for (int i = 0; i < 8192; i++) begin
                        assert (dut.mem[i] == {internal_mem[i*4+3],
                            internal_mem[i*4+2], internal_mem[i*4+1],
                            internal_mem[i*4]})
                            else $fatal("Memory missmatch %d %d %h %h\n", i<<2, a, dut.mem[i],
                                {internal_mem[i*4+3], internal_mem[i*4+2], internal_mem[i*4+1],
                                internal_mem[i*4]});
                            
                        assert (pregs_internal == pregs_tb)
                            else $fatal("physical register mismatch (good luck) %h %h\n", pregs_internal, pregs_tb);
                    end
                end
                prev_mem_valid = 1;
            end else 
                prev_mem_valid = 0;
            retire_rob_valid = 0;
            if ((rob[0][rob_tail] == 1) && $urandom_range(1, 0)) begin
                if ((rob_tail) != rob_head) begin
                    if (rob[1][rob_tail] == 1) begin
                        retire_rob_valid = 1;
                        retire_rob_id = rob_tail;
                    end
                    rob_tail = rob_tail + 1;
                end
            end
            if (uop_out.valid) begin
                /*assert (uop_out.faulted == 0 &&
                        uop_out.was_jmp == 0 &&
                        uop_out.was_mem &&
                        uop_out.dst_valid == uop.dst_valid &&
                        uop_out.dst_reg == uop.dst_reg &&
                        uop_out.rob_id == uop.rob_id &&
                        uop_out.valid)
                    else $fatal("impossible state reached; compare uops\ninput: %h output: %h\n", 
                        uop, uop_out);*/ // useless due to cycle delay bench
                rob[0][uop_out.rob_id] = 1;
                if (uop_out.dst_valid) begin
                    pregs_internal[uop_out.dst_reg] ^= uop_out.dst_val;
                end
            end
            if (!valid && agu_ready && $urandom_range(1, 0) && ((rob_head+1) != rob_tail)) begin
                addr[14:0] = $urandom_range(32767, 0);
                uop.rob_id = rob_head;
                rob[0][rob_head] = 0;
                rob_head = rob_head + 1;
                if ($urandom_range(1, 0)) begin // write
                    logic [3:0] mask;
                    rob[1][uop.rob_id] = 1;
                    uop.op_type = 3'b011;
                    if ($urandom_range(2, 0)) begin
                        mask = 4'b1111;
                        uop.op = 4'b0010; // force alignment
                        addr = {addr>>2, 2'b00}; // equiv to (x // 4) * 4
                    end else if ($urandom_range(1, 0)) begin
                        mask = 4'b0011;
                        uop.op = 4'b0001;
                        addr = {addr>>1, 1'b0};
                    end else begin 
                        mask = 4'b0001;
                        uop.op = 4'b0000;
                    end
                    // stores use src1 and an immediate
                    uop.src1_valid = 1;
                    // so the immediate is 12 signed bits, meaning +-2047
                    uop.immediate[11:0] = $urandom();
                    src_1 = {addr-{{20{uop.immediate[11]}}, uop.immediate[11:0]}};
                    // if src_1 becomes negative it *should* be fine
                    src_2 = $urandom();
                    uop.src2_valid = 1;
                    internal_mem[addr[14:0]+3] = mask[3] ? src_2[31:24] : internal_mem[addr[14:0]+3];
                    internal_mem[addr[14:0]+2] = mask[2] ? src_2[23:16] : internal_mem[addr[14:0]+2];
                    internal_mem[addr[14:0]+1] = mask[1] ? src_2[15:8 ] : internal_mem[addr[14:0]+1];
                    internal_mem[addr[14:0]+0] = mask[0] ? src_2[7:0  ] : internal_mem[addr[14:0]+0];
                end else begin
                    logic [3:0] mask;
                    logic [31:0] tmp_reg;
                    logic is_signed;
                    rob[1][uop.rob_id] = 0;
                    tmp_reg = '0;
                    is_signed = 1;
                    uop.op_type = 3'b001;
                    case ($urandom_range(4, 0))
                        4'b0: begin
                                mask = 4'b1111;
                                uop.op = 4'b0010;
                                addr = {addr>>2, 2'b00}; 
                            end
                        4'd1: begin
                                mask = 4'b0011;
                                uop.op = 4'b0001;
                                addr = {addr>>1, 1'b0};
                            end
                        4'd2: begin
                                mask = 4'b0001;
                                uop.op = 4'b0000;
                            end
                        4'd3: begin
                                is_signed = 0;
                                mask = 4'b0001;
                                uop.op = 4'b0100;
                                addr = addr;
                            end
                        4'd4: begin
                                is_signed = 0;
                                mask = 4'b0011;
                                uop.op = 4'b0101;
                                addr = {addr>>1, 1'b0};
                            end
                    endcase
                    // stores use src1 and an immediate
                    uop.src1_valid = 1;
                    // so the immediate is 12 signed bits, meaning +-2047
                    uop.immediate[11:0] = $urandom_range(4095, 0);
                    src_1 = {addr-{{20{uop.immediate[11]}}, uop.immediate[11:0]}};;
                    // if src_1 becomes negative it *should* be fine
                    uop.dst_valid = 1;
                    uop.dst_reg = $urandom_range(0,15);
                    uop.src2_valid = 0;
                    tmp_reg = {
                        {mask[3] ? internal_mem[addr+3] : 8'b0},
                        {mask[2] ? internal_mem[addr+2] : 8'b0},
                        {mask[1] ? internal_mem[addr+1] : 8'b0},
                        {mask[0] ? internal_mem[addr+0] : 8'b0}
                    };
                    if (is_signed) begin
                        if (mask == 4'b0011)
                            tmp_reg = {{16{tmp_reg[15]}}, tmp_reg[15:0]};
                        if (mask == 4'b0001)
                            tmp_reg = {{24{tmp_reg[7]}}, tmp_reg[7:0]};
                    end
                    pregs_tb[uop.dst_reg] ^= tmp_reg; // so inconsistencies cascade
                    // xor so inconsistencies cascade
                end
                valid = 1;
            end else 
                valid = 0;
        end
    endtask

    initial begin
        reset_unit();
        randomized_testing();
        $finish;
    end
endmodule