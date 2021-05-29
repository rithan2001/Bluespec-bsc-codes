// solution for Fibonacci Lab Two
package FibTwo
interface Fib;
  // putRequest() takes an int, and performs an Action (side effects)
  method Action putRequest(int n);
  // getReply() returns an int, and has no side effects (no Action)
  method int getReply();
endinterface: Fib

(* synthesize *)
module mkFibTwo(Fib);  // this time mkFibTwo provides an interface (Fib)
  Reg#(int) this_fib <- mkReg(0);
   
  Reg#(int) next_fib <- mkRegU;  // registers made by mkRegU have no reset 
                                 // or initial value but same Reg interface
  Reg#(int) count <- mkReg(0);

  rule fib(count != 0);
    this_fib <= next_fib;
    next_fib <= this_fib + next_fib;  // note that this uses stale this_fib
    count <= count - 1;
  endrule: fib

  // putRequest only available when circuit not computing (count == 0)
  method Action putRequest(int n) if (count == 0);
    action
      this_fib <= 0;
      next_fib <= 1;
      count <= n;
    endaction
  endmethod: putRequest

  // getReply only available when answer is ready (count == 0)
  method int getReply() if (count == 0);
    return this_fib;
  endmethod: getReply
endmodule: mkFibTwo
endpackage: FibTwo
