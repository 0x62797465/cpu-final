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
Rewrite rename testbench