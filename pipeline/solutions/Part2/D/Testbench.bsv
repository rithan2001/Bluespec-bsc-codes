/*  Copyright Bluespec Inc. 2005-2008  */

package Testbench;

import FIFO      :: *;    // import the FIFO package from the BSV library

import Functions :: *;

module mkTestbench ();  // It has no interface and no arguments

  // ----------------
  // STATE (sub-modules)

  // A counter for feeding stage0
  Reg#(Int#(16)) counter <- mkReg(0);    // reset value 0
  
  // Instantiate three FIFOs: stage0, stage1 and stage2.
  // We use the library interface FIFO and the library module mkSizedFIFO.

  FIFO#(Int#(16)) stage0 <- mkSizedFIFO(4);    // depth 4 FIFO
  FIFO#(Int#(16)) stage1 <- mkSizedFIFO(4);
  FIFO#(Int#(16)) stage2 <- mkSizedFIFO(4);


  // ----------------
  // RULES (behavior)

  // This rule fires on each cycle because it has no conditions
  // and no conflicts

  rule stimuli;
    counter <= counter + 1;
  endrule

  // This rule defines the operations between the shifter FIFOs.

  rule shift;
    stage0.enq (counter);
    stage1.enq (increment (stage0.first, 5)); stage0.deq;
    stage2.enq (decrement (stage1.first, 3)); stage1.deq;
    stage2.deq;
  endrule

  // This rule displays the shifter FIFO contents, in decimal (%0d) format

  rule show;
    $display("  stage0: %0d, stage1: %0d, stage2: %0d", stage0.first, stage1.first, stage2.first);
  endrule
 
  // This rule just limits the length of the simulation
  rule stop (counter == 100);
    $finish(0);
  endrule: stop

  // ----------------
  // INTERFACE

    /* None */

endmodule: mkTestbench

endpackage
