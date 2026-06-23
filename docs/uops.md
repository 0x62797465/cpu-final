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
    `0000` - load upper immediate (dest = immediate << 12)
    `0001` - add upper imm to PC (dest = pc + (im << 12))
`111` - variable cycle arithmatic
    `0000` - mul (low bits result, sign doesn't matter)
    `0001` - mulh (high bits, signed both)
    `0010` - mulsu (high bits, signed first unsigned second)
    `0011` - mulu (high, both unsigned)
    `0100` - div (signed)
    `0101` - divu (unsigned)
    `0110` - rem (signed)
    `0111` - remu (unsigned)
    
# Module "contracts" (unfinished)
## Fetch
On reset: the fetch address becomes zero.
On stall: the PC does not get updated, prev_fetch_addr remains as fetch_addr. 
Normally: PC gets incremented by 8 and places 64 bits from the 4 byte aligned mem into predecoded instructions.
In: stall signal, reset
Out: predecoded instr

## Decode
When the fetch address changes (or if it's zero) then we decode into the uop's pc,
op_type and op (as documented above), and do some basic checks to prevent some
invalid instructions. We also set wether or not registers are valid, we set immediates,
we set aregs for dsts and srcs. If the decode detects a non-moved fetch, it emits 
"nops" in the form of all-0 instructions.
In: PC at time of fetch, reset, predecoded instruction, stall
Out: prerename uops

## Rename
Given two regular instructions, we find the renamed source variables from the rename table
then apply them to the new uop. If there is a destination register then we look towards the
free list to find a free entry, then allocate it and we place it into the renamed uop.
We create an rob entry by marking as unfinished, speculative if it's a jump to reg or
conditonal branch (**note that this may be unused**), wether it's a store (**may also be
unused**), we set the previous physical register (so it can be freed upon retirement), 
the architectural destination register (so the architecural state matches upon mispred), 
physical destination register (to be marked as ready). The renamed uop is the same except
for the rob_id and the registers.
We also mark the rob entrys as valid.
The stall will be issued if there is not going to be enough uops. For every following cycle
we check the condition to determine wether or not to un-stall. Upon a low-stall, we will
set the backwards stall to low and then, next cycle, we process the data stored in the uops.
This data will be old, it would have been reflected in the unit state the cycle after we
set the stall (since the stall doesn't apply same-cycle). 
NOPs are specified by all-0 instructions and the ROB ent is not set. 

In: reset, stall, rob head, prerename uops, free free list (from retire)
Out: allocated free list (for retire), renamed uops, rob entries (for retire), 
tail (for retire), stall backwards

## 
