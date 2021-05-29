// Copyright Bluespec Inc. 2009-2010

#include <iostream>
#include <stdexcept>
#include <string>
#include <cstdlib>
#include <cstring>

#include <pthread.h>

// Bluespec's version -- $BLUESPECDIR/tcllib/include
//#include "tcl.h"

#include "DMATester.h"

// Bluespec common code
#include "bsdebug_common.h"


using namespace std;

// the package name and namespace for this extension

#define PKG_NAME    "BSDebug"
#define NS          "bsdebug"
#define PKG_VERSION "1.0"

// static extension global data
class SceMiGlobalData {
public:
  bool			m_initialized ;
  SceMi                 * m_scemi;
  DMATester     	* m_busmaster;
  SceMiServiceThread    * m_serviceThread;
  SimulationControl 	* m_simControl;
  ProbesXactor          * m_probeControl;

  // Simple initializer invoked when the extension is loaded
  SceMiGlobalData ()
    : m_initialized(false)
    , m_scemi(0)
    , m_busmaster(0)
    , m_serviceThread(0)
    , m_simControl(0)
    , m_probeControl(0)
  {}

  ~SceMiGlobalData ()
  {
    if (m_initialized) {
      destroy();
    }
  }

  // Initialization -- call from bsdebug::scemi init <param>
  void init (const char *paramfile) {

    if (m_initialized) throw std::runtime_error ("scemi is already initialized");

     // Initialize SceMi
    int sceMiVersion = SceMi::Version( SCEMI_VERSION_STRING );
    SceMiParameters params( paramfile );
    m_scemi = SceMi::Init( sceMiVersion, & params );
    if (! m_scemi) throw std::runtime_error ("Could not initialize SceMi");

    // initialize ProbesXactor          * probeControl;
    m_probeControl = ProbesXactor::init("", "scemi_dut_prb_control", NULL, m_scemi);

    /* initiate the SCE-MI transactors and threads */
    // Create the transactor
    m_busmaster = new DMATester(m_scemi);

    m_simControl  = new SimulationControl ("", "scemi_xcontrol" ,m_scemi);

    // Start a SceMiService thread;
    m_serviceThread = new SceMiServiceThread  (m_scemi);

    m_initialized = true ;
  }

  // Destruction -- called from bsdebug::scemi delete
  void destroy () {
    m_initialized = false ;
    // Stop the simulation side
    if (m_busmaster) m_busmaster->shutdown();

    // Stop and join with the service thread, then shut down scemi --
    if (m_serviceThread) {
      m_serviceThread->stop();
      m_serviceThread->join();
      delete m_serviceThread;  m_serviceThread = 0;
    }

    // Delete the simulation control
    delete m_simControl; m_simControl = 0;

    //Delete the clktest Dut
    delete m_busmaster; m_busmaster = 0;

    // Shutdown the probes transactor
    ProbesXactor::shutdown();

    // Shutdown SceMi
    if (m_scemi) {
      SceMi::Shutdown(m_scemi);
      m_scemi = 0;
    }
  }

} SceMiGlobal;




// forward declarations of C functions which are called by tcl
extern "C" {

  // Package intialization  and cleanup
  extern int Bsdebug_Init (Tcl_Interp * interp);
  extern int Bsdebug_Unload (Tcl_Interp * interp,  int flags);
  extern void Bsdebug_ExitHandler (ClientData clientData);

  extern int SceMi_Cmd(ClientData clientData,
                       Tcl_Interp *interp,
                       int objc,
                       Tcl_Obj *const objv[]);

  extern int Dut_Cmd(ClientData clientData,
                     Tcl_Interp *interp,
                     int objc,
                     Tcl_Obj * objv[]);

} // extern "C"



// Function called if/when the dynamic library is unloaded
// Function name must match package library name
int Bsdebug_Unload (Tcl_Interp * interp,  int flags)
{
  if (flags & TCL_UNLOAD_DETACH_FROM_PROCESS) {
    SceMiGlobalData *pglobal = & SceMiGlobal;
    pglobal->destroy();
    Tcl_DeleteExitHandler ( Bsdebug_ExitHandler, &SceMiGlobal);
  }
  return TCL_OK;
}

// Exit handler called during exit.
void Bsdebug_ExitHandler (ClientData clientData)
{
  SceMiGlobalData *pglobal = (SceMiGlobalData *) clientData;
  pglobal->destroy();
}

