import Axi::*;
import AxiSupplement::*;
import Vector::*;
import Connectable::*;
import GetPut::*;
import DefaultValue::*;
import BRAM::*;
import TLM2::*;
import TLMBRAM::*;

import DMA::*;
import Types::*;
import BusRange::*;
import GDefines::*;

`include "AXI.defines"

typedef  TLMRecvIFC#(`AXI_RR) Soc;

(*synthesize*)
module mkDMA_n(DmaC#(2));
   let ifc <- mkDMA;
   return ifc;
endmodule

(*synthesize*)
module [Module] mkSoc(Soc);
      
   ////////////////////////////////////////////////////////////////////////////////
   /// DMA Controller
   ////////////////////////////////////////////////////////////////////////////////
   DmaC#(2) dmac <- mkDMA_n;
   AddressRange#(AxiAddr#(`AXI_PRM)) dmac_params = defaultValue;
   dmac_params.base = 32'h0001_0000;
   dmac_params.high = 32'h0002_0000 - 1;
   AxiRWSlaveXActor#(`AXI_XTR)   dmac_cfg <- mkAxiRWSlave( addAddressRangeMatch( dmac_params ) );
   AxiRWMasterXActor#(`AXI_XTR)  dmac_mem <- mkAxiRWMaster;
   let connectCfg <- mkConnection(dmac_cfg.tlm, dmac.cfg);
   let connectMem <- mkConnection(dmac_mem.tlm, dmac.mmu);
   
   ////////////////////////////////////////////////////////////////////////////////
   /// BRAM
   ////////////////////////////////////////////////////////////////////////////////
   BRAM_Configure bcfg = defaultValue;
   bcfg.memorySize = 10 * 1024; // 10 K words
   
   BRAM1Port#(Bit#(16), Bit#(32)) bram <- mkBRAM1Server(bcfg);
   TLMRecvIFC#(`AXI_RR) tlmbram <- mkTLMBRAM(bram.portA);
   
   AddressRange#(AxiAddr#(`AXI_PRM)) bram_params = defaultValue;
   bram_params.base = 32'h0010_0000;
   bram_params.high = 32'h0020_0000 - 1;
   AxiRWSlaveXActor#(`AXI_XTR) bram_axi <- mkAxiRWSlave( addAddressRangeMatch( bram_params ) );
   let connectBram <- mkConnection(tlmbram, bram_axi.tlm);
      
   ////////////////////////////////////////////////////////////////////////////////
   /// Connection from Testbench
   ////////////////////////////////////////////////////////////////////////////////
   AxiRWMasterXActor#(`AXI_XTR)  tb <- mkAxiRWMaster;

   ////////////////////////////////////////////////////////////////////////////////
   /// Axi Read Fabric
   ////////////////////////////////////////////////////////////////////////////////
   Vector#(0, AxiRdFabricMaster#(`AXI_PRM)) axi_rd_masters0 = ?;
   Vector#(0, AxiRdFabricSlave#(`AXI_PRM))  axi_rd_slaves0  = ?;
   
   // Master(s)
   let axi_rd_masters1 = cons(dmac_mem.read, axi_rd_masters0);
   let axi_rd_masters2 = cons(tb.read,       axi_rd_masters1);
   let axi_rd_masters  = axi_rd_masters2;
   
   // Slave(s)
   let axi_rd_slaves1  = cons(dmac_cfg.read, axi_rd_slaves0);
   let axi_rd_slaves2  = cons(bram_axi.read, axi_rd_slaves1);
   let axi_rd_slaves   = axi_rd_slaves2;
   
   // Bus Fabric
   let bus_axi_rd <- mkAxiRdBus( axi_rd_masters, axi_rd_slaves );

   ////////////////////////////////////////////////////////////////////////////////
   /// Axi Write Fabric
   ////////////////////////////////////////////////////////////////////////////////
   Vector#(0, AxiWrFabricMaster#(`AXI_PRM)) axi_wr_masters0 = ?;
   Vector#(0, AxiWrFabricSlave#(`AXI_PRM))  axi_wr_slaves0  = ?;
   
   // Master(s)
   let axi_wr_masters1 = cons(dmac_mem.write, axi_wr_masters0);
   let axi_wr_masters2 = cons(tb.write,       axi_wr_masters1);
   let axi_wr_masters  = axi_wr_masters2;
   
   // Slave(s)
   let axi_wr_slaves1  = cons(dmac_cfg.write, axi_wr_slaves0);
   let axi_wr_slaves2  = cons(bram_axi.write, axi_wr_slaves1);
   let axi_wr_slaves   = axi_wr_slaves2;
   
   // Bus Fabric
   let bus_axi_wr <- mkAxiWrBus( axi_wr_masters, axi_wr_slaves );
      
   return tb.tlm;
endmodule
