# General structure
typedef struct packed {
	logic [3:0]  op; // specifies what operation to perform
	logic [2:0]  op_type; // specifies what logical hardware resource to delegate it to
	logic [5:0]  src1_reg; // index of src1's reg
	logic        src1_valid; // prevents non-used registers from being renamed
	logic [5:0]  src2_reg;
	logic        src2_valid;
	logic [5:0]  dst_reg; // same as above for destination
	logic        dst_valid;
	logic [19:0] immediate; // immediate/offset, J/U type use 20 bits
	logic        pred_taken; // for later use, currently always not taken to simplify fetching
	logic        faulted;
	logic [31:0] pc; // needed for jmps/interupts/calls/etc
	logic [3:0]  rob_id; // lets ROB know what entry it is
} uop_t;

# OP types
`000` - ALU
    `0000` - add
    `1000` - sub
    `0100` - xor
    `0110` - or
    `0111` - and
    `0001` - shl
    `0101` - shr
    `1101` - shr arith (msb extends)
    `0010` - set less than (slt)
    `0011` - set less than unsigned (sltu) (zero extends)
`001` - Memory read
    `0000` - load byte
    `0001` - load half
    `0010` - load word
    `0100` - load byte unsigned (zero extends)
    `0101` - load half unsigned (zero extends)
`010` - jmp+reg
    `0000` - jump and link reg
`011` - Memory write
    `0000` - store byte
    `0001` - store half
    `0010` - store word
`100` - branch type
    `0000` - branch if equal 
    `0001` - branch if not equal
    `0100` - branch if less than 
    `0101` - branch if equal or greater 
    `0110` - branch if less than unsigned 
    `0111` - branch if equal or greater unsigned 
`101` - jmp+pc+imm
    jumps to pc+imm
`110` - load
    load upper immediate (dest = immediate << 12)
`111` - load+pc
    add upper imm to PC (dest = pc + (im << 12))