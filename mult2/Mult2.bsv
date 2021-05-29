package Mult2; 

// Multiplier using Booth encoding

import Mult::*;

function Tout boothenc (Bit#(3) n, Tout x);
   case ( n )
      0: return 0;     // isolated zero
      1: return x;     // high end of run of ones
      2: return x;     // isolated one
      3: return 2*x;   // high end of run of ones
      4: return -(2*x);// low end of run of ones
      5: return (-x);  // end one run, start another
      6: return (-x);  // low end of run of ones
      7: return 0;     // middle of run of ones
   endcase
endfunction

(* synthesize *)
module mkMult2( Mult_IFC );
   Reg#(Bool)    available <- mkReg(True);
   Reg#(Tout)      product <- mkReg(?);
   Reg#(TinPlusOne)  mcand   <- mkReg(0);
   Reg#(Tout)      mplr    <- mkReg(?);

   rule cycle ( mcand != 0 );
      // TASK: fill in the body of this rule, dealing with the bits of mcand
      // two at a time (but also looking at the adjacent bit).
      
      Tout tmp = boothenc( mcand[2:0], mplr );
      product <= product + tmp;
      mplr    <= mplr  << 2;
      mcand   <= mcand >> 2;
   endrule
   
   method Action start (Tin m1, Tin m2) if ((mcand == 0) && available);
      product <= 0;
      mplr    <= { 0, m1 };
      mcand   <= { m2, 1'b0 }; // append an extra 0: the "adjacent bit" for
			       // the first encoding.
      available <= False;
   endmethod

   method ActionValue#(Tout) result () if ((mcand == 0) && !available);
       // TASK: complete this method.
      available <= True;
      return product;
   endmethod
   
endmodule
        
endpackage
