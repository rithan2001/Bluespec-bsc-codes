/*  Copyright Bluespec Inc. 2005-2008  */

package Testbench;

// This funtion takes a Bit#(16), increments it and returns a Bit#(16)
// In this version we use the function's name as the value to be returned

function Bit#(16)  increment(Bit#(16) value);
   increment = value + 1;
endfunction

// This function takes a Bit#(16), decrements it and returns a Bit#(16)
// In this version we use a 'return' statement instead of the function's name

function Bit#(16)  decrement(Bit#(16) value);
  return value - 1;
endfunction


module mkTestbench ();  // It has no interface and no arguments

  // ----------------
  // STATE (sub-modules)

  // Instantiate three registers: stage0, stage1 and stage2.
  // We use the library interface Reg and the library module mkReg.
  // If we wanted an asynch-reset register, we'd use mkRegA instead.

  Reg#(Bit#(16)) stage0 <- mkReg(0);    // reset value 0
  Reg#(Bit#(16)) stage1 <- mkReg(0);    // reset value 0
  Reg#(Bit#(16)) stage2 <- mkReg(0);    // reset value 0

  Reg#(Bit#(16)) counter <- mkReg(0);

  // ----------------
  // RULES (behavior)

  // This rule fires on each cycle because it has no conditions
  // and no conflicts.
  // The rule body defines the operations between the shifter registers.

  rule shift;               // Rule without conditions
    stage1 <= increment(stage0);      // Note the use of <= due to concurrent operations
    stage2 <= decrement(stage1);
  endrule

  /* Note:
     Remember the register interface Reg#(type t), defines two methods
     _read() and _write().  We could also write the previous rule thus:

    rule shift;                           
      stage1._write(increment(stage0._read));
      stage2._write(decrement(stage1._read));
    endrule
  */

  // This rule fires on each cycle because it has no conditions
  // and no conflicts.
  // It just displays the shifter register contents, in decimal (%0d) format

  rule show;
    $display("  stage0: %0d, stage1: %0d, stage2: %0d", stage0, stage1, stage2);
  endrule
 
  // The next rule will fire each cycle because it has no conditions
  // and no conflicts
  rule stimuli;
    counter <= counter + 1;
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
