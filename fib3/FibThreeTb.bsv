// testbench for FibThree

import FibThree::*;

(* synthesize *)
module mkFibThreeTb();
   // test value register
   Reg#(int) tbCounter();
   mkReg#(0) tbCounter_instance(tbCounter);

   // device under test
   Fib fib();
   mkFibThree fib_instance(fib);

   // rules to manage the device under test
   // note lack of explicit flow control, which is inserted by the compiler
   // from the implicit condition in fib's methods
   rule show;
      $display("%0d", fib.getReply());
      if ( tbCounter > 40 ) $finish(0) ;
   endrule: show
  
   rule feed;
      tbCounter <= tbCounter + 1;
      fib.putRequest(tbCounter);
   endrule: feed
endmodule