// Package initialization function -- called during package load/require
// function name must match package library name
int Bsdebug_Init(Tcl_Interp *interp)
{
  Tcl_Namespace* nsptr = NULL;

  try {
    // register the exit handler
    Tcl_CreateExitHandler( Bsdebug_ExitHandler, &SceMiGlobal);

    // Dynmaic binding of this extension to tcl
    if (Tcl_InitStubs(interp, TCL_VERSION, 0) == NULL) {
      return TCL_ERROR;
    }

    // Create a namespace NS
    nsptr = (Tcl_Namespace*) Tcl_CreateNamespace(interp, NS, NULL, NULL);
    if (nsptr == NULL) {
      return TCL_ERROR;
    }

    // Provide the tcl package
    if (Tcl_PkgProvide(interp, PKG_NAME, PKG_VERSION) != TCL_OK) {
      return TCL_ERROR;
    }

    // Register commands to this tcl extension
    // A top-level tcl bsdebug::scemi command -- application specific boilerplate
    Tcl_CreateObjCommand(interp,
			 NS "::scemi",
			 (Tcl_ObjCmdProc *) SceMi_Cmd,
			 (ClientData) &(SceMiGlobal),
                         0);
    Tcl_Export(interp, nsptr, "scemi", 0);

    // A top-level tcl dut command -- application specific
    Tcl_CreateObjCommand(interp,
			 NS "::dut",
			 (Tcl_ObjCmdProc *) Dut_Cmd,
			 (ClientData) &(SceMiGlobal.m_busmaster),
			 0);
    Tcl_Export(interp, nsptr, "dut", 0);

    // Bluespec emulation control command
    Tcl_CreateObjCommand(interp,
                         NS "::emu",
                         (Tcl_ObjCmdProc *) Emu_Cmd,
                         (ClientData) &(SceMiGlobal.m_simControl),
                         (Tcl_CmdDeleteProc *) Emu_Cmd_Delete);
    Tcl_Export(interp, nsptr, "emu", 0);

    // Bluespec probe capture command
    Tcl_CreateObjCommand(interp,
                         NS "::probe",
                         (Tcl_ObjCmdProc *) Capture_Cmd,
                         (ClientData) &(SceMiGlobal.m_probeControl),
                         (Tcl_CmdDeleteProc *) Capture_Cmd_Delete);
    Tcl_Export(interp, nsptr, "probe", 0);

    // Other command can go here

  } catch (const exception & error) {
    Tcl_AppendResult(interp, error.what()
                     ,"\nCould not initialize bsdebug tcl package"
                     ,(char *) NULL);
    return TCL_ERROR;
  }

  return TCL_OK;
}




// implementation of the scemi command ensemble
// at the tcl level, the command will be
// bsdebug::scemi init <params file>
// bsdebug::scemi delete
extern "C" int SceMi_Cmd(ClientData clientData,    	//  &(GlobalXactor),
                     Tcl_Interp *interp,      	// Current interpreter
                     int objc,               	// Number of arguments
                     Tcl_Obj *const objv[]   	// Argument strings
         )
{
  // Command table
  enum ScemiCmds { scemi_init, scemi_delete };
  static const cmd_struct cmds_str[] = {
    {"init",		scemi_init,		"<params file>"}
    ,{"delete",		scemi_delete,		""}
    ,{0}                        // MUST BE LAST
  };

  // Cast client data to proper type
  SceMiGlobalData *pglobal = (SceMiGlobalData *) clientData;

  // Extract sub command
  ScemiCmds command;
  int index;
  if (objc == 1) goto wrongArgs;
  if (TCL_OK != Tcl_GetIndexFromObjStruct (interp, objv[1], cmds_str, sizeof(cmd_struct),
                                           "command", 0, &index ) ) {
    return TCL_ERROR;
  }


  command = (enum ScemiCmds) cmds_str[index].enumcode;
  switch (command) {
    case scemi_init:
    {
	if (objc != 3) goto wrongArgs;
	char *paramfile = Tcl_GetString(objv[2]);
	try {
          pglobal->init(paramfile);
	} catch (const exception & error) {
          Tcl_AppendResult(interp, error.what()
                           ,"\nCould not initialize emulation"
                           ,(char *) NULL);
	  return TCL_ERROR;
	}
      break;
    }
    case scemi_delete:
        pglobal->destroy();
        break;
  }
  return TCL_OK;

wrongArgs:
  dumpArguments (interp, cmds_str, Tcl_GetString(objv[0]));
  return TCL_ERROR;
}
#define CheckStatus(var) if ((var) != TCL_OK) { return var; }

