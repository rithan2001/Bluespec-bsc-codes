/*  Copyright Bluespec Inc. 2005-2008  */

package Pipeline;

import FIFO      :: *;    // import the FIFO package from the BSV library
import GetPut::*;
import ClientServer::*;

import Functions :: *;

// (* synthesize *)                // Uncomment this and recompile, after everything is working
module mkPipeline (Server#(Int#(16), Int#(16)));

  // ----------------
  // State (sub-modules)

  // Instantiate three FIFOs: stage0, stage1 and stage2.
  // We use the library interface FIFO and the library module mkSizedFIFO.

  FIFO#(Int#(16)) stage0 <- mkSizedFIFO(4);    // depth 4 FIFO
  FIFO#(Int#(16)) stage1 <- mkSizedFIFO(4);
  FIFO#(Int#(16)) stage2 <- mkSizedFIFO(4);


  // ----------------
  // RULES (behavior)

  rule shift1;
    stage1.enq (increment (stage0.first, 5)); stage0.deq;
  endrule

  rule shift2;
    stage2.enq (decrement (stage1.first, 3)); stage1.deq;
  endrule

  // These rules display the shifter FIFO contents, in decimal (%0d) format

  rule show0;
    $display("  stage0: %0d", stage0.first);
  endrule

  rule show1;
    $display("  stage1: %0d", stage1.first);
  endrule

  rule show2;
    $display("  stage2: %0d", stage2.first);
  endrule

  // ----------------
  // INTERFACE

   interface Put request = toPut(stage0);
   interface Get response = toGet(stage2);
endmodule: mkPipeline

endpackage: Pipeline
