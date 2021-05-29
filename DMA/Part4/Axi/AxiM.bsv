////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2010  Bluespec, Inc.   ALL RIGHTS RESERVED.
////////////////////////////////////////////////////////////////////////////////
//  Filename      : AxiM.bsv
//  Description   :
////////////////////////////////////////////////////////////////////////////////
package AxiM;

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
interface AxiRWMasterXActor#(`TLM_XTR_DCL);
   interface AxiRdFabricMaster#(`TLM_PRM) read;
   interface AxiWrFabricMaster#(`TLM_PRM) write;
   interface TLMRecvIFC#(`TLM_RR)         tlm;
endinterface

////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
///
/// Implementation
///
////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////
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

endpackage: AxiM
