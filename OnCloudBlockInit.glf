#################################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#################################################################################

#################################################################################
#
# OnCloudBlockInit.glf
#
# This Script is used to perform the following tasks:
#  *) Initialize all/selected unstructured blocks
#  *) Save a new Pointwise project file (if selected)
#  *) Compute examine metric(s) (if selected)
#  *) CAE export the current project (if selected)
#  *) Report final results to an external log file
#
#################################################################################

# Load Pointwise Glyph package
package require PWI_Glyph 3

if { ! [pw::Application isInteractive] } {
  puts "This script can only be run interactively"
  exit 1
}

# Load Tk package
pw::Script loadTk

# Widget hierarchy
set w(LabelTitle)                              .title
set w(MainFrame)                               .main

  set w(InitializeFrame)                         $w(MainFrame).finitialize
    set w(SelectionFrame)                          $w(InitializeFrame).fselection
      set w(SelectionListbox)                        $w(SelectionFrame).lselection
      set w(SelectionScrollbar)                      $w(SelectionFrame).sselection
      set w(SelectionButton)                         $w(SelectionFrame).bselection
    set w(OptionsFrame)                          $w(InitializeFrame).foptions
      set w(InitializeSelectionRadioButton)          $w(OptionsFrame).rbinitselection
      set w(InitializeAllRadioButton)                $w(OptionsFrame).rbinitall
      set w(InitializeNoneRadioButton)               $w(OptionsFrame).rbinitnone

  set w(SaveFrame)                               $w(MainFrame).fsave
    set w(SavePWFileCheckButton)                   $w(SaveFrame).checksavepwfile
    set w(ExportCAEFileCheckButton)                $w(SaveFrame).checkexportcaefile

  set w(AdvancedFrame)                           $w(MainFrame).fadvanced
    set w(FilesPathLabel)                          $w(AdvancedFrame).lfilespath
    set w(BrowseButton)                            $w(AdvancedFrame).bbrowse
    set w(BaseNameLabel)                           $w(AdvancedFrame).bnlabel
    set w(BaseNameEntry)                           $w(AdvancedFrame).bnentry
    set w(ExamineLabel)                            $w(AdvancedFrame).lexamine
    set w(ExamineMenu)                             $w(AdvancedFrame).mexamine
    set w(ExitCheckButton)                         $w(AdvancedFrame).checkexit

  set w(ButtonsFrame)                          .buttons
    set w(Logo)                                  $w(ButtonsFrame).logo
    set w(OkButton)                              $w(ButtonsFrame).bok
    set w(CancelButton)                          $w(ButtonsFrame).bcancel

  set w(MessageBlock)                          .msg

#################################################################################
# Define variables
#################################################################################

# Define dictionaries
set errorDict [dict create]
set solverDict [dict create]
set caeDict [dict create]
set examineDict [dict create]

# Define initial and default values
set opt(cwd) [file dirname [info script]]
set opt(fileChannel) ""
set opt(baseFileName) block_init_result
set opt(saveDirectory) $opt(cwd)
set opt(saveDirectoryDisplay) "Current Directory:\n"
set opt(initSelection) All
set opt(allBlocks) ""
set opt(selectedBlocks) ""
set opt(selectedBlocksNames) ""
set opt(prevHighlightSelection) ""
set opt(savePWFile) 1
set opt(exportCAEFile) 1
set opt(saveLogFile) 1
set opt(examineMetric) BlockNone
set opt(exitWhenComplete) 1
set opt(sleepMS) 5000
set opt(defDomainColor) #008F00
set opt(defColor) #00AAFF
set opt(defWidth) 1
set opt(defColorMode) Automatic
set opt(defSelectColor) #FF7878
set opt(defSelectColorMode) Entity
set opt(defSelectWidth) 2
set opt(defListBoxStringWidth) 20

# Return a unique file name in the specified directory
proc uniqueFilePath { dir base { ext "" } } {
  if { $ext ne "" } { set ext .${ext} }
  set path [file join $dir ${base}${ext}]
  set ver 1
  while 1 {
    if { $ext eq "" && [catch { glob "${path}*" }] } {
      break
    } elseif { $ext ne "" && ! [file exists $path] } {
      break
    }
    incr ver
    set path [file join $dir ${base}_${ver}${ext}]
  }
  return $path
}

# Return a unique, non-existent directory path
proc uniqueDirPath { dir subdir } {
  set path [file join $dir $subdir]
  set ver 1
  while { [file exists $path] } {
    incr ver
    set path [file join $dir ${base}_${ver}]
  }
  return $path
}

