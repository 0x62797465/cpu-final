# Add stalling to rename
~~Rename must stall become issue's IQs can become full~~

# Add backwards stalling to issue
~~IQ can become full, we don't want uops to be overwritten. Then add to cpu.sv~~

# Create testbench for issue
Title

# Create execution units
ALU:
Add sign extensions to certain op-types during execution
Append some mispred bit so we can flush when it hits ROB; technically can be put in uop but we'd have to regenerated the testcases *again*
AGU:
Create LSQ; calculate memory read/write cyclic complexity; create caches seperate from icache

# Testbench execute (possibly create a C wrapper to be more rebust?)
Initially will be in pure systemverilog
Shouldn't be too hard to verify; just make sure uop being passed through remains as similar as it should be and the output values make sense
Need to test sign extensions in certain cases

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

# Bonus
Make IP relative jumps execute immediatly after decoding (would run alongside of rename, execute would treat the instruction as a NOP)
Predict conditional jumps during the same stage (execute would serve to test if prediction was correct, ROB would make everything correct), additionally store a correct/not correct counter. 
Make the memory unit have a 1-cycle delay instead of 2 (LSQ stuff).