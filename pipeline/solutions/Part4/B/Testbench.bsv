/*  Copyright Bluespec Inc. 2005-2008  */

package Testbench;

import FIFO      :: *;    // import the FIFO package from the BSV library

import Functions :: *;

import Pipeline :: *;

module mkTestbench (Empty);

  // ----------------
  // STATE (sub-modules)

  // A counter for feeding the pipeline
  Reg#(UInt#(8)) counter <- mkReg(0);
  
  // Instantiate the pipeline

  FIFO#(Int#(16)) pipe <- mkPipeline (5);

  // ----------------
  // RULES (behavior)

  // This rule fires on each cycle because it has no conditions
  // and no conflicts

  rule stimuli;
    counter <= counter + 1;
  endrule

  rule shift0;
    // pipe.enq (counter);    // First attempt: type-checking error
    pipe.enq (unpack (zeroExtend (pack (counter))));
  endrule

  rule shift3;
    pipe.deq;
  endrule

  // This rule just limits the length of the simulation
  rule stop (counter == 100);
    $finish(0);
  endrule: stop

  // ----------------
  // INTERFACE

    /* None */

endmodule: mkTestbench

endpackage: Testbench