// Forward references for dut subcommands
#define TCLFUNC(name) static int name(ClientData, Tcl_Interp *, int objc, struct Tcl_Obj *const objv[])
TCLFUNC(dut_read);
TCLFUNC(dut_write);
TCLFUNC(dut_fill);
TCLFUNC(dut_dump);
TCLFUNC(dut_readQ);
TCLFUNC(dut_writeQ);
TCLFUNC(dut_fillQ);
TCLFUNC(dut_dumpQ);
TCLFUNC(dut_responseQ);


// implementation of the Dut command ensemble
extern "C" int Dut_Cmd(ClientData clientData,    	//  &(GlobalXactor.m_busmaster)
                   Tcl_Interp *interp,     	// Current interpreter
                   int objc,               	// Number of arguments
                   Tcl_Obj * objv[]   	// Argument strings
         )
{
  // Command table
  static const cmd_struct_funptr_2 cmds_str[] = {
    // CMD Name,  Help Str,        arg cnt  function name
    {"read",		"<addr>"			,1  ,dut_read}
    ,{"write",		"<addr> <data>"			,2  ,dut_write}
    ,{"fill",		"<lo> <hi> <dat> <incr>"	,4  ,dut_fill}
    ,{"dump",		"<lo> <hi>"			,2  ,dut_dump}
    ,{"readQ",		"<addr>"			,1  ,dut_readQ}
    ,{"writeQ",		"<addr> <data>"			,2  ,dut_writeQ}
    ,{"fillQ",		"<lo> <hi> <dat> <incr>"	,4  ,dut_fillQ}
    ,{"dumpQ",		"<lo> <hi>"			,2  ,dut_dumpQ}
    ,{"responseQ",	"" 				,0  ,dut_responseQ}
    ,{0}                        // MUST BE LAST
  };

  // Check that client data has been set
  DMATester *synctx = *(DMATester **) clientData;
  if (synctx == 0) {
    Tcl_SetResult (interp, (char *) "Cannot use dut command before emulation initialization", TCL_STATIC );
    return TCL_ERROR;
  }

  // Extract sub command
  int index;
  tclfunptr command ;
  int stat;
  if (objc == 1) goto wrongArgs;
  if (TCL_OK != Tcl_GetIndexFromObjStruct (interp, objv[1], cmds_str, sizeof(cmd_struct_funptr_2),
                                           "dut command", TCL_EXACT, &index ) ) {
    return TCL_ERROR;
  }
  if (cmds_str[index].numargs + 2 != objc) goto wrongArgs;

  command = cmds_str[index].function;
  stat = command(clientData, interp, objc, objv);
  return stat;

wrongArgs:
  dumpArguments (interp, cmds_str, Tcl_GetString(objv[0]));
  return TCL_ERROR;
}



// dut read <addr>
static int dut_read (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                     Tcl_Interp *interp,       // Current interpreter
                     int objc,                 // Number of arguments
                     Tcl_Obj *const objv[]          // Argument strings
	    )
{
  DMATester *synctx = *(DMATester **) clientData;
  int stat ;
  // Get Arguments
  int addr;
  long data;
  stat = Tcl_GetIntFromObj(interp, objv[2], &addr);
  CheckStatus(stat);

  bool sent = synctx->read(addr, data);
  Tcl_Obj *r = Tcl_GetObjResult(interp);
  if (sent) {
    addTclList(interp, r, "%08x", data );
    stat = TCL_OK;
  }
  else {
    addTclList(interp, r, "Blocked");
    stat = TCL_ERROR;
  }

  return stat;
}


// dut write <addr> <data>
static int dut_write (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;

  int stat ;
  int addr;
  long data;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &addr);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[3], &data);
  CheckStatus(stat);

  bool ok = synctx->write(addr, data);
  if (ok) {
    addTclList( interp, r, "");
    stat = TCL_OK;
  } else {
    addTclList(interp, r, "Blocked");
    stat = TCL_ERROR;
  }

  return stat;
}

// dut fill <lo> <hi> <data> <incr>
static int dut_fill (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;
  int stat;
  int loaddr, wcnt;
  long data, incr;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &loaddr);
  CheckStatus(stat);
  stat = Tcl_GetIntFromObj(interp, objv[3], &wcnt);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[4], &data);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[5], &incr);
  CheckStatus(stat);

  bool ok = synctx->fill(loaddr, wcnt, data, incr);
  if (ok) {
    addTclList(interp,r,"");
    stat = TCL_OK;
  } else {
    addTclList(interp,r,"Blocked");
    stat = TCL_ERROR;
  }

  return stat;
}


