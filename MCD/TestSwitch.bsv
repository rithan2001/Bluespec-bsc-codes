import Switch::*;

(* synthesize *)
module sysTestSwitch(Empty);

  Reg#(Bit#(32)) a_count();
  mkReg#(0) the_a_count(a_count);

  Reg#(Bit#(32)) b_count();
  mkReg#(0) the_b_count(b_count);

  Reg#(Bit#(32)) out_count();
  mkReg#(0) the_out_count(out_count);

  Reg#(Bit#(32)) flip_count();
  mkReg#(0) the_flip_count(flip_count);

  Switch#(Bit#(32)) s();
  mkSwitch the_s(s);
  
  rule push_a (a_count < 10);
    let a_val = a_count + 10; // 10, 11, .. 19
    s.enq_a(a_val); 
    $display ("Send %0d to switch port a at time %0t", a_val, $time);
    a_count <= a_count + 1;
  endrule

  rule push_b (b_count < 10);
    let b_val = b_count + 20; // 20, 21, .. 29
    s.enq_b(b_val); 
    $display("Send %0d to switch port b at time %0t", b_val, $time); 
    b_count <= b_count + 1;
  endrule

  rule display_out;
    $display("Output %0d received at time %0t", s.first, $time);
    s.deq;
    out_count <= out_count + 1;
  endrule

  rule exit(out_count == 20);
    $display("20 elements received at time %0t", $time);
    $finish(0);
  endrule

  rule flip; 
    if (flip_count == 5)
      begin
        flip_count <= 0;
        s.flip;
        $display("Flip switch at time %0t", $time);
      end
    else
      flip_count <= flip_count + 1;
   endrule

endmodule

