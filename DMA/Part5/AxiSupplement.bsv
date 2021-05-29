import Axi::*;
import TLM2::*;
import GetPut::*;
import FIFO::*;
import SpecialFIFOs::*;
import DefaultValue::*;

`include "TLM.defines"

interface AxiRWMasterXActor#(`TLM_XTR_DCL);
   interface AxiRdFabricMaster#(`TLM_PRM) read;
   interface AxiWrFabricMaster#(`TLM_PRM) write;
   interface TLMRecvIFC#(`TLM_RR)         tlm;
endinterface

interface AxiRWSlaveXActor#(`TLM_XTR_DCL);
   interface TLMSendIFC#(`TLM_RR)        tlm;
   interface AxiRdFabricSlave#(`TLM_PRM) read;
   interface AxiWrFabricSlave#(`TLM_PRM) write;
endinterface


module mkAxiRWMaster(AxiRWMasterXActor#(`TLM_XTR))
   provisos(  Bits#(req_t, s0)
	    , Bits#(resp_t, s1)
	    , Bits#(cstm_type, s2)
	    , TLMRequestTC#(req_t, `TLM_PRM)
	    , TLMResponseTC#(resp_t, `TLM_PRM)
	    , DefaultValue#(cstm_type)
	    , AxiConvert#(AxiProt, cstm_type)
	    , AxiConvert#(AxiLock, cstm_type)
	    , AxiConvert#(AxiCache, cstm_type)
	    , AxiConvert#(AxiCustom, cstm_type)
	    );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   AxiRdMasterXActorIFC#(`TLM_XTR)           rd_master           <- mkAxiRdMaster;
   AxiWrMasterXActorIFC#(`TLM_XTR)           wr_master           <- mkAxiWrMaster;

   FIFO#(req_t)                              fRequest            <- mkBypassFIFO;
   FIFO#(resp_t)                             fResponse           <- mkBypassFIFO;

   let                                       reqFirst             = toTLMRequest(fRequest.first);

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   rule start_read(reqFirst matches tagged Descriptor .d &&& d.command matches READ);
      let request = fRequest.first; fRequest.deq;
      rd_master.tlm.rx.put(request);
   endrule

   rule start_write(reqFirst matches tagged Descriptor .d &&& d.command matches WRITE);
      let request = fRequest.first; fRequest.deq;
      wr_master.tlm.rx.put(request);
   endrule

   rule continue_write(reqFirst matches tagged Data .d);
      let data = fRequest.first; fRequest.deq;
      wr_master.tlm.rx.put(data);
   endrule

   (* preempts = "grab_read_data, grab_write_data" *)
   rule grab_read_data;
      let data <- rd_master.tlm.tx.get;
      fResponse.enq(data);
   endrule

   rule grab_write_data;
      let response <- wr_master.tlm.tx.get;
      fResponse.enq(response);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface read  = rd_master.fabric;
   interface write = wr_master.fabric;
   interface TLMRecvIFC tlm;
      interface rx = toPut(fRequest);
      interface tx = toGet(fResponse);
   endinterface

endmodule

module mkAxiRWSlave#(function Bool addr_match(AxiAddr#(`TLM_PRM) addr))(AxiRWSlaveXActor#(`TLM_XTR))
   provisos(  TLMRequestTC#(req_t, `TLM_PRM)
	    , TLMResponseTC#(resp_t, `TLM_PRM)
	    , Bits#(req_t, s0)
	    , Bits#(resp_t, s1)
	    , Bits#(cstm_type, s2)
	    , AxiConvert#(AxiCustom, cstm_type)
	    , AxiConvert#(AxiProt, cstm_type)
	    , AxiConvert#(AxiLock, cstm_type)
	    , AxiConvert#(AxiCache, cstm_type)
	    );

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   AxiRdSlaveXActorIFC#(`TLM_XTR)            rd_slave            <- mkAxiRdSlave(1, addr_match);
   AxiWrSlaveXActorIFC#(`TLM_XTR)            wr_slave            <- mkAxiWrSlave(1, addr_match);

   FIFO#(req_t)                              fRequest            <- mkBypassFIFO;
   FIFO#(resp_t)                             fResponse           <- mkBypassFIFO;

   ////////////////////////////////////////////////////////////////////////////////
   /// Rules
   ////////////////////////////////////////////////////////////////////////////////
   (* preempts = "process_read, process_write" *)
   rule process_read;
      let request <- rd_slave.tlm.tx.get;
      fRequest.enq(request);
   endrule

   rule process_write;
      let request <- wr_slave.tlm.tx.get;
      fRequest.enq(request);
   endrule

   rule handle_read_response(toTLMResponse(fResponse.first).command matches READ);
      let response = fResponse.first; fResponse.deq;
      rd_slave.tlm.rx.put(response);
   endrule

   rule handle_write_response(toTLMResponse(fResponse.first).command matches WRITE);
      let response = fResponse.first; fResponse.deq;
      wr_slave.tlm.rx.put(response);
   endrule

   ////////////////////////////////////////////////////////////////////////////////
   /// Interface Connections / Methods
   ////////////////////////////////////////////////////////////////////////////////
   interface TLMSendIFC tlm;
      interface tx = toGet(fRequest);
      interface rx = toPut(fResponse);
   endinterface
   interface read  = rd_slave.fabric;
   interface write = wr_slave.fabric;

endmodule

////////////////////////////////////////////////////////////////////////////////
/// Instances
////////////////////////////////////////////////////////////////////////////////
instance AxiConvert#(AxiCustom, Bit#(12));
   function AxiCustom toAxi(Bit#(12) value);
      AxiCustom custom = defaultValue;
      custom.lock  = unpack(value[8:7]);
      custom.cache = value[6:3];
      custom.prot  = value[2:0];
      return custom;
   endfunction
   function Bit#(12) fromAxi(AxiCustom value);
      return zeroExtend(pack(value));
   endfunction
endinstance

instance AxiConvert#(AxiCache, Bit#(12));
   function AxiCache toAxi(Bit#(12) value);
      AxiCustom custom = defaultValue;
      custom.lock  = unpack(value[8:7]);
      custom.cache = value[6:3];
      custom.prot  = value[2:0];
      return custom.cache;
   endfunction
   function Bit#(12) fromAxi(AxiCache value);
      return zeroExtend(pack(value) << 3);
   endfunction
endinstance

instance AxiConvert#(AxiLock, Bit#(12));
   function AxiLock toAxi(Bit#(12) value);
      AxiCustom custom = defaultValue;
      custom.lock  = unpack(value[8:7]);
      custom.cache = value[6:3];
      custom.prot  = value[2:0];
      return custom.lock;
   endfunction
   function Bit#(12) fromAxi(AxiLock value);
      return zeroExtend(pack(value) << 7);
   endfunction
endinstance

instance AxiConvert#(AxiProt, Bit#(12));
   function AxiProt toAxi(Bit#(12) value);
      AxiCustom custom = defaultValue;
      custom.lock  = unpack(value[8:7]);
      custom.cache = value[6:3];
      custom.prot  = value[2:0];
      return custom.prot;
   endfunction
   function Bit#(12) fromAxi(AxiProt value);
      return zeroExtend(pack(value) << 0);
   endfunction
endinstance