// dut fill <lo> <hi>
static int dut_dump (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;

  int stat;
  int loaddr, wcnt;
  std::vector<long> dout;;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &loaddr);
  CheckStatus(stat);
  stat = Tcl_GetIntFromObj(interp, objv[3], &wcnt);
  CheckStatus(stat);

  bool ok = synctx->dump(loaddr, wcnt, dout);
  if (ok) {
    addTclList(interp, r, "%08x", loaddr);
    addTclList(interp, r, "%08x", dout);
    stat = TCL_OK;
  } else {
    addTclList(interp,r,"Blocked");
    stat = TCL_ERROR;
  }

  return stat;

}

// dut read <addr>
static int dut_readQ (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                     Tcl_Interp *interp,       // Current interpreter
                     int objc,                 // Number of arguments
                     Tcl_Obj *const objv[]          // Argument strings
	    )
{
  DMATester *synctx = *(DMATester **) clientData;
  int stat ;
  // Get Arguments
  int addr;
  stat = Tcl_GetIntFromObj(interp, objv[2], &addr);
  CheckStatus(stat);

  synctx->readQ(addr);
  Tcl_Obj *r = Tcl_GetObjResult(interp);
  addTclList(interp, r, "Queued: read");
  addTclList(interp, r, "0x%08x", addr);

  return stat;
}


// dut writeQ <addr> <data>
static int dut_writeQ (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;

  int stat ;
  int addr;
  long data;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &addr);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[3], &data);
  CheckStatus(stat);

  synctx->writeQ(addr, data);
  addTclList(interp, r, "Queued: write");
  addTclList(interp, r, "0x%08x", addr);
  addTclList(interp, r, "0x%08x", data);

  return stat;
}

// dut fill <lo> <hi> <data> <incr>
static int dut_fillQ (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;
  int stat = TCL_ERROR;
  int loaddr, wcnt;
  long data, incr;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &loaddr);
  CheckStatus(stat);
  stat = Tcl_GetIntFromObj(interp, objv[3], &wcnt);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[4], &data);
  CheckStatus(stat);
  stat = Tcl_GetLongFromObj(interp, objv[5], &incr);
  CheckStatus(stat);

  synctx->fillQ(loaddr, wcnt, data, incr);
  addTclList(interp, r, "Queued: fill");
  addTclList(interp, r, "0x%08x", loaddr);
  addTclList(interp, r, "%d", wcnt);
  addTclList(interp, r, "0x%08x", data);
  addTclList(interp, r, "0x%08x", incr);
  stat = TCL_OK;
  
  return stat;
}


// dut fill <lo> <hi>
static int dut_dumpQ (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                      Tcl_Interp *interp,       // Current interpreter
                      int objc,                 // Number of arguments
                      Tcl_Obj *const objv[]          // Argument strings
                      )
{
  DMATester *synctx = *(DMATester **) clientData;

  int stat;
  int loaddr, wcnt;
  std::vector<long> dout;;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  // Get arguments
  stat = Tcl_GetIntFromObj(interp, objv[2], &loaddr);
  CheckStatus(stat);
  stat = Tcl_GetIntFromObj(interp, objv[3], &wcnt);
  CheckStatus(stat);

  synctx->dumpQ(loaddr, wcnt);
  stat = TCL_OK;
  addTclList(interp, r, "Queued: dump");
  addTclList(interp, r, "0x%08x", loaddr);
  addTclList(interp, r, "%d", wcnt);

  return stat;
}

// responseQ
static int dut_responseQ (ClientData clientData,	// &(GlobalXactor.m_busmaster)
                          Tcl_Interp *interp,       // Current interpreter
                          int objc,                 // Number of arguments
                          Tcl_Obj *const objv[]          // Argument strings
                          )
{
  DMATester *synctx = *(DMATester **) clientData;
  Tcl_Obj *r = Tcl_GetObjResult(interp);

  std::vector<long> vdata;
  unsigned addr;
  bool stat = synctx->getResponseQ(addr, vdata);
  if (stat) {
    addTclList(interp, r, "0x%08x", (int) addr );
    addTclList(interp, r, "%08x", vdata );
  } else {
  }

  return TCL_OK;
}

