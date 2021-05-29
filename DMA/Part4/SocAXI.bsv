import Axi::*;
import BRAM::*;
import Connectable::*;
import TLM2::*;
import Vector::*;

import DMA::*;
import GDefines::*;
import BusRange::*;
import AxiS::*;
import AxiM::*;

`include "ARM.defines"

// ================================================================
// DMA of given size

(* synthesize *)
module mkDMA_n ( DmaC #(2) );
   let ifc <- mkDMA;
   return ifc;
endmodule

// ================================================================

typedef  TLMRecvIFC#(`ARM_RR)  SOC;

(*synthesize*)
module mkSOC_AXI (SOC);

   ////////////////////////////////////////////////////////////////////////////////
   /// DMA Controller
   ////////////////////////////////////////////////////////////////////////////////
   DmaC#(2) dmac <- mkDMA_n;
   AddressRange#(AxiAddr#(`ARM_PRM)) dmac_params = defaultValue;
   dmac_params.base       = 32'h0001_0000;
   dmac_params.high       = 32'h0002_0000 - 1;
   AxiRWSlaveXActor#(`ARM_XTR)  dmac_cfg  <- mkAxiRWSlave( addAddressRangeMatch( dmac_params ) );
   AxiRWMasterXActor#(`ARM_XTR) dmac_mem  <- mkAxiRWMaster;
   let connectCfg <- mkConnection(dmac_cfg.tlm, dmac.cfg);
   let connectMem <- mkConnection(dmac_mem.tlm, dmac.mmu);

   ////////////////////////////////////////////////////////////////////////////////
   /// BRAM1
   ////////////////////////////////////////////////////////////////////////////////
   BRAM_Configure bcfg = defaultValue;
   bcfg.memorySize = 10 * 1024; // 10 K words

   BRAM1Port#(Bit#(16), Bit#(32)) bram1 <-mkBRAM1Server(bcfg);
   TLMRecvIFC#(`ARM_RR) tlmbram1 <-mkTLMBRAM(bram1.portA);

   AddressRange#(AxiAddr#(`ARM_PRM))         bram1_params           = defaultValue;
   bram1_params.base       = 32'h0010_0000;
   bram1_params.high       = 32'h0020_0000 - 1;
   AxiRWSlaveXActor#(`ARM_XTR)   bram1_axi <- mkAxiRWSlave( addAddressRangeMatch( bram1_params ) );
   let bram1_connect <- mkConnection(tlmbram1, bram1_axi.tlm);

   ////////////////////////////////////////////////////////////////////////////////
   /// BRAM2
   ////////////////////////////////////////////////////////////////////////////////
   BRAM1Port#(Bit#(16), Bit#(32)) bram2 <-mkBRAM1Server(bcfg);
   TLMRecvIFC#(`ARM_RR) tlmbram2 <-mkTLMBRAM(bram2.portA);

   AddressRange#(AxiAddr#(`ARM_PRM))         bram2_params           = defaultValue;
   bram2_params.base       = 32'h0020_0000;
   bram2_params.high       = 32'h0030_0000 - 1;
   AxiRWSlaveXActor#(`ARM_XTR)   bram2_axi <- mkAxiRWSlave( addAddressRangeMatch( bram2_params ) );
   let bram2_connect <- mkConnection(tlmbram2, bram2_axi.tlm);

   ////////////////////////////////////////////////////////////////////////////////
   // A controlling master for use as the interface to SceMi
   ////////////////////////////////////////////////////////////////////////////////

   AxiRWMasterXActor#(`ARM_RR,`ARM_PRM)  ctrlMaster <- mkAxiRWMaster;

  ////////////////////////////////////////////////////////////////////////////////
   /// AXI Bus Fabric
   ////////////////////////////////////////////////////////////////////////////////
   Vector#(2,  AxiRdFabricMaster#(`ARM_PRM)) axi_rd_masters = ?;
   Vector#(2,  AxiWrFabricMaster#(`ARM_PRM)) axi_wr_masters = ?;

   Vector#(3,  AxiRdFabricSlave#(`ARM_PRM))  axi_rd_slaves;
   Vector#(3,  AxiWrFabricSlave#(`ARM_PRM))  axi_wr_slaves;

   // Masters
   axi_rd_masters[0] = dmac_mem.read;
   axi_rd_masters[1] = ctrlMaster.read;

   axi_wr_masters[0] = dmac_mem.write;
   axi_wr_masters[1] = ctrlMaster.write;

   // Slaves
   axi_rd_slaves[0]  = dmac_cfg.read;
   axi_rd_slaves[1]  = bram1_axi.read;
   axi_rd_slaves[2]  = bram2_axi.read;

   axi_wr_slaves[0]  = dmac_cfg.write;
   axi_wr_slaves[1]  = bram1_axi.write;
   axi_wr_slaves[2]  = bram2_axi.write;

   Empty   bus_axi_rd   <- mkAxiRdBus( axi_rd_masters, axi_rd_slaves );
   Empty   bus_axi_wr   <- mkAxiWrBus( axi_wr_masters, axi_wr_slaves );

   return  ctrlMaster.tlm;
endmodule

module [Module] mkSOC (SOC);
   (*hide*)
   let _ifc <- mkSOC_AXI;
   return _ifc;
endmodule