#################################################################################
# Set the initial value for the initialization radio buttons
# (Selection, All, None)
#################################################################################
proc setInitCheckButtonValue { } {
  global opt

  # Clear selected blocks
  set opt(selectedBlocks) ""
  set opt(selectedBlocksNames) ""

  # Get current (unstructured) block selection
  set mask [pw::Display createSelectionMask -requireBlock {Unstructured}]
  pw::Display getSelectedEntities -selectionmask $mask selectionArray

  foreach blk $selectionArray(Blocks) {
    if {[$blk isOfType "pw::BlockUnstructured"]} {
      lappend opt(selectedBlocks) $blk
      lappend opt(selectedBlocksNames) [$blk getName]
    }
  }
  if {[llength $opt(selectedBlocks)] > 0} {
    set opt(initSelection) Selected
    update
    return
  }

  if {[llength $opt(allBlocks)] > 0} {
    set opt(selectedBlocks) $opt(allBlocks)
    foreach blk $opt(allBlocks) {
      lappend opt(selectedBlocksNames) [$blk getName]
    }
    set opt(initSelection) All
    update
    return
  }

  puts "\n<a style=\"color:red; font-weight:bold\">ERROR:</a>\
    <a style=\"color:red;\">There are no unstructured blocks to initialize. Goodbye!</a>/n"
  exit 1
}

proc selectDirectory { } {
  global opt

  # Open file browser and select directory
  set opt(saveDirectory) [tk_chooseDirectory -initialdir $opt(saveDirectory) \
    -title "Select Directory:"]

  # Update directory display variable
  set opt(saveDirectoryDisplay) "Current Directory:  $opt(saveDirectory)"

  # Update
  update
}

#################################################################################
# Make window
#################################################################################
proc makeWindow { } {
  global w opt

  label $w(LabelTitle) -text "Initialize Block(s)"
  setTitleFont $w(LabelTitle)

  frame $w(MainFrame)

    labelframe $w(InitializeFrame) -text "Initialize Block(s)"
      frame $w(SelectionFrame)
        scrollbar $w(SelectionScrollbar) -command "$w(SelectionListbox) yview" -takefocus 0
        listbox $w(SelectionListbox) -yscrollcommand "$w(SelectionScrollbar) set" \
          -selectmode extended -exportselection false -takefocus 0 -height 8 \
          -font TkFixedFont
        button $w(SelectionButton) -text "Select Block(s)" -command { selectBlocks } -width 13
      frame $w(OptionsFrame)
        radiobutton $w(InitializeSelectionRadioButton) -text "Initialize Selected Block(s)" \
          -variable opt(initSelection) -value Selected
        radiobutton $w(InitializeAllRadioButton) -text "Initialize All Block(s)" \
          -variable opt(initSelection) -value All
        radiobutton $w(InitializeNoneRadioButton) -text "Don't Initialize Block(s)" \
          -variable opt(initSelection) -value None

    labelframe $w(SaveFrame) -text "Save/Export Options"
      checkbutton $w(SavePWFileCheckButton) -text "Save Pointwise File" -variable opt(savePWFile)
      checkbutton $w(ExportCAEFileCheckButton) -text "Export CAE File" -variable opt(exportCAEFile)

    labelframe $w(AdvancedFrame) -text "Advanced Options"
      label $w(FilesPathLabel) -text "Save File Directory:"
      button $w(BrowseButton) -text "Browse" -command { selectDirectory } -width 13
      label $w(BaseNameLabel) -text "Save File Base Name:"
      entry $w(BaseNameEntry) -width 30 -bd 2 -textvariable opt(baseFileName)
      label $w(ExamineLabel) -text "Examine Metric:"
      makeExamineMenu $w(ExamineMenu)
      checkbutton $w(ExitCheckButton) -text "Exit Pointwise when complete" -variable opt(exitWhenComplete)

  frame $w(ButtonsFrame)
    label $w(Logo) -image [cadenceLogo] -bd 0 -relief flat
    button $w(OkButton) -text "OK" -command { run } -width 10
    button $w(CancelButton) -text "Cancel" -command { exit 0 } -width 10

  message $w(MessageBlock) -textvariable opt(saveDirectoryDisplay) -background beige -bd 3 -relief sunken\
    -padx 5 -pady 5 -anchor w -justify left -width 300

  # Title label
  pack .title -side top -fill x -pady 5 -padx 5
  pack [frame .hr1 -bd 1 -height 2 -relief sunken] -fill x -padx 5 -pady 2

  # Main frame
  pack $w(MainFrame) -side top -fill both -expand 1

  # Initialize frame
  pack $w(InitializeFrame) -side top -fill both -pady 5 -padx 5 -expand 1
    pack $w(SelectionFrame) -side left -fill both -pady 5 -padx 5 -expand 1
      pack $w(SelectionButton) -side bottom -padx 5 -pady 5
      pack $w(SelectionScrollbar) -side right -fill y
      pack $w(SelectionListbox) -fill both -side right -expand 1
      # Populate list
      $w(SelectionListbox) configure -listvar opt(selectedBlocksNames)
      # Bind selection in listbox to block selection in script
      bind $w(SelectionListbox) <<ListboxSelect>> { highlightSelectedBlocks }

    pack $w(OptionsFrame) -side right -fill y -pady 5 -padx 5
      pack $w(InitializeSelectionRadioButton) -anchor w -pady 5 -padx 5
      pack $w(InitializeAllRadioButton) -anchor w -pady 5 -padx 5
      pack $w(InitializeNoneRadioButton) -anchor w -pady 5 -padx 5

  # Save frame
    pack $w(SaveFrame) -side left -fill y -pady 5 -padx 5
    pack $w(SavePWFileCheckButton) -anchor w -padx 5 -pady 5
    pack $w(ExportCAEFileCheckButton) -anchor w -padx 5 -pady 5

  # Advanced frame
  pack $w(AdvancedFrame) -side right -fill both -pady 5 -padx 5 -expand 1
    grid $w(FilesPathLabel) -row 0 -column 0 -padx 5 -pady 5 -sticky e
    grid $w(BrowseButton) -row 0 -column 1 -padx 5 -pady 5 -sticky w
    grid $w(BaseNameLabel) -row 1 -column 0 -padx 5 -pady 5 -sticky e
    grid $w(BaseNameEntry) -row 1 -column 1 -padx 5 -pady 5 -sticky ew
    grid $w(ExamineLabel) -row 2 -column 0 -padx 5 -pady 5 -sticky e
    grid $w(ExamineMenu) -row 2 -column 1 -padx 5 -pady 5 -sticky w
    grid $w(ExitCheckButton) -row 3 -column 0 -columnspan 2 -padx 5 -pady 5
    grid columnconfigure $w(AdvancedFrame) 1 -weight 1

  # Message blocks
  pack $w(MessageBlock) -side bottom -fill x -anchor s

  # Buttons and logo frame
  pack $w(ButtonsFrame) -side bottom -pady 10 -fill x
  pack $w(Logo) -side left -padx 10
  pack $w(CancelButton) -side right -padx 10
  pack $w(OkButton) -side right -padx 10

  bind . <Key-Escape>         { $w(CancelButton) invoke }
  bind . <Control-Key-Return> { $w(OkButton) invoke }

  # Main window & Widget set up
  setInitCheckButtonValue
  wm title . "Initialize Blocks"
  update
  wm deiconify .
}

