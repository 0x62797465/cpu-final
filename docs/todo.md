# Add stalling to rename
~~Rename must stall become issue's IQs can become full~~

# Add backwards stalling to issue
~~IQ can become full, we don't want uops to be overwritten. Then add to cpu.sv~~

# Create testbench for issue
~~Title~~

# Create execution units
ALU:
~~Add sign extensions to certain op-types during execution~~
~~Append some mispred bit so we can flush when it hits ROB; technically can be put in uop but we'd have to regenerated the testcases *again*~~ // should be delegated to the retire unit?
~~AGU:
Create LSQ; calculate memory read/write cyclic complexity; create caches seperate from icache~~

# ~~Testbench alu execute~~ (possibly create a C wrapper to be more rebust?)
~~Initially will be in pure systemverilog~~
~~Shouldn't be too hard to verify; just make sure uop being passed through remains as similar as it should be and the output values make sense~~
~~Need to test sign extensions in certain cases~~

~~# Testbench AGU~~

# Fix issuing for AGU
Hindsight is 20/20 but we are recieving mem ops in-order, we just need a circular
buffer in order to find the next needed uop (this also makes dual issue easier
if we chose to expand in the future).

# Add jmp unit during decode
To prevent missprediction penalty despite knowing the exact addr we need to go to;
the instruction still will have to go to execute in order to store the prev PC+4
to the destination register. Note that this may make one instruction invalid (plus 
whatever fetch fetches in the same cycle, and next cycle), so we will have to do
a lot of bubble insertion.

# Writeback
Flag certain registers as ready
Writeback

# Testbench wb
Should be simple

# ROB stuff
Write rob entry (coming from rename)
Handle mispredictions
Update internal free list based off rename allocations
Output freed freelist
Update head
Handle faults (should we make it trigger an LED on the FPGA?)
Handle a possible termination?

# Testbench
See if misprediction is triggered (testing will be left for entire CPU module testbench)
Make sure free list remains consistent (should be similar to the one in rename)
Make sure outputted freelist is correct
Make sure the head is consistent
Test if faulting is triggered correctly

# Misc
Add UART to a certain address and testbench

# Testbench CPU.sv with realish programs

# FPGA!

# Bonus
Make IP relative jumps execute immediatly after decoding (would run alongside of rename, execute would treat the instruction as a NOP)
Predict conditional jumps during the same stage (execute would serve to test if prediction was correct, ROB would make everything correct), additionally store a correct/not correct counter. 
Make the memory unit have a 1-cycle delay instead of 2 (LSQ stuff).
Real pages with actual permission bits
Make oob reads/writes actually fault