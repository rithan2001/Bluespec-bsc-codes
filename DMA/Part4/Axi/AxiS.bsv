////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2010  Bluespec, Inc.   ALL RIGHTS RESERVED.
////////////////////////////////////////////////////////////////////////////////
//  Filename      : AxiS.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package AxiS;

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Axi               ::*;
import AxiCustom         ::*;

import GetPut            ::*;
import FIFO              ::*;
import SpecialFIFOs      ::*;
import DefaultValue      ::*;
import TLM2              ::*;
import Bus               ::*;

`include "TLM.defines"

////////////////////////////////////////////////////////////////////////////////
/// Types
////////////////////////////////////////////////////////////////////////////////

////////////////////////////////////////////////////////////////////////////////
/// Interfaces
////////////////////////////////////////////////////////////////////////////////
interface AxiRWSlaveXActor#(`TLM_XTR_DCL);
   interface TLMSendIFC#(`TLM_RR)        tlm;
   interface AxiRdFabricSlave#(`TLM_PRM) read;
   interface AxiWrFabricSlave#(`TLM_PRM) write;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
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

endpackage: AxiS