#################################################################################
# Set the font for the input widget to be bold and 1.5 times larger than the
# default font
#################################################################################
proc setTitleFont { title } {
  if { ! [info exists titleFont] } {
    set fontSize [font actual TkCaptionFont -size]
    set titleFont [font create -family [font actual TkCaptionFont -family] \
        -weight bold -size [expr {int(1.5 * $fontSize)}]]
  }
  $title configure -font $titleFont
}

#################################################################################
# Make Examine Menu
#################################################################################
proc makeExamineMenu { frame } {
  global opt

  # Metrics only available with blocks
  foreach f [pw::Examine getFunctionNames] {
    if {0 == [string compare -length 5 $f "Block"]} {
      lappend opt(allMetrics) $f
    }
  }

  return [eval [concat tk_optionMenu $frame opt(examineMetric) $opt(allMetrics)]]
}

#################################################################################
# Sleep for N seconds
#################################################################################
proc sleep { } {
  global opt
  after $opt(sleepMS)
}

#################################################################################
# Interactively select unstructured blocks
#################################################################################

proc selectBlocks { } {
  global w opt

  # Iconify main window
  wm iconify .

  # Clear the current selection
  $w(SelectionListbox) selection clear 0 end
  highlightSelectedBlocks
  update

  # Clear selected blocks
  set opt(selectedBlocks) ""
  set opt(selectedBlocksNames) ""

  # Interactive selection
  set mask [pw::Display createSelectionMask -requireBlock {Unstructured}]
  pw::Display selectEntities -description "Select unstructured block(s) to initialize..." \
    -selectionmask $mask selectionArray

  set selectedBlocks $selectionArray(Blocks)
  if {[llength $selectedBlocks] > 0} {
    set opt(selectedBlocks) $selectedBlocks
    foreach blk $selectedBlocks {
      lappend opt(selectedBlocksNames) [$blk getName]
    }

    # Set value of Initialization Options radio buttons
    set opt(initSelection) Selected
    update
  } else {
   setInitCheckButtonValue
  }

  # Deiconify main window
  wm deiconify .
}

