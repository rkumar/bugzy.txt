BUGZY.TXT Command Line Bug Tracker
==================================

A simple (and not yet extensible) shell script for managing
bugs/features/enhancements and tasks.

Bugs have a unique persistent serial number. I have moved from a single
issue per file (key: value) format, to a tab separated single file
format. The earlier file format is still created and updated till I
decide whether to knock it off altogether.

Mails are sent using the 'mail' command if specified.

I have moved to a tab separated format from key:value flat file.
however, the old files are still created i have not yet removed them,
since someone may like it that way.

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


### Dependencies

Unfortunately, some reports do require **GNU's date** (coreutils). In `add`, I have
coded so GNU will fail through to BSD then to perl, but there's a lot
of work to do the same for all date calcs. There is a big difference in
the options of GNU and BSD :-(.

If you use BSD date, pls install gnu's date as `gdate` and in bugzy.sh replace 
    DATE=$( date )
with
    DATE=$( gdate )

### Usage

Current operations include add, mod, delete, list, list by severity,
show, tag, quick/q (listing), grep, qadd (quick add).

When adding an issue, entry of fields can be reduced by adding a default
in the config file, and setting PROMPT to NO. When entering due_date, a
value such as "+3 days" or "tomorrow" may be entered (provided your
version of `date` can do the conversion.

You can add an issue with only a title using  `qadd`. Defaults will be
used for other fields, or can be passed on the command line (use help
option for examples).
 
`b qadd --type:bug --severity:cri --due_date:2009-12-26 "a title"`

Actions to directly change status are open, started, closed, canceled,
stopped or the first 3 letter of each.

"selectm" or "selm" is a multiple criteria search as:

   > bugzy selectm "type: bug" "status: open" ...  

   > bugzy selectm "type=bug" "status=(open|started)" "severity=critical"  


"pri" adds a priority to as task or bug, which results in a change in color, and having it 
sorted above. "depri" removes priority.

"liststat" lists tasks for a given status (|open|closed|started|stopped|canceled|).

The above example relies on shell expansion, if supported by your shell.

"show" item#
  
   b show 106    # shows the bug 106, with colors 
   b -p show 106  # show the bug in plain (no colors)

"viewlog" item#

  b log 108  # displays logs of 108

"viewcomment" item#    # view comments for a item

"addcomment" item#    # add a comment

"fix" item#    # add a fix or resolution


TO ADD MORE HERE.

You may also alias bugzy to "b" in ~/.bashrc or equivalent.

    > alias b='bugzy -d ~/bugzy.cfg'  
    > b add "Module aaa crashes on startup"  
    > b show
    > b list  
    > b mod 1  
    > b start 1  
    > b close 1  
    > b show  
    > b add "Module bbb crashes on startup"  
    > b pri 2 A  
    > b  

    > b depri 2  
    > b q
    > b status
    > b grep crash
    > b tag URG 1 2
    > b grep @URG
    > b liststat OPE
    > b newest 5

    > b -h
    > b help

 

Others
------

- Uses the excellent [todo.txt shell script](http://github.com/ginatrapani/todo.txt-cli) as a base.

- Original anaemic release by rkumar on 2009-11-08.
/* vim: set tw=72: */
