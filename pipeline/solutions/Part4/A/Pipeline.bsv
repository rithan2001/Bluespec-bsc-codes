/*  Copyright Bluespec Inc. 2005-2008  */

package Pipeline;

import FIFO      :: *;    // import the FIFO package from the BSV library

import Functions :: *;

(* synthesize *)
module mkPipeline (FIFO#(Int#(16)));

  // ----------------
  // STATE (sub-modules)

  Integer n = 3;

  FIFO#(Int#(16))  stages [n];
  for (Integer j = 0; j < n; j = j + 1)
    stages [j] <- mkSizedFIFO (4);

  // ----------------
  // RULES (behavior)

  for (Integer j = 1; j < n; j = j + 1)
    rule shift_j;
      stages[j].enq (increment (stages[j-1].first, j*5)); stages[j-1].deq;
    endrule

  for (Integer j = 0; j < n; j = j + 1)
    rule show_j;
      $display("  stage%0d: %0d", j, stages[j].first());
    endrule
 
  // ----------------
  // INTERFACE

  method Action enq (Int#(16) x);
    stages[0].enq (x);
  endmethod

  method Int#(16) first ();
    return stages[n-1].first();
  endmethod

  method Action deq ();
    stages[n-1].deq();
  endmethod

  method Action clear ();
    for (Integer j = 0; j < n; j = j + 1)
      stages[j].clear();
  endmethod

endmodule: mkPipeline

endpackage: Pipeline
