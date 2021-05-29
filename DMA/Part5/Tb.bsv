import DMA::*;
import Types::*;
import Soc::*;
import GDefines::*;

import BRAM::*;
import StmtFSM::*;
import SceMiProxies::*;
import GetPut::*;
import Connectable::*;
import TLM2::*;
import DefaultValue::*;

`include "AXI.defines"

(* synthesize *)
module mkTb();

   Reg#(Bit#(32)) i  <- mkReg(0);
   Reg#(Bool)           done1        <- mkReg(False);
   Reg#(Bool)           done2        <- mkReg(False);

   // instantiating the scemi proxies to connect to the system
   SceMiMessageInPortProxyIfc#(BusRequest)   request  <- mkSceMiMessageInPortProxy("mkBridge.params", "", "scemi_xrequest_inport");
   SceMiMessageOutPortProxyIfc#(BusResponse) response <- mkSceMiMessageOutPortProxy("mkBridge.params", "", "scemi_xresponse_outport");
   
   SceMiMessageInPortProxyIfc#(Bit#(32))     simreq   <- mkSceMiMessageInPortProxy("mkBridge.params", "", "scemi_xcontrol_req_in");
   SceMiMessageOutPortProxyIfc#(Bit#(32))    simresp  <- mkSceMiMessageOutPortProxy("mkBridge.params", "", "scemi_xcontrol_resp_out");
   
   SceMiMessageInPortProxyIfc#(Bool)         shutdown <- mkSceMiMessageInPortProxy("mkBridge.params", "", "scemi_xshutdown_ctrl_in");
   SceMiMessageOutPortProxyIfc#(Bool)        done     <- mkSceMiMessageOutPortProxy("mkBridge.params", "", "scemi_xshutdown_ctrl_out");
   

   function Stmt sendWrite(Bit#(32) address, Bit#(32) data);
      return seq
	 action
	    BusRequest req = defaultValue;
	    req.write = True;
	    req.address = address;
	    req.data = data;
	    request.send(req);
	    $display("send write %08x <= %08x", address, data);
	 endaction
	 action
	    let r <- toGet(response).get;
	    $display("resp write");
	 endaction
      endseq;
   endfunction
   
   function Action sendRead(Bit#(32) address);
      action
	 BusRequest req = defaultValue;
	 req.write = False;
	 req.address = address;
	 request.send(req);
	 $display("send read %08x", address);
      endaction
   endfunction
   
   // the configuration sequence
   Stmt test = seq
      delay(10);
      simreq.send(32'hFFFFFFF);
      delay(10);
      // initializing the bram
      $display("Initializing The BRAM");
      for (i<=0; i<300; i<=i+1)
   	 sendWrite(32'h0010_0000 + (i*4), i);
      $display("Done.");
		  
      // configuring the DMA controller channel 0
      $display("configuring channel 0...");
      sendWrite(32'h0001_0000, 32'h0010_0000); // src address 0010_0000
      sendWrite(32'h0001_0004, 16);            // 10 chunks of data
      sendWrite(32'h0001_0008, 32'h0010_0100); // dst address 0010_0100

      // configuring the DMA controller channel 1
      $display("configuring channel 1...");
      sendWrite(32'h0001_0100, 32'h0010_0100); // src address 0010_0100
      sendWrite(32'h0001_0104, 12);            // 10 chunks of data
      sendWrite(32'h0001_0108, 32'h0010_0200); // dst address 0010_0200

      sendWrite(32'h0001_000C, 1);             // setting "busy"
      sendWrite(32'h0001_010C, 1);             // setting "busy"

      // Poll until both DMA transfers are done
      while ((! done1) || (! (done2))) seq
         $display ("Channel busy status: %0d %0d", done1, done2);
         delay (8);

         // Poll the 'enable' registers until they are reset
         sendRead (32'h0001_000C);
         action
            BusResponse resp <- toGet(response).get;
            $display ("Top: BusResponse {error %0d cop %0d gdb %0d write %0d id %0d data %0h}",
       	   	resp.error, resp.cop, resp.gdb, resp.write, resp.id, resp.data);
            if (resp.data[0] == 1'b0) done1 <= True;
         endaction

         sendRead (32'h0001_010C);
         action
            BusResponse resp <- toGet(response).get;
            $display ("Top: BusResponse {error %0d cop %0d gdb %0d write %0d id %0d data %0h}",
       		resp.error, resp.cop, resp.gdb, resp.write, resp.id, resp.data);
            if (resp.data[0] == 1'b0) done2 <= True;
         endaction
      endseq
      $display ("Both channels done!");
		  
      $display("reading results starting address 0x0010_0100");
      for(i<=0; i<16; i<=i+1) seq
         sendRead(32'h0010_0100+(i*4));
         action
      	    let resp <- toGet(response).get;
            $display("read %d from destination", resp);
         endaction
      endseq
      
      delay(10);
      
      $display("reading results starting address 0x0010_0200");
      for(i<=0; i<12; i<=i+1) seq
         sendRead(32'h0010_0200+(i*4));
         action
      	    let resp <- toGet(response).get;
      	    $display("read %d from destination", resp);
         endaction
      endseq
      delay(10);

      shutdown.send(True);
      action
	 let r <- toGet(done).get;
      endaction
   endseq;

   mkAutoFSM(test); // instantiating an fsm to execute test

endmodule
