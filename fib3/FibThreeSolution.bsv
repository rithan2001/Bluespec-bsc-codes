// solution for Fibonacci Lab Three

// import FIFO library
import FIFO::*;


interface Fib;
  // putRequest() takes an int, and performs an Action (side effects)
  method Action putRequest(int n);
  // getReply() returns an int, and performs an Action (side effects)
  method ActionValue#(int) getReply();
endinterface: Fib

(* synthesize *)
module mkFibThree(Fib);  // this time mkFibThree provides an interface (Fib)

  // queues to store request and responses
  FIFO#(int) requests <- mkFIFO();
  FIFO#(int) replies <- mkFIFO();

  // registers for first fib unit
  Reg#(int)  one_this_fib <- mkRegU();
  Reg#(int)  one_next_fib <- mkRegU();
  Reg#(int)  one_count <- mkReg(0);
  Reg#(Bool) one_has_ans <- mkReg(False); // keep answer until removed

  // registers for second fib unit
  Reg#(int)  two_this_fib <- mkRegU();
  Reg#(int)  two_next_fib <- mkRegU();
  Reg#(int)  two_count <- mkReg(0);
  Reg#(Bool) two_has_ans <- mkReg(False); // keep answer until removed


  // loading first fib unit
  rule one_load(one_count == 0 && !one_has_ans);
    one_this_fib <= 0;
    one_next_fib <= 1;
    // eat the next request and remove from requests queue
    one_count <= requests.first();
    requests.deq();
    one_has_ans <= one_count == 0;
  endrule: one_load

  // computation for first fib unit
  rule one_fib(one_count != 0);
    one_this_fib <= one_next_fib;
    one_next_fib <= one_this_fib + one_next_fib;
    one_count <= one_count - 1;
    one_has_ans <= one_count == 1;
  endrule: one_fib

  // completion for first fib unit
  rule one_finish(one_count == 0 && one_has_ans);
    replies.enq(one_this_fib);
    one_has_ans <= False;
  endrule: one_finish

  // loading second fib unit
  rule two_load(two_count == 0 && !two_has_ans);
    two_this_fib <= 0;
    two_next_fib <= 1;
    // eat the next request and remove from requests queue
    two_count <= requests.first();
    requests.deq();
    two_has_ans <= two_count == 0;
  endrule: two_load

  // computation for second fib unit
  rule two_fib(two_count != 0);
    two_this_fib <= two_next_fib;
    two_next_fib <= two_this_fib + two_next_fib;
    two_count <= two_count - 1;
    two_has_ans <= two_count == 1;
  endrule: two_fib

  // completion for second fib unit
  rule two_finish(two_count == 0 && two_has_ans);
    replies.enq(two_this_fib);
    two_has_ans <= False;
  endrule: two_finish

  // putRequest available whenever requests queue can accept new data
  method Action putRequest(int n);
    action
      requests.enq(n);
    endaction
  endmethod: putRequest

  // getReply only available when replies queue has data
  method ActionValue#(int) getReply();
    actionvalue
      replies.deq();
      return replies.first();
    endactionvalue
  endmethod: getReply
endmodule: mkFibThree