###############################################################################
# Helper function (list set difference)
###############################################################################
proc ldifference {a b} {
  set result {}
  foreach e $a {
    if {$e ni $b} {lappend result $e}
  }
  return $result
}

###############################################################################
#   - Determine user selected blocks from Gui listbox.
#   - Valid blocks from groups are added.
###############################################################################
proc getCurSelBlocks {} {
  global w opt

  set curSelIndexList [$w(SelectionListbox) curselection]
  set curSelBlocks {}

  foreach index $curSelIndexList {
    set curEnt [lindex $opt(selectedBlocks) $index]
    lappend curSelBlocks $curEnt
  }

  return $curSelBlocks
}

###############################################################################
# Get connectors used by a domain
###############################################################################
proc getConnectors { domain } {
  set conns [list]
  set edgeCount [$domain getEdgeCount]
  for {set i 1} {$i <= $edgeCount} {incr i} {
    set edge [$domain getEdge $i]
    set connectorCount [$edge getConnectorCount]
    for {set j 1} {$j <= $connectorCount} {incr j} {
      lappend conns [$edge getConnector $j]
    }
  }
  return $conns
}

###############################################################################
# Get domains used by a block
###############################################################################

proc getDomains { block } {
  set doms [list]
  set faceCount [$block getFaceCount]
  for {set i 1} {$i <= $faceCount} {incr i} {
    set face [$block getFace $i]
    set domainCount [$face getDomainCount]
    for {set j 1} {$j <= $domainCount} {incr j} {
      lappend doms [$face getDomain $j]
    }
  }
  return $doms
}

###############################################################################
# Using a block list, highlight all block connectors
###############################################################################
proc highlightBlockCons { blkList colorMode color width } {

  # Find all connectors that correspond to the blk list and highlight them.

  set conList {}
  set doms {}

  foreach blk $blkList {
    # Get the list of domains used by this block
    set domsList [getDomains $blk]

    foreach domain $domsList {
      # Get list of connectors used by those domains
      set consList [getConnectors $domain]
      foreach con $consList {
        $con setRenderAttribute ColorMode Entity
        $con setColor $color
        $con setRenderAttribute LineWidth $width
      }
    }
  }
}

###############################################################################
# Highlight selected blocks by changing render atts
###############################################################################
proc highlightSelectedBlocks { } {
  global opt

  # Current selection of blocks
  set selectedBlocks [getCurSelBlocks]
  set newBlocks [ldifference $selectedBlocks $opt(prevHighlightSelection)]
  set oldBlocks [ldifference $opt(prevHighlightSelection) $selectedBlocks]

  if {[llength $newBlocks] > 0 || [llength $oldBlocks] > 0} {
    # Reset old blocks to default Bfly script colors
    if {[llength $oldBlocks] > 0} {
      highlightBlockCons $oldBlocks $opt(defColorMode) $opt(defColor) $opt(defWidth)
    }

    # Set All selected blocks to default "selected" colors
    highlightBlockCons $selectedBlocks $opt(defSelectColorMode) $opt(defSelectColor) \
      $opt(defSelectWidth)

    # If changes were made, update the display and prev. selected blocks
    pw::Display update
    set opt(prevHighlightSelection) $selectedBlocks
  }
}

#################################################################################
# Compute the initialization time
#################################################################################
proc fmtDeltaTime { deltaTime {sufx ""} } {
  set h [expr "$deltaTime / 3600"]
  set deltaTime [expr "$deltaTime - ($h * 3600)"]
  set m [expr "$deltaTime / 60"]
  set deltaTime [expr "$deltaTime - ($m * 60)"]
  return [format "%02d:%02d:%02d%s" $h $m $deltaTime $sufx]
}

#################################################################################
# Close the file channel and exit Pointwise
#################################################################################
proc closeAndExit { } {
  global opt errorDict

  if {[dict size $errorDict] > 0 && $opt(saveLogFile) == 1} {
    # Open file channel
    set opt(fileChannel) [open [uniqueFilePath $opt(saveDirectory) $opt(baseFileName) "log"] w]

    # Build string
    puts $opt(fileChannel) [format "%s\n" [pw::Application getVersion]]

    # Error dictionary
    dict for {key value} $errorDict {
      puts $opt(fileChannel) "$key $value"
    }
    puts $opt(fileChannel) ""

    # Close the file channel
    if [catch {close $opt(fileChannel)} err] {
      puts [format "ERROR: Failed to close file %s. (%s)" [file join $opt(saveDirectory) $opt(logFileName)] $err]
    }
  }

  # Exit
  if {$opt(exitWhenComplete)} {
    # Exit Pointwise
    puts [format "Exiting Pointwise in %d seconds..." [expr int($opt(sleepMS))/1000]]
    update
    sleep
    pw::Application exit
  } else {
    # Exit the script
    update
    exit 0
  }
}

