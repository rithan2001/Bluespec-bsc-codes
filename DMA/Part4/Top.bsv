package Top;

`include "ARM.defines"

import DefaultValue::*;
import TLM2::*;
import GetPut::*;
import StmtFSM::*;

import GDefines::*;

import SocAXI::*;

(* synthesize *)
module [Module] mkTop(Empty);

   SOC soc <- mkSOC;

   Put #(BusRequest)  rx = soc.rx;
   Get #(BusResponse) tx = soc.tx;

   function Action sendDMAconfig (Bool writeNotRead, Bit #(32) addr, Bit #(32) data);
      action
	 BusRequest req = defaultValue;
	 req.write   = writeNotRead;
	 req.byteen  = -1;
	 req.address = addr;
	 req.data    = data;
	 rx.put (req);
      endaction
   endfunction

   Reg #(Bool) done1 <- mkReg (False);
   Reg #(Bool) done2 <- mkReg (False);

   mkAutoFSM (
      seq
	 // Configure DMA channel 0
	 sendDMAconfig (True, 32'h0001_0000, 32'h0010_1000); // Channel 0 source address
	 sendDMAconfig (True, 32'h0001_0004, 32'h0000_0010); // Channel 0 count = 16
	 sendDMAconfig (True, 32'h0001_0008, 32'h0020_2000); // Channel 0 destination address

	 // Configure DMA channel 1
	 sendDMAconfig (True, 32'h0001_0100, 32'h0020_4000); // Channel 0 source address
	 sendDMAconfig (True, 32'h0001_0104, 32'h0000_000C); // Channel 0 count = 12
	 sendDMAconfig (True, 32'h0001_0108, 32'h0020_3000); // Channel 0 destination address

	 // Start both DMA transfers
	 sendDMAconfig (True, 32'h0001_000C, 32'h0000_0001); // Channel 0 enable
	 sendDMAconfig (True, 32'h0001_010C, 32'h0000_0001); // Channel 1 enable

	 // Absorb the responses for the above 8 writes
	 repeat (8)
	 action
	    BusResponse resp <- tx.get;
	    $display ("Top: BusResponse {error %0d cop %0d gdb %0d write %0d id %0d data %0h}",
		      resp.error, resp.cop, resp.gdb, resp.write, resp.id, resp.data);
	 endaction

	 // Poll until both DMA transfers are done
	 while ((! done1) || (! (done2))) seq
	    $display ("Channel busy status: %0d %0d", done1, done2);
	    delay (8);

	    // Poll the 'enable' registers until they are reset
	    sendDMAconfig (False, 32'h0001_000C, ?);
	    sendDMAconfig (False, 32'h0001_010C, ?);

	    action
	      BusResponse resp <- tx.get;
	      $display ("Top: BusResponse {error %0d cop %0d gdb %0d write %0d id %0d data %0h}",
			resp.error, resp.cop, resp.gdb, resp.write, resp.id, resp.data);
	      if (resp.data[0] == 1'b0) done1 <= True;
	    endaction
	    action
	      BusResponse resp <- tx.get;
	      $display ("Top: BusResponse {error %0d cop %0d gdb %0d write %0d id %0d data %0h}",
			resp.error, resp.cop, resp.gdb, resp.write, resp.id, resp.data);
	      if (resp.data[0] == 1'b0) done2 <= True;
	    endaction
	 endseq
	 $display ("Both channels done!");
      endseq
      );

endmodule

// ================================================================

// ================================================================

endpackage
