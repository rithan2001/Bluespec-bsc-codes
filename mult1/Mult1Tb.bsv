package Mult1Tb;

// testbench for Mult1

import Mult::*;
import Mult1::*;

(* synthesize *)
module mkMult1Tb (Empty);

   Reg#(Tin) x    <- mkReg(1);
   Reg#(Tin) y    <- mkReg(0);
   
   // The dut
   Mult_IFC dut <- mkMult1;
   
   // RULES ----------------
   
   rule rule_tb_1 (x < 20);
      $display ("    x = %d, y = %d", x, y);
      dut.start (x, y);
      x <= x + 1;
      y <= y + 1;
   endrule
   
   rule rule_tb_2 (x < 20);
      let z = dut.result();
      dut.acknowledge();
      $display("    Result = %d", z);
   endrule

   // TASK: Add a rule to invoke $finish(0) at the appropriate moment
   rule stop (x >= 20);
       $finish(0);
   endrule
      
   
endmodule : mkMult1Tb

endpackage : Mult1Tb