#################################################################################
# Run the unstructured solver
#################################################################################
proc runUnsSolver { } {
  global opt solverDict

  # Start timer
  set initTimeStart [clock seconds]

  set selectedBlocks $opt(selectedBlocks)
  if {$opt(initSelection) eq "All"} {
    set selectedBlocks $opt(allBlocks)
  }

  set UnsSolverMode [pw::Application begin UnstructuredSolver $selectedBlocks]
    $UnsSolverMode run Initialize
  $UnsSolverMode end

  # End timer
  set initTimeEnd [clock seconds]
  set deltaTime [expr "$initTimeEnd - $initTimeStart"]
  dict set solverDict "Unstructured Solver: " ""
  dict set solverDict "  Timing  : " "[fmtDeltaTime $deltaTime] h:m:s"
  puts [format "  Timing: %s (h:m:s)\n" [fmtDeltaTime $deltaTime]]

  return $solverDict
}

#################################################################################
# Capture the unstructured solver errors (if any)
#################################################################################
proc getSolverErrors { } {
  global opt solverDict

  foreach blk $opt(selectedBlocks) {
    set errCount [$blk getInitializationErrorCount]
    dict set errorDict $blk $errCount
    for {set i 1} {$i <= $errCount} {incr i} {
      dict set errorDict "  " [$blk getInitializationError -points $i]
      puts [format "  %s" [$blk getInitializationError -points $i]]
    }
  }
  # Close and exit
  closeAndExit
}

#################################################################################
# Compute the examine metrics for each bock
#################################################################################
proc getExamineMetrics { } {
  global opt examineDict

  # Start timer
  set initTimeStart [clock seconds]

  # Calculate examine metric
  set Examine [pw::Examine create $opt(examineMetric)]
    $Examine addEntity $opt(selectedBlocks)
    $Examine examine

    # Compute the examine metric
    dict set examineDict "Examine Metric : " $opt(examineMetric)

    # Compute the maximum extrema
    dict set examineDict "  Maximum : " [$Examine getMaximum]

    # Compute the minimum extrema
    dict set examineDict "  Minimum : " [$Examine getMinimum]

    # Compute the average
    dict set examineDict "  Average : " [$Examine getAverage]

  # Delete examine metric
  $Examine delete

  # End timer
  set initTimeEnd [clock seconds]
  set deltaTime [expr "$initTimeEnd - $initTimeStart"]
  dict set examineDict "  Timing  : " "[fmtDeltaTime $deltaTime] h:m:s"
  puts "  Timing: [fmtDeltaTime $deltaTime] h:m:s\n"

  # Return examine metric dictionary
  return $examineDict
}

