BUGZY.TXT Command Line Bug Tracker
==================================

A simple (and not yet extensible) shell script for managing bugs/features/enhancements and tasks.

Bugs have a unique persistent serial number. Each bug is written to a separate file with various fields
in the email header like format with title, description, severity, date_created, type, fix, comments,
log, status, etc.

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
    > `mv bugzy.sh ~/bin`

4. Move the config file to your home directory.

    > `mv bugzy.cfg ~/`

The bug files are created in a directory ".todos" inside TODO_DIR.

### Usage

Current operations include add, mod, edit (edit the file itself), delete, list, list by severity,
select (based on a key).

TO ADD MORE HERE.

Others
------

- Uses the excellent [todo.txt shell script](http://github.com/ginatrapani/todo.txt-cli) as a base.

- Original anaemic release by rkumar on 2009-11-08.
