OnCloud Block Initialization
============================

Copyright 2021 Cadence Design Systems, Inc. All rights reserved worldwide.

This Glyph script can be used to initiate a sequence of steps to initialize one
or more blocks in an unattended manner, save the results, and exit Pointwise.
This is useful in the Cadence Design Systems, Inc. *OnCloud* environment where
the system monitor can automatically shut down a virtual machine as soon as the
meshing process is complete, whether the user is actively connected or not. The
following steps can be performed:

-  Initialize all or a selected set of unstructured blocks

-  Compute an Examine metric (optional).

-  Save a Pointwise project file with the final grid

-  Export the final grid in the CAE format corresponding to the currently
   selected CAE solver

-  Save a log file with relevant timing, examine extrema values, and exported
   cell count information

-  Close Pointwise after the entire process has finished

.. image:: https://raw.github.com/pointwise/OnCloudBlockInit/master/tk.png

Usage
-----

By default, this script will initialize all unstructured blocks, save the
Pointwise project file, export to the selected CAE solver format, and exit
Pointwise. The default file location is C:\temp, but can be configured.

Options:

- The block(s) to be initialized can be selected using the *Select Block(s) button*,
  and are displayed in the list. Selecting a block in the list will highlight
  it in the display window for reference. If all blocks are already initialized
  and only CAE export is desired, select the *Don't Initialize Blocks*
  option.

- The results can be saved in a new project file in the selected directory
  with the name specified in *Save File Base Name*. To skip saving the
  project file, uncheck *Save Pointwise File*. The file name is ensured
  to be unique so that previous results will not be overwritten.

- The results can be exported to the selected solver file format in the
  selected directory using the name in the *Save File Base Name*. To skip
  CAE export, uncheck *Export CAE File*. The file name is ensured to
  be unique so that previous results will not be overwritten. CAE formats
  that write multiple files will use the given base name. CAE formats
  that write to a directory will use the given base name as the sub-directory
  name.

- The file/export base directory can be selected with the *Browse* button
  next to *Save File Directory*, and is displayed in the message area of
  the script window.

- The default base name is *block_init_result*, but can be changed by
  entering the desired base name in the *Save File Base Name* field.

- An Examine metric can be evaluated and min/max/average values written
  to the log file by selecting from the *Examine Metric* menu.

- Pointwise will exit automatically unless the *Exit when Pointwise is complete*
  checkbox is unchecked.

The configured sequence will commence when *OK* is pressed. Processing can be
interrupted by pressing the *Interrupt Script* button in the main Pointwise
window.

Disclaimer
~~~~~~~~~~

This file is licensed under the Cadence Public License Version 1.0 (the
"License"), a copy of which is found in the LICENSE file, and is distributed
"AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, CADENCE DISCLAIMS
ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO ANY PARTY FOR ANY DAMAGES
ARISING OUT OF OR RELATING TO USE OF THIS FILE.

Please see the License for the full text of applicable terms.
