package require Tk
package require Bluetcl
package require Iwidgets

namespace eval ::DMADemo {

    variable ChannelNames [list "SRC Addr" "DST Addr" "Count" "Enable"]
    variable ChannelIds   [list sa ea ct en]
    variable NumChannels  4
    #  
    variable MemInitial [list 0x100000 64 0xBE000000 0x1111]
    variable InitialValues [list \
                           [list 0x100000        0x200000 64 1] \
                           [list "0x200000 + 32" 0x100000 64 1] \
                           [list "0x200000 + 00" 0x100000 64 1] \
                           [list "0x300000 + 32" 0x100000 64 1] \
                           ]

    # Base address of DMA
    variable DMABase 0x10000
    #  difference of each channel address from base
    variable ChanOffset   0x100
    # register offsets
    variable ChanRegOffsets [list 0 8 4 12]
    variable ServiceInterval  200
    variable TextWin ""
    variable OutFile {}

proc mkDutControl { win } {

    set top $win.dut
    if { $top == "..dut" } { set top .dut }

    mkDMAConfigure $top

    return $top
}

proc sendMessage { msg } {
    variable TextWin
    $TextWin insert end "$msg\n"
    $TextWin yview end
}
proc puts { msg } {
    variable OutFile
    sendMessage $msg
    update
    ::puts $OutFile $msg
    #::puts $msg
}

proc mkDMAConfigure { win } {
    variable NumChannels
    variable TextWin
    variable OutFile

    ttk::frame $win
    mkDMAChannels $win.chans $NumChannels
    mkMemAccess $win.mem

    ttk::labelframe $win.tf -text "Messages"
    iwidgets::scrolledtext $win.tf.txt  -labelpos nw \
        -height 200 -width 300 \
        -textfont bscFixedFont
    pack $win.tf.txt -expand 1 -fill both
    set TextWin $win.tf.txt

    grid $win.chans -row 0 -column 0 -sticky ew
    grid $win.mem   -row 1 -column 0 -sticky ew
    grid $win.tf    -row 2 -column 0 -sticky ewns

    grid columnconfigure $win all -weight 1
    grid rowconfigure    $win 2   -weight 1


    set OutFile [open "dut_session.log" "w"]
    return $win

}
proc mkDMAChannels { win numC } {
    variable ChannelIds
    variable ChannelNames
    variable InitialValues

    ttk::labelframe $win -text "DMA Channel Configuration"

    set r 1
    foreach n $ChannelNames w $ChannelIds {
        ttk::label $win.$w -text $n -anchor e
        grid $win.$w -row $r -column 0 -sticky e
        incr r
    }

    for { set c 0 } { $c < $numC } { incr c } {
        set r 0
        ttk::label $win.c$c -text "Chan $c"
        grid $win.c$c -row 0 -column [expr $c + 1]
        incr r
        foreach w $ChannelIds {
            ttk::entry $win.${w}_$c -width 14 -font bscFixedFont -justify r
            $win.${w}_$c insert end [lindex $InitialValues $c $r-1]
            grid $win.${w}_$c -row $r -column [expr $c + 1] -sticky ew
            incr r
        }
        ttk::button $win.cfg_$c -text "Set" -width 14 \
            -command [namespace code "configureDMA $win $c $c"]
        grid $win.cfg_$c -row $r -column [expr $c + 1]
    }

    # Config all button,
    ttk::button $win.cfg -text "Configure All" \
        -command [namespace code "configureDMA $win 0 [expr $numC - 1]"]
    grid $win.cfg   -row $r -column [expr $numC + 1] -sticky s

    return $win
}

proc configureDMA { win chanlo chanhi} {
    variable ChannelIds
    variable DMABase
    variable ChanOffset
    variable ChanRegOffsets

    for { set c $chanlo } { $c <= $chanhi } { incr c } {
        foreach w $ChannelIds a $ChanRegOffsets {
            set d [$win.${w}_$c get]
            set d [expr $d]
            set realaddr [expr $DMABase + ($c * $ChanOffset) + $a]
            dutcmd writeQ $realaddr $d
        }
    }

}



############################################################
proc mkMemAccess { win } {
    variable MemInitial
    ttk::labelframe $win -text "Memory Access"
    ttk::label $win.a -text "Address/Count"
    ttk::label $win.d -text "Data/Incr"

    set entries [list al ah dd di]

    foreach e $entries ini $MemInitial {
        ttk::entry $win.$e -width 14 -font bscFixedFont  -justify r
        $win.$e insert end $ini
    }

    set buttons [list br bw bd bf]
    set bnames  [list "Read" "Write" "Dump" "Fill"]
    set bcmds   [list read write dump fill]
    foreach b $buttons n $bnames c $bcmds {
        ttk::button $win.$b -width 14 -text $n  -command [namespace code "but $win $c"]
    }

    set order [list \
                   [list a al ah br bd ] \
                   [list d dd di bw bf ]\
                  ]
    set r -1
    foreach rs $order {
        incr r
        set c -1
        foreach cs $rs {
            incr c
            grid $win.$cs -row $r -column $c
        }
    }


    return $win
}

proc but { win but } {
    set al [$win.al get]
    set al [expr $al]
    set ah [$win.ah get]
    set ah [expr $ah]
    set dd [$win.dd get]
    set dd [expr $dd]
    set di [$win.di get]
    set di [expr $di]
    switch $but {
        read { dutcmd readQ $al}
        write {dutcmd writeQ $al $dd}
        dump { dutcmd dumpQ $al $ah}
        fill { dutcmd fillQ $al $ah $dd $di}
        default {puts stderr "Unxpected button command: $but"}
    }
}

proc dutcmd { args } {
    set cmd [lindex $args 0]
    if { [catch "uplevel #1 bsdebug::dut $args" err] } {
        puts "Caught Error: on $args"
        puts " --> [join $err]"
        set err ""
    } else {
        if { $cmd != "responseQ" } {
            puts [join [concat $cmd $err]]
        }
    }
    return $err
}

proc serviceLoop {} {
    variable ServiceInterval
    set data [dutcmd responseQ]
    while {$data != "" } {
        formatDisplay $data
        set data [dutcmd responseQ]
    }
    after $ServiceInterval [namespace code serviceLoop]
}

proc formatDisplay { data } {
    lassign $data addr vdata
    while { $vdata != {} } {
        set vdata [lassign $vdata a b c d e f g h]
        puts [format "0x%08x : %s %s %s %s  %s %s %s %s" $addr $a $b $c $d $e $f $g $h]
        set addr [expr $addr + (4*8)]
    }
}

}


package provide DMADemo 1.0

## pack [DMADemo::mkDutControl .] -expand 1 -fill both
