package SceMiLayer;

import SceMi             ::*;
import Clocks            ::*;
import Connectable       ::*;
import GetPut            ::*;
import ClientServer      ::*;
import DefaultValue      ::*;
import FIFO              ::*;
import TLM2              ::*;

import GDefines::*;
import Soc::*;

module [SceMiModule] mkSceMiLayer(Empty);
   
   ////////////////////////////////////////////////////////////////////////////////
   /// Clocks & Resets
   ////////////////////////////////////////////////////////////////////////////////
   Clock                           uclk                <- sceMiGetUClock;
   Reset                           urst                <- sceMiGetUReset;

   ////////////////////////////////////////////////////////////////////////////////
   /// Dut Clock
   ////////////////////////////////////////////////////////////////////////////////
   SceMiClockConfiguration         clk_cfg              = defaultValue;
   clk_cfg.clockNum        = 0;
   clk_cfg.resetCycles     = 4;
   SceMiClockPortIfc               clk_port            <- mkSceMiClockPort( clk_cfg );
   let cclock = clk_port.cclock;
   let creset = clk_port.creset;

   ////////////////////////////////////////////////////////////////////////////////
   /// Design Elements
   ////////////////////////////////////////////////////////////////////////////////
   Soc                             dut                 <- buildDut( mkSoc, clk_port );
   
   Empty                           xshutdown           <- mkShutdownXactor;
   Empty                           xcontrol            <- mkSimulationControl( clk_cfg );
   
   Get#(BusRequest)                xrequest            <- mkInPortXactor( clk_port );
   Put#(BusResponse)               xresponse           <- mkOutPortXactor( clk_port );
   mkConnection(dut.rx, xrequest);
   mkConnection(dut.tx, xresponse);
   
endmodule

endpackage
