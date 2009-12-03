BUGZY.TXT Command Line Bug Tracker
==================================

A simple, extensible shell script (bash) for managing
bugs/features/enhancements and tasks.

Maintains summary, description, create_date, scheduled start date, due_date, severity, type,
priority, assigned to, multiple comments, fix/resolution, various statuses.

All modifications are logged.
Mails are sent using the 'mail' command if specified.

Downloads
---------

<http://github.com/rkumar/bugzy.txt/downloads>

User Documentation
------------------

### Installation

1. Download the latest release from <http://github.com/rkumar/bugzy.txt/downloads>

2. Edit the bugzy.cfg and update the TSV_DIR to whereever your bug files should be created.

3. Make the bugzy.sh file executable, and place it in your PATH.

    > `chmod +x bugzy.sh`  
    > `mv bugzy.sh ~/bin/bugzy`

4. Move the config file to your home directory.

    > `mv bugzy.cfg ~/`

The bug files are created in a directory ".todos" inside TSV_DIR.

Add-ons may be placed in $HOME/.bugzy.actions.d (default).

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

Current operations include **add**, **mod**, **delete**, **list**, list by severity,
show / print, tag, **quick**/q (listing), grep, **qadd** (quick add) and
various listings.

When adding an issue, entry of fields can be reduced by adding a default
in the config file, and setting PROMPT to NO. When entering due_date, a
value such as "+3" or "tomorrow" may be entered (provided your
version of `date` can do the conversion.

You can add an issue with only a title using  `qadd`. Defaults will be
used for other fields, or can be passed on the command line (use help
option for examples).
 
`b qadd --type:bug --severity:cri --due_date:2009-12-26 "a title"`

Actions to directly change status are open, started, closed, canceled,
stopped or the first 3 letter of each.


"pri" adds a priority to as task or bug, which results in a change in color, and having it 
sorted above. "depri" removes priority.

"liststat" lists tasks for a given status (|open|closed|started|stopped|canceled|).

"show" item#
  
    b show 106    # shows the bug 106, with colors 
    b -p show 106  # show the bug in plain (no colors)

"viewlog" item#

   `b log 108`  # displays logs of 108

"viewcomment" item#    # view comments for a item

"addcomment" item#    # add a comment

"fix" item#    # add a fix or resolution

"recentcomment" | "rc"  # view recent comments
"recentlog" | "rl"      # view recent logs

"delcomment" item# comment#            # delete comment from an item

"lbs"        # list by severity
        b lbs --fields:"1,3,4,7,8"   # display only given fields

"upcoming" | "upc"  [--start-date=true]
     list upcoming tasks based on due date (or optionally scheduled start date)

**Add-ons** include `mdel`, `mpri`, `mdepri` which do multiple deletes or
priority setting and unsetting.

TO ADD MORE HERE.

You may also alias bugzy to "b" in ~/.bashrc or equivalent.

     alias b='bugzy -d ~/bugzy.cfg'  
     b add "Module aaa crashes on startup"  
     b show
     b list  
     b mod 1 # user can select fields to modify 
     b start 1  
     b close --comment="some optional comment comes here" 1  
     b clo   --fix="resolved by ...." 1
     b show  
     b add "Module bbb crashes on startup" # user prompted for other fields 
     b pri 2 A  
     b  

     b depri 2  
     b q
     b q -CLO -CAN
     b q "(OPE|STA)"
     b status
     b grep crash
     b tag URG 1 2
     b grep @URG
     b liststat OPE
     b newest 5
     b recentlog
     b recentcomment
     b chpri 1 2 P2
     b chstart 1 2 +5
     b chstart 1 2 2009-12-25

     b -h     # short help
     b help   # longer help

 
Screenshots
-----------

[Quick report](http://i47.tinypic.com/6s4291.jpg)

Others
------

- Used the excellent [todo.txt shell script](http://github.com/ginatrapani/todo.txt-cli) as a base.

- Original *anaemic* release by rkumar on 2009-11-08.

/* vim: set tw=72: */
