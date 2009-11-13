BUGZY.TXT Command Line Bug Tracker
==================================

A simple (and not yet extensible) shell script for managing bugs/features/enhancements and tasks.

Bugs have a unique persistent serial number. Each bug is written to a separate file with various fields
in the email header like format with title, description, severity, date_created, type, fix, comments,
log, status, etc.

Mails are sent using the 'mail' command if specified.

Currently, it is very new, help is not documented, just wait a week or 3 before using.


Downloads
---------

<http://github.com/rkumar/bugzy.txt/downloads>

User Documentation
------------------

### Installation

1. Download the latest release from <http://github.com/rkumar/bugzy.txt/downloads>

2. Edit the bugzy.cfg and update the TODO_DIR to whereever your bug files should be created.

3. Make the bugzy.sh file executable, and place it in your PATH.

    > `chmod +x bugzy.sh`  
    > `mv bugzy.sh ~/bin/bugzy`

4. Move the config file to your home directory.

    > `mv bugzy.cfg ~/`

The bug files are created in a directory ".todos" inside TODO_DIR.

### Usage

Current operations include add, mod, edit (edit the file itself), delete, list, list by severity,
select (based on a key), show.

Actions to directly change status are open, started, closed, canceled, stopped or the first 3 letter of each.

"selectm" or "selm" is a multiple criteria search as:

   > bugzy selectm "type: bug" "status: open" ...  

   > bugzy selectm "type=bug" "status=(open|started)" "severity=critical"  


"pri" adds a priority to as task or bug, which results in a change in color, and having it 
sorted above. "depri" removes priority.

"liststat" lists tasks for a given status (|open|closed|started|stopped|canceled|).

"longlist" (or "ll" field1 field2 ... (lists the given fields for all tasks)

Bugs displayed may be restricted to some numbers using the "-i" flag.
e.g.

    b -i '106 107 109 110}' longlist
    b -i '{106..118}' ll
    b -v -i '!(106)' ll

The above example relies on shell expansion, if supported by your shell.

"show" item#
  
   b show 106    # shows the bug 106, with colors 
   b -p show 106  # show the bug in plain (no colors)

"viewlog" item#

  b log 108  # displays logs of 108

"viewcomment" item#    # view comments for a item

"addcomment" item#    # add a comment


TO ADD MORE HERE.

You may also alias bugzy to "b" in ~/.bashrc or equivalent.

    > alias b='bugzy -d ~/bugzy.cfg'  
    > b add "Module aaa crashes on startup"  
    > b list  
    > b mod 1  
    > b start 1  
    > b cancel 1  
    > b close 1  
    > b show  
    > b add "Module bbb crashes on startup"  
    > b pri 2 A  
    > b  
    > b depri 2  
    > b  

 

Others
------

- Uses the excellent [todo.txt shell script](http://github.com/ginatrapani/todo.txt-cli) as a base.

- Original anaemic release by rkumar on 2009-11-08.
