/*  Copyright Bluespec Inc. 2005-2008  */

package Testbench;

import Functions :: *;

module mkTestbench ();  // It has no interface and no arguments

  // ----------------
  // STATE (sub-modules)

  // A counter for feeding stage0
  Reg#(Int#(83)) counter <- mkReg(0);    // reset value 0
  
  // Instantiate three registers: stage0, stage1 and stage2.
  // We use the library interface Reg and the library module mkReg.
  // If we wanted an asynch-reset register, we'd use mkRegA instead.

  Reg#(Int#(83)) stage0 <- mkReg(0);    // reset value 0
  Reg#(Int#(83)) stage1 <- mkReg(0);    // reset value 0
  Reg#(Int#(83)) stage2 <- mkReg(0);    // reset value 0


  // ----------------
  // RULES (behavior)

  // This rule fires on each cycle because it has no conditions
  // and no conflicts

  rule stimuli;
    counter <= counter + 1;
  endrule

  // This rule fires on each cycle because it has no conditions
  // and no conflicts.
  // The rule body defines the operations between the shifter registers.

  rule shift;               // Rule without conditions
    stage0 <= counter;
    stage1 <= increment(stage0);      // Note the use of <= due to concurrent operations
    stage2 <= decrement(stage1);
  endrule

  // This rule fires on each cycle because it has no conditions
  // and no conflicts.
  // It just displays the shifter register contents, in decimal (%0d) format

  rule show;
    $display("  stage0: %0d, stage1: %0d, stage2: %0d", stage0, stage1, stage2);
  endrule
 
  // This rule is added to limit the length of the simulation
  rule stop (counter == 100);
    $finish(0);
  endrule: stop

  // ----------------
  // INTERFACE

    /* None */

endmodule: mkTestbench

endpackage
