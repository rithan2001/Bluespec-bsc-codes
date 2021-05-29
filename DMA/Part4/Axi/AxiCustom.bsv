////////////////////////////////////////////////////////////////////////////////
// Copyright (c) 2010  Bluespec, Inc.   ALL RIGHTS RESERVED.
////////////////////////////////////////////////////////////////////////////////
//  Filename      : AxiCustom.bsv
//  Description   : 
////////////////////////////////////////////////////////////////////////////////

// Notes :

////////////////////////////////////////////////////////////////////////////////
/// Imports
////////////////////////////////////////////////////////////////////////////////
import Axi               ::*;
import DefaultValue      ::*;

`include "TLM.defines"

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


