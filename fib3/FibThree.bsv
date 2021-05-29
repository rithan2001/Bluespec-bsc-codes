// import FIFO library
import FIFO::*;

interface Fib;
  // putRequest() takes an int, and performs an Action (side effects)
  method Action putRequest(int n);
  // getReply() returns an int, and performs an Action (side effects)
  method ActionValue#(int) getReply();
endinterface: Fib

(* synthesize *)
module mkFibThree(Fib);  // mkFibThree provides an interface (Fib)

  // TASK: implement two-issue Fibonacci circuit

  // HINT: create a requests FIFO and a replies FIFO to buffer I/O;
  //       the Fib interface methods should write to/read from these FIFOs

  // HINT: create two sets of registers, each containing this/next fib values,
  //       a counter, and an answer presence bit

  // HINT: create three rules for each execution unit: one to start the
  //       computation, one to compute the result, and one to store the value
  //       in the results FIFO.  Take care to update the presence bit
  //       correctly.

endmodule: mkFibThree

