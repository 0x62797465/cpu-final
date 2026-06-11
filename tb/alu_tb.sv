`include "../src/types.svh"

module alu_tb;
    int fd;
    string line;

    reg clk   = '0;
    reg reset = '0;
    reg valid = '0;
    uop_t uop = '0;
    post_ex_uop_t uop_out = '0;
    reg [31:0] src_1 = '0;
    reg [31:0] src_2 = '0;
    reg [31:0] dst_exp = '0;

    always #10 clk = ~clk;
    
    alu dut (.clk(clk), .CPU_RESET_n(reset), .uop(uop), .valid(valid),
        .src_1(src_1), .src_2(src_2), .uop_out(uop_out));

    task reset_stage();
        uop = '0;
        reset = '0;
        @(posedge clk);
        reset = 1'b1;
    endtask

    task test_arithmatic();
        valid = 1;
        uop = '0;
        fd = $fopen("testcases/alu/arith_full.txt", "r");
        while ($fgets(line, fd)) begin
            $sscanf(line, "%b %b %h %b %h %b %h %h", uop.op_type, uop.op, 
                src_1, uop.src1_valid, src_2, uop.src2_valid,
                dst_exp, uop.immediate);
            @(posedge clk);
            #1
            assert (uop_out.dst_val == dst_exp)
                else $fatal("Destination wrong for %s\ngot: %h, expected: %h\n", line, uop_out.dst_val, dst_exp);
            assert (uop_out.faulted == 1'b0 && 
                    uop_out.rob_id == uop.rob_id &&
                    uop_out.dst_reg == uop.dst_reg &&
                    uop_out.was_jmp == 1'b0)
                else $fatal("Something about the uop changed which shouldn't have \noriginal :%b \nrecieved: %b\nline: %s\n", uop, uop_out, line);
        end
    endtask

    task test_none();
        valid = 0;
        @(posedge clk);
        #1
        assert (uop_out.valid == 1'b0)
            else 
                $fatal("ALU incorrectly marked output as valid!\n");
    endtask

    task test_load();
        valid = 1;
        uop = '0;
        uop.op_type = 3'b110;
        uop.immediate = 12'b111011101001;
        @(posedge clk);
        #1;
        assert (uop_out.dst_val == {12'b111011101001, {12{1'b0}}})
            else $fatal("Load result, %b, doesn't match expected, %b\n", uop_out.dst_val, {12'b111011101001, {12{1'b0}}});
        assert (uop_out.faulted == 1'b0 && 
                uop_out.rob_id == uop.rob_id &&
                uop_out.dst_reg == uop.dst_reg &&
                uop_out.was_jmp == 1'b0)
            else $fatal("Something about the uop changed which shouldn't have \noriginal :%b \nrecieved: %b\nline: %s\n", uop, uop_out, line);
        uop = '0;
        uop.op_type = 3'b111;
        uop.immediate = 12'b111011101001;
        uop.pc = $urandom();
        @(posedge clk);
        #1;
        assert (uop_out.dst_val == (uop.pc+{12'b111011101001, {12{1'b0}}}))
            else $fatal("Load result, %b, doesn't match expected, %b\n", uop_out.dst_val, {12'b111011101001, {12{1'b0}}});
        assert (uop_out.faulted == 1'b0 && 
                uop_out.rob_id == uop.rob_id &&
                uop_out.dst_reg == uop.dst_reg &&
                uop_out.was_jmp == 1'b0)
            else $fatal("Something about the uop changed which shouldn't have \noriginal :%b \nrecieved: %b\nline: %s\n", uop, uop_out, line);
        
    endtask

    task test_signed_add();
        valid = 1;
        uop = '0;
        uop.op_type = 3'b000;
        uop.op = 4'b0000;
        uop.immediate = -(12'b011011101001);
        uop.src1_valid = 1'b1;
        uop.src2_valid = 1'b0;
        src_1 = 32'h62d738f6; // who came up with these variable names? it's so bad
        @(posedge clk);
        #1;
        assert (uop_out.dst_val == (32'h62d738f6-32'b11011101001))
            else $fatal("addi result, %h, doesn't match expected, %h\n", uop_out.dst_val, (32'h62d738f6-32'b11011101001));
        assert (uop_out.faulted == 1'b0 && 
                uop_out.rob_id == uop.rob_id &&
                uop_out.dst_reg == uop.dst_reg &&
                uop_out.was_jmp == 1'b0)
            else $fatal("Something about the uop changed which shouldn't have \noriginal :%b \nrecieved: %b\nline: %s\n", uop, uop_out, line);
    endtask

    initial begin
        reset_stage();
        test_arithmatic();
        reset_stage();
        test_none();
        reset_stage();
        test_load();
        test_none();
        reset_stage();
        test_signed_add();
        $finish;
    end
    // immediate signed arith, load, load+pc, some conditional jumps, JAL, 
    // and no instruction
endmodule