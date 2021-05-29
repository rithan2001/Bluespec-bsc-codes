lappend auto_path .
package require BSDebug
package require ControlGui
package require ProbeGui

# Display the window

proc buildEmulationWin { {win .emu} } {
    if { $win != "." } {
        toplevel $win
    }
    wm title $win "Bluespec Emulation"
    wm geometry . 750x600
    set paned [ttk::panedwindow $win.paned -orient vertical]
    pack $paned -side top -expand yes -fill both -pady 2 -padx 2

    set c [ControlGui::mkEmulationControlPanels $win]
    $paned add $c -weight 0

    set d [DMADemo::mkDutControl $win]
    $paned add $d -weight 1

#    set r [buildReadme $win]
#    $paned add $r -weight 1

#    set p [ProbeGui::mkProbePanel $win "scemi_test.vcd"]
#    $paned add $p -weight 1

    # start the status loop here
    after 500 ControlGui::statusLoop
#    after 500 ProbeGui::statusLoop
    after 500 DMADemo::serviceLoop
}

 
proc buildReadme { frame {filename "readme.txt"} } {
    set w [ttk::labelframe $frame.readme -text "Instructions" -relief ridge]
    set t [text $w.text -yscrollcommand [list $w.scroll set] -setgrid 1 \
               -height 15 -undo 1 -autosep 1]
    set sb [scrollbar $w.scroll -command [list $w.text yview]]

    pack $sb -side right -fill y
    pack $t -expand yes -fill both

    $t insert 0.0 [exec cat $filename]

    return $w
}