#################################################################################
# cadenceLogo: get Cadence Design Systems logo
#################################################################################
proc cadenceLogo { } {
  set logoData {
R0lGODlhgAAYAPQfAI6MjDEtLlFOT8jHx7e2tv39/RYSE/Pz8+Tj46qoqHl3d+vq62ZjY/n4+NT
T0+gXJ/BhbN3d3fzk5vrJzR4aG3Fubz88PVxZWp2cnIOBgiIeH769vtjX2MLBwSMfIP///yH5BA
EAAB8AIf8LeG1wIGRhdGF4bXD/P3hwYWNrZXQgYmVnaW49Iu+7vyIgaWQ9Ilc1TTBNcENlaGlIe
nJlU3pOVGN6a2M5ZCI/PiA8eDp4bXBtdGEgeG1sbnM6eD0iYWRvYmU6bnM6bWV0YS8iIHg6eG1w
dGs9IkFkb2JlIFhNUCBDb3JlIDUuMC1jMDYxIDY0LjE0MDk0OSwgMjAxMC8xMi8wNy0xMDo1Nzo
wMSAgICAgICAgIj48cmRmOlJERiB4bWxuczpyZGY9Imh0dHA6Ly93d3cudy5vcmcvMTk5OS8wMi
8yMi1yZGYtc3ludGF4LW5zIyI+IDxyZGY6RGVzY3JpcHRpb24gcmY6YWJvdXQ9IiIg/3htbG5zO
nhtcE1NPSJodHRwOi8vbnMuYWRvYmUuY29tL3hhcC8xLjAvbW0vIiB4bWxuczpzdFJlZj0iaHR0
cDovL25zLmFkb2JlLmNvbS94YXAvMS4wL3NUcGUvUmVzb3VyY2VSZWYjIiB4bWxuczp4bXA9Imh
0dHA6Ly9ucy5hZG9iZS5jb20veGFwLzEuMC8iIHhtcE1NOk9yaWdpbmFsRG9jdW1lbnRJRD0idX
VpZDoxMEJEMkEwOThFODExMUREQTBBQzhBN0JCMEIxNUM4NyB4bXBNTTpEb2N1bWVudElEPSJ4b
XAuZGlkOkIxQjg3MzdFOEI4MTFFQjhEMv81ODVDQTZCRURDQzZBIiB4bXBNTTpJbnN0YW5jZUlE
PSJ4bXAuaWQ6QjFCODczNkZFOEI4MTFFQjhEMjU4NUNBNkJFRENDNkEiIHhtcDpDcmVhdG9yVG9
vbD0iQWRvYmUgSWxsdXN0cmF0b3IgQ0MgMjMuMSAoTWFjaW50b3NoKSI+IDx4bXBNTTpEZXJpZW
RGcm9tIHN0UmVmOmluc3RhbmNlSUQ9InhtcC5paWQ6MGE1NjBhMzgtOTJiMi00MjdmLWE4ZmQtM
jQ0NjMzNmNjMWI0IiBzdFJlZjpkb2N1bWVudElEPSJ4bXAuZGlkOjBhNTYwYTM4LTkyYjItNDL/
N2YtYThkLTI0NDYzMzZjYzFiNCIvPiA8L3JkZjpEZXNjcmlwdGlvbj4gPC9yZGY6UkRGPiA8L3g
6eG1wbWV0YT4gPD94cGFja2V0IGVuZD0iciI/PgH//v38+/r5+Pf29fTz8vHw7+7t7Ovp6Ofm5e
Tj4uHg397d3Nva2djX1tXU09LR0M/OzczLysnIx8bFxMPCwcC/vr28u7q5uLe2tbSzsrGwr66tr
KuqqainpqWko6KhoJ+enZybmpmYl5aVlJOSkZCPjo2Mi4qJiIeGhYSDgoGAf359fHt6eXh3dnV0
c3JxcG9ubWxramloZ2ZlZGNiYWBfXl1cW1pZWFdWVlVUU1JRUE9OTUxLSklIR0ZFRENCQUA/Pj0
8Ozo5ODc2NTQzMjEwLy4tLCsqKSgnJiUkIyIhIB8eHRwbGhkYFxYVFBMSERAPDg0MCwoJCAcGBQ
QDAgEAACwAAAAAgAAYAAAF/uAnjmQpTk+qqpLpvnAsz3RdFgOQHPa5/q1a4UAs9I7IZCmCISQwx
wlkSqUGaRsDxbBQer+zhKPSIYCVWQ33zG4PMINc+5j1rOf4ZCHRwSDyNXV3gIQ0BYcmBQ0NRjBD
CwuMhgcIPB0Gdl0xigcNMoegoT2KkpsNB40yDQkWGhoUES57Fga1FAyajhm1Bk2Ygy4RF1seCjw
vAwYBy8wBxjOzHq8OMA4CWwEAqS4LAVoUWwMul7wUah7HsheYrxQBHpkwWeAGagGeLg717eDE6S
4HaPUzYMYFBi211FzYRuJAAAp2AggwIM5ElgwJElyzowAGAUwQL7iCB4wEgnoU/hRgIJnhxUlpA
SxY8ADRQMsXDSxAdHetYIlkNDMAqJngxS47GESZ6DSiwDUNHvDd0KkhQJcIEOMlGkbhJlAK/0a8
NLDhUDdX914A+AWAkaJEOg0U/ZCgXgCGHxbAS4lXxketJcbO/aCgZi4SC34dK9CKoouxFT8cBNz
Q3K2+I/RVxXfAnIE/JTDUBC1k1S/SJATl+ltSxEcKAlJV2ALFBOTMp8f9ihVjLYUKTa8Z6GBCAF
rMN8Y8zPrZYL2oIy5RHrHr1qlOsw0AePwrsj47HFysrYpcBFcF1w8Mk2ti7wUaDRgg1EISNXVwF
lKpdsEAIj9zNAFnW3e4gecCV7Ft/qKTNP0A2Et7AUIj3ysARLDBaC7MRkF+I+x3wzA08SLiTYER
KMJ3BoR3wzUUvLdJAFBtIWIttZEQIwMzfEXNB2PZJ0J1HIrgIQkFILjBkUgSwFuJdnj3i4pEIlg
eY+Bc0AGSRxLg4zsblkcYODiK0KNzUEk1JAkaCkjDbSc+maE5d20i3HY0zDbdh1vQyWNuJkjXnJ
C/HDbCQeTVwOYHKEJJwmR/wlBYi16KMMBOHTnClZpjmpAYUh0GGoyJMxya6KcBlieIj7IsqB0ji
5iwyyu8ZboigKCd2RRVAUTQyBAugToqXDVhwKpUIxzgyoaacILMc5jQEtkIHLCjwQUMkxhnx5I/
seMBta3cKSk7BghQAQMeqMmkY20amA+zHtDiEwl10dRiBcPoacJr0qjx7Ai+yTjQvk31aws92JZ
Q1070mGsSQsS1uYWiJeDrCkGy+CZvnjFEUME7VaFaQAcXCCDyyBYA3NQGIY8ssgU7vqAxjB4EwA
DEIyxggQAsjxDBzRagKtbGaBXclAMMvNNuBaiGAAA7}

  return [image create photo -format GIF -data $logoData]
}

#################################################################################
# Run
#################################################################################
proc run { } {
  global opt solverDict caeDict examineDict

  wm iconify .

  # Set verbosity level
  catch {pw::Application setVerbosity Info}

  # Print current build
  puts [format "%s\n" [pw::Application getVersion]]

  # Run the unstructured solver
  if {$opt(initSelection) ne "None"} {
    puts "Initializing unstructured blocks..."
    if {[catch {runUnsSolver}]} {
      # Get solver errors (if any)
      getSolverErrors
    }
  }

  # Compute examine metric
  if {$opt(examineMetric) ne "BlockNone"} {
    puts [format "\nComputing %s examine metric..." $opt(examineMetric)]
    set examineDict [getExamineMetrics]

    # Print examine metrics
    if {$opt(examineMetric) ne "BlockNone" && [dict size $examineDict] > 0} {
      dict for {key value} $examineDict {
        puts [format "  %s %s" $key $value]
      }
    }
  }

  # Check path to save files
  if {$opt(savePWFile) eq 1 || $opt(exportCAEFile) eq 1 || $opt(saveLogFile) eq 1} {
    if {$opt(saveDirectory) eq ""} {
      set opt(saveDirectory) $opt(cwd)
      puts [format "\nDirectory path is empty. Saving files to '%s'" $opt(cwd)]
    } elseif {! [file writable $opt(saveDirectory)]} {
      set opt(saveDirectory) $opt(cwd)
      puts ""
      puts [format "\nDirectory is not writable. Saving files to '%s'" $opt(cwd)]
    }
  }

  # Save Pointwise project file
  if {$opt(savePWFile) == 1} {
    # Start timer
    set saveTimeStart [clock seconds]
    set pwDest [uniqueFilePath $opt(saveDirectory) "${opt(baseFileName)}_Initialized" "pw"]
    puts [format "\nSaving Pointwise file: '%s'" $pwDest]
    pw::Application save -compress 1 $pwDest

   # End timer
   set saveTimeEnd [clock seconds]
   set saveDeltaTime [expr "$saveTimeEnd - $saveTimeStart"]
   puts [format "  Timing: %s (h:m:s)" [fmtDeltaTime $saveDeltaTime]]
  }

  # CAE export
  if {$opt(exportCAEFile) == 1} {

    # Start timer
    set exportTimeStart [clock seconds]

    # Default extension
    set defExt [lindex [pw::Application getCAESolverAttribute FileExtensions] 0]

    # Export destination suitable for the current solver.
    set destType [pw::Application getCAESolverAttribute FileDestination]
    switch $destType {
      Filename { set caeDest [uniqueFilePath $opt(saveDirectory) "${opt(baseFileName)}_CAE" $defExt] }
      Basename { set caeDest [uniqueFilePath $opt(saveDirectory) "${opt(baseFileName)}_CAE"] }
      Folder   {
        set caeDest [uniqueDirPath $opt(saveDirectory) "${opt(baseFileName)}_CAE"]
        file mkdir $caeDest
      }
      default  { return -code error "Unexpected FileDestination value" }
    }
    puts [format "\nCAE export file: '%s'" $caeDest]

    set status abort
    set CAEMode [pw::Application begin CaeExport [pw::Entity sort $opt(allBlocks)]]
      if { [$CAEMode initialize -strict -type CAE $caeDest] } {
        # Set the FilePrecision attribute
        if { ![catch {$CAEMode setAttribute FilePrecision Double}] } {
          dict set caeDict "  File Precision:" "Double"
          puts "  File Precision: Double"
        }
        if { ![$CAEMode verify] } {
          puts {  $CAEMode verify failed!}
        } elseif { ![$CAEMode canWrite] } {
          puts {  $CAEMode canWrite failed!}
        } elseif { ![$CAEMode write] } {
          puts {  $CAEMode write failed!}
        } elseif { 0 != [llength [set caeDict [$CAEMode getForeignEntityCounts]]] } {

          # End timer
          set exportTimeEnd [clock seconds]
          set deltaTime [expr "$exportTimeEnd - $exportTimeStart"]
          puts [format "  Timing: %s (h:m:s)" [fmtDeltaTime $deltaTime]]

          # Add timing to the caeDict dictionary
          dict set caeDict "  Timing:" "[fmtDeltaTime $deltaTime] h:m:s"

          # Print entity counts reported by the exporter
          puts "  Number of grid entities exported:"
          dict for {key val} $caeDict {
            if {$key eq "  Timing:"} continue
            puts [format "  %-22.22s : %6.6s" $key $val]
          }
          set status end
        } else {
          # For some CAE solvers, the foreign entity count is zero even if the export succeeds

          # End timer
          set exportTimeEnd [clock seconds]
          set deltaTime [expr "$exportTimeEnd - $exportTimeStart"]
          puts [format "  Timing: %s (h:m:s)" [fmtDeltaTime $deltaTime]]

          # Add timing to the caeDict dictionary
          dict set caeDict "  Timing:" "[fmtDeltaTime $deltaTime] h:m:s\n"

          set status end
        }
      }
    $CAEMode $status
    if {$status eq "abort"} {
      puts "  CAE Export aborted!"
    }
    puts ""
  }

  # Print data to log file
  if {$opt(saveLogFile) == 1} {
    # Open file channel
    set opt(fileChannel) [open [uniqueFilePath $opt(saveDirectory) $opt(baseFileName) "log"] w]

    # Build string
    puts $opt(fileChannel) [format "%s\n" [pw::Application getVersion]]

    # Unstructured solver
    if {$opt(initSelection) ne "None" && [dict size $solverDict] > 0} {
      dict for {key value} $solverDict {
        puts $opt(fileChannel) [format "%s %s" $key $value]
      }
      puts $opt(fileChannel) ""
    }

    # Examine metric
    if {$opt(examineMetric) ne "BlockNone" && [dict size $examineDict] > 0} {
      dict for {key value} $examineDict {
        puts $opt(fileChannel) [format "%s %s" $key $value]
      }
      puts $opt(fileChannel) ""
    }

    # Save Pointwise file
    if {$opt(savePWFile) eq 1} {
      puts $opt(fileChannel) "Pointwise File:"
      puts $opt(fileChannel) [format "  Destination: %s" $pwDest]
      puts $opt(fileChannel) [format "  Timing: %s (h:m:s)" [fmtDeltaTime $saveDeltaTime]]
    }

    # CAE export
    if {$opt(exportCAEFile) == 1} {
      puts $opt(fileChannel) "CAE Export:"
      puts $opt(fileChannel) [format "  Destination: %s" $caeDest]
      if [dict exists $caeDict "  Timing:"] {
        puts $opt(fileChannel) [format "  Timing: %s" [dict get $caeDict {  Timing:}]]
      }
      if {$status ne "abort" && [dict size $caeDict] > 0} {
        set fmt { %-22.22s : %6.6s }
        puts $opt(fileChannel) "  Number of grid entities exported:"
        dict for {key val} $caeDict {
          if {$key eq "  Timing:"} continue
          puts $opt(fileChannel) [format "  %-22.22s : %6.6s" $key $val]
        }
      } elseif {$status eq "abort"} {
        puts $opt(fileChannel) "  CAE Export aborted!"
      }
    }

    # Close the file channel
    if {[catch {close $opt(fileChannel)} err]} {
      puts [format "ERROR: Failed to close file '%s'. (%s)" [file join $opt(saveDirectory) $opt(logFileName)] $err]
    }
  }

  # Close file channel and exit Pointwise
  closeAndExit
}

#################################################################################
# Main script body
#################################################################################

# Determine current working directory
if {[file isdirectory [file join C:/ temp]]} {
  set opt(saveDirectory) [file join C:/ temp]
} elseif {[file isdirectory [file join C:/ data]]} {
  set opt(saveDirectory) [file join C:/ data]
} else {
  set opt(saveDirectory dirname [info script]]
}
set opt(saveDirectoryDisplay) "Current Directory:  $opt(saveDirectory)"

# Get all unstructured blocks
set opt(allBlocks) [pw::Grid getAll -type "pw::BlockUnstructured"]

# Make the window
makeWindow

#
# END SCRIPT
#

################################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
################################################################################
