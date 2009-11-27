#!/bin/bash
#
# A simple file based bug tracker                       
#                                                       
# 2009-11-24 v0.1.12 - am removing old flat file creation
# rkumar                                                
# 
#
# TODO - entry of title, check for tab and replace with spaces
# TODO - how to view archived data
# CAUTION: we are putting priority at start of title, and tags *and* comment count at end.
#

#### --- cleanup code use at start ---- ####
TMP_FILE=${TMPDIR:-/tmp}/prog.$$
trap "rm -f $TMP_FILE.?; exit 1" 0 1 2 3 13 15
TSV_PROGNAME=$(basename "$0")
TODO_SH=$TSV_PROGNAME
#TODO_DIR="/Users/rahul/work/projects/rbcurse"
export TSV_PROGNAME
Date="2009-11-16"
TSV_DATE_FORMAT='+%Y-%m-%d %H:%M'
TSV_DUE_DATE_FORMAT='+%Y-%m-%d'
arg0=$(basename "$0")

TSV_FILE="data.tsv"
TSV_EXTRA_DATA_FILE="ext.txt"
TSV_ARCHIVE_FILE="archive.txt"
#TSV_TITLES_FILE="titles.tsv"
# what fields are we to prompt for in mod
TSV_EDITFIELDS="title description status severity type assigned_to due_date comment fix"
TSV_PRINTFIELDS="title id status severity type assigned_to date_created due_date"
TSV_PRETTY_PRINT=1
# should desc and comments be printed in "list" command
TSV_PRINT_DETAILS=0
TSV_OUTPUT_DELIMITER=" | "
TSV_NOW=`date "$TSV_DATE_FORMAT"`
TSV_NOW_SHORT=`date "$TSV_DUE_DATE_FORMAT"`
# input delimiter or IFS
export DELIM=$'\t'
export TSV_TITLE_OFFSET1=57 # with id - DONT USE
## This is the field offset for title if using cut -f
export TSV_TITLE_COLUMN=8
#export TSV_TITLE_OFFSET2=63 # without the id
TSV_CREATE_FLAT_FILE=0
TSV_WRITE_FLAT_FILE=0
TSV_TXT_FORCE=0
TSV_ADD_COMMENT_COUNT_TO_TITLE=1
#ext=${1:-"default value"}
#today=$(date +"%Y-%m-%d-%H%M")

#TSV_DEFAULT_ACTION="list" # this should be in a CFG file not here.
oneline_usage="$TSV_PROGNAME [-fhpantvV] [-d todo_config] action [task_number] [task_description]"
usage()
{   
    sed -e 's/^    //' <<EndUsage
    Usage: $oneline_usage
    Try '$TSV_PROGNAME -h' for more information.
EndUsage
    exit 1
}
shorthelp()
{
    sed -e 's/^    //' <<EndHelp
      Usage: $oneline_usage

      Operations:
        add|a "Fix calculation in +project @context"
        archive|ar
        comment|addcomment NUMBER
        #command [ACTIONS] TODO
        del|rm NUMBER 
        dp|depri NUMBER
        fix|addfix
        help
        modify|mod NUMBER
        pri|p NUMBER PRIORITY
        tag TAG ITEM1 ITEM1 ... ITEMn

        open|ope     NUMBER
        started|sta  NUMBER
        closed|clo   NUMBER
        canceled|can NUMBER
        stopped|sto  NUMBER
     
      Listings:
        list|ls [TERM...]
        grep REGEX
        lbs
        oldest [COUNT]
        newest [COUNT]
        quick|q
        show [NUMBER]
        status
        upcoming|upc 
        viewlog  NUMBER
        viewcomment NUMBER


      See "help" for more details.
EndHelp
    exit 0
}
help() # COMMAND: shows help
{
    sed -e 's/^    //' <<EndHelp
      Usage: $oneline_usage

      Actions:
        add "THING I NEED TO DO +project @context"
        a "THING I NEED TO DO +project @context"
          Adds THING I NEED TO DO to your data.tsv file on its own line.
          Project and context notation optional.
          Quotes optional.

        archive 
        ar 
          Moves closed and canceled items to archive.txt

        comment NUMBER [TEXT]
        addcomment NUMBER [TEXT]
          to add a comment to an item. If not given on command line, a multi-line comment
          will be prompted for.

        modify NUMBER
        mod NUMBER
          allows user to modify various fields of a bug

        del NUMBER [TERM]
        rm NUMBER [TERM]
          Deletes the item/bug/task

        depri NUMBER
        dp NUMBER
          Deprioritizes (removes the priority) from the item

        fix    NUMBER
        addfix NUMBER
          add a fix / resolution for given item

        grep REGEX
          uses egrep to run a regex search showing status and title sorted on status
          This searches the entire record using egrep and prints matches

        help
          Display this help message.

        list [-l] [TERM...]
        ls [-l] [TERM...]
          Displays all bug's that contain TERM(s) sorted by priority with line
          numbers.  If no TERM specified, lists all items.
          The -l option results in descriptions, comments and fix being printed also.

        newest N
            a quick report showing  newest <n> items added

        oldest N
            a quick report showing  oldest <n> items added

        listpri [PRIORITY]   TODO
        lsp [PRIORITY]
          Displays all items prioritized PRIORITY.
          If no PRIORITY specified, lists all prioritized items.

        listproj   TODO
        lsprj
          Lists all the projects that start with the + sign in todo.txt.

        pri NUMBER PRIORITY
        p NUMBER PRIORITY
          Adds PRIORITY to todo on line NUMBER.  If the item is already
          prioritized, replaces current priority with new PRIORITY.
          PRIORITY must be an uppercase letter between A and Z.

        show NUMBER
          shows an item, defaults to last

        lbs
          Lists bugs by severity.

        selectm "type: BUG" "status: OPE" ...
        selm "type=bug" "status=(open|started)" "severity=critical"
          A multiple criteria search.

        quick
        q
          Prints a list of titles with status on left.

        qadd TITLE
          (Quickly) add an item passing only title on command-line. All other values will be defaults

        qadd --type:bug --severity:cri --due_date:2009-12-26 "TITLE..."
          (Quickly) add an item passing only title on command-line. You may override defaults for
          type, severity, status and due_date as arguments. No spaces in -- commands.
          

        tag TAG item1 item1 ...
          Appends a tag to multiple items, prefixing the tag with @

        print NUMBER
          Prints details of given item

        open     NUMBER # means unstarted /new
        started  NUMBER # work has begun
        closed   NUMBER # fixed and closed
        canceled NUMBER # no work done. No fix. Rejected.
        stopped  NUMBER
          change status of given item/s. May also use first 3 characters

        clo --comment:"i am testing a comment from CL" 209
          change status and add a (related) comment at the same time.

        upcoming
        upc 
          shows upcoming tasks
          
        viewlog  NUMBER
        viewcomment NUMBER
           view comments for an item

        recentlog 
        rl
        list recent activity from logs

        recentcomments 
        rc
        list recent comments

EndHelp
if [ -d "$TSV_ACTIONS_DIR" ]
then
    echo ""
    for action in "$TSV_ACTIONS_DIR"/*
    do
        if [ -x "$action" ]
        then
            "$action" usage
        fi
    done
    echo ""
fi
    exit 1
}
die()
{
    echo "$*"
    exit 1
}
cleanup()
{
    [ -f "$TMP_FILE" ] && rm "$TMP_FILE"
    bak="$file.bak"
    [[ ! -z "$bak" && -f "$bak" ]] && rm "$bak"
    exit 0
}
oldask()
{
    select CHOICE in $CHOICES
    do
        echo "$CHOICE"
        return
    done
}


## presents choices to user
## allows user to press ENTER and puts default into reply.
## adds 'q' option to quit and returns "quit"
## set CHOICES with your choices, space separated
# pass $1 as prompt
# pass $2 as default value if user pressed enter
#CHOICES="bread butter jam cheese"
#ask "Please select your breakfast" "jam"
#echo "i got $ASKRESULT."
ask(){
    promptstring="$1"
    defaultval="$2"
    local mchoices=$( echo "$CHOICES" | tr '\n\t' '  ')
    while true
    do
        ASKRESULT=
        if [ ! -z "$promptstring" ];
        then
            defaultstring=""
            [ ! -z "$defaultval" ] && defaultstring="[$defaultval]"
            echo "${promptstring}${defaultstring}: "
        fi
        let ctr=1
        valid=" "
        OLDIFS="$IFS"
        for option in $mchoices
        do
            valid+=" $ctr "
            echo "$ctr) $option"
            let ctr+=1
        done
        IFS="$OLDIFS"
        echo "q) quit"
        #echo "valid is ($valid)"

        echo -n "? "
        read ASKRESULT
        ret=0
        [ -z "$ASKRESULT" ] && { ASKRESULT="$defaultval"; return; }
        [ "$ASKRESULT" == "q" ] && { ASKRESULT="quit"; return;}
        #[ $reply -gt 0 -a $reply -lt $ctr ] && { ret=1; }
        #echo "check ( $ASKRESULT ) in ($valid)"
        count=$(echo "$valid" | grep -c " $ASKRESULT ")
        #echo "count is $count"
        [ $count -eq 1 ] && { ASKRESULT=$( echo "$mchoices" | cut -d ' ' -f $ASKRESULT ); return;}
        if [ $ret -gt 0 ];
        then
            #echo "$ASKRESULT"
            break
        else
            echo "Invalid response $ASKRESULT"
        fi
    done
}
## XXX CAN ONLY BE USED GLOBALLY
## will NOT work in echo | while read LINE
## instead use for LINE in $( echo -e "$data" )
Hash_config_varname_prefix=__hash__

# Emulates:  hash[key]=value
#
# Params:
# 1 - hash
# 2 - key
# 3 - value
function hash_set {
    eval "${Hash_config_varname_prefix}${1}_${2}=\"${3}\""
}


# Emulates:  value=hash[key]
#
# Params:
# 1 - hash
# 2 - key
# 3 - value (name of global variable to set)
function hash_get_into {
    eval "$3=\"\$${Hash_config_varname_prefix}${1}_${2}\""
}


# Emulates:  echo ha[key]
#
# Params:
# 1 - hash
# 2 - key
# 3 - echo params (like -n, for example)
function hash_echo {
    eval "echo $3 \"\$${Hash_config_varname_prefix}${1}_${2}\""
}
# Emulates something similar to:
#   foreach($hash as $key => $value) { fun($key,$value); }
#
# It is possible to write different variations of this function.
# Here we use a function call to make it as "generic" as possible.
#
# Params:
# 1 - hash
# 2 - function name
function hash_foreach {
  local keyname oldIFS="$IFS"
  IFS=' '
  for i in $(eval "echo \${!${Hash_config_varname_prefix}${1}_*}"); do
    keyname=$(eval "echo \${i##${Hash_config_varname_prefix}${1}_}")
    eval "$2 $keyname \"\$$i\""
  done
IFS="$oldIFS"
}

hash_set "VALUES" "status" "open started closed stopped canceled "
hash_set "VALUES" "severity" "normal critical moderate"
hash_set "VALUES" "type" "bug feature enhancement task"
hash_set "TSVVALUES" "status" "OPE STA CLO STO CAN"
hash_set "TSVVALUES" "severity" "NOR CRI MOD"
hash_set "TSVVALUES" "type" "BUG FEA ENH TAS"

# edits temporary file, remember to cleanup after
edit_tmpfile()
{
            mtime=`stat -c %Y $TMP_FILE`
            $EDITOR $TMP_FILE
            mtime2=`stat -c %Y $TMP_FILE`
            if [ $mtime2 -gt $mtime ] 
            then
                #echo "$? changed value is:"
                #cat $TMP_FILE
                RESULT=1
            else
                echo "editing cancelled"
                RESULT=0
            fi
            export RESULT
            # coul have just done expr $mtime2 - $mtime
}



shopt -s extglob
# this is the new list. earlier on is now oldlist
_list()
{
    ## Prefix the filter_command with the pre_filter_command
    filter_command="${pre_filter_command:-}"


    [ $TSV_VERBOSE_FLAG -gt 1 ] && echo "$arg0: list : $@"
    for search_term in "$@"
    do
    [ $TSV_VERBOSE_FLAG -gt 1 ] && echo "$arg0: search_term is $search_term "
        ## See if the first character of $search_term is a dash
        if [ ${search_term:0:1} == '=' ]
        then
            filter_command="${filter_command:-} ${filter_command:+|} \
            grep \"${search_term:1}\" "
        else
            if [ ${search_term:0:1} != '-' ]
            then
                ## First character isn't a dash: hide lines that don't match
                ## this $search_term
                filter_command="${filter_command:-} ${filter_command:+|} \
                grep -i \"$search_term\" "
            else
                ## First character is a dash: hide lines that match this
                ## $search_term
                #
                ## Remove the first character (-) before adding to our filter command
                filter_command="${filter_command:-} ${filter_command:+|} \
                grep -v -i \"${search_term:1}\" "
            fi
        fi
    done
    [ $TSV_VERBOSE_FLAG -gt 1 ] && echo "$arg0: filter_command is $filter_command "

    ## If post_filter_command is set, append it to the filter_command
    [ -n "$post_filter_command" ] && {
        filter_command="${filter_command:-}${filter_command:+ | }${post_filter_command:-}"
    }
    width=$( tput cols )
    let width-=3
        # cat "$TSV_FILE" \
    formatted_tsv_headers 
        items=$(
        cut -c1-$width "$TSV_FILE" \
        | eval ${TSV_SORT_COMMAND} \
          )
    if [ "${filter_command}" ]; then
        filtered_items=$(echo -ne "$items" | eval ${filter_command})
    else
        filtered_items=$items
    fi
    filtered_items=$(echo -ne "$filtered_items" | pretty_print)

    if [ "$TSV_PRINT_DETAILS" == "1" ]; then
        # while read row removes leading and trailing spaces !! FIXME
        #echo -e "$filtered_items" | while read row
        OLDIFS="$IFS"
        IFS=$'\n'
        for row in $( echo "$filtered_items" )
        do
            echo -ne "$row\n"
            # ugly attempt to remove ascii stuff from first row
            #rowitem=$( echo -e "$row" | cut -d $'|' -f1 | sed 's/....*m //;s/ $//' )
            rowitem=$( echo -e "$row" | cut -d $'|' -f1 )
            #     echo "1rowitem was ($rowitem)"
            #rowitem=${rowitem%% *} ## trim trailing blanks spaces
            rowitem=${rowitem// /}
            if [[ "$rowitem" = +([0-9]) ]]; then  
                get_extra_data $rowitem description | sed '1s/^/      Desc: /;2,$s/^/      >/g;'
                get_extra_data $rowitem comment     | sed '1s/^/      Comments: /;2,$s/^/      >/g;'
            else
                echo "rowitem was ($rowitem)"
            fi
        done
        IFS="$OLDIFS"
    else
        echo -ne "$filtered_items\n"
    fi

    if [ $TSV_VERBOSE_FLAG -gt 0 ]; then
        # pretty print has already shown headers
        NUMTASKS=$( echo -ne "$filtered_items" | sed -n '$ =' )
        #TOTALTASKS=$( echo -ne "$items" | sed -n '$ =' )
        # we can do ls +(0-9).txt but not sure how portable and requires extglob
        #TOTALTASKS=$( ls $ISSUES_DIR/*.txt | grep "[0-9]\+\.txt" | wc -l )
        # tsv stuff OLD above
        TOTALTASKS=$( grep -c . "$TSV_FILE" )

        # footer

        echo "--"
        #echo "${NUMTASKS:-0} of ${TOTALTASKS:-0} issues shown from $ISSUES_DIR"
        echo "${NUMTASKS:-0} of ${TOTALTASKS:-0} issues shown from $TSV_FILE"
        echo -ne "$filtered_items" | \
        cut -d '|' -f2 | awk  '{a[$1] ++} END{for (i in a) printf i": "a[i]"   "}' | \
        sed 's/CAN/canceled/;s/CLO/closed/;s/STO/stopped/;s/OPE/open/;s/STA/started/'

    fi
}
## logging of changes
## appended to end of file, so log should be last entry
## i could reverse append it after the log keyword
log_changes()
{
    local key=$1
    local oldvalue=$2
    local newline=$3
    local file=$4
    local dlim="~"
    #local now=`date "$TSV_DATE_FORMAT"`
    [ -z "$key" ] && die "key blank"
    [ -z "$oldvalue" ] && die "oldvalue blank"
    [ -z "$newline" ] && die "newline blank"
    #[ -z "$file" ] && die "flat file name blank"
    data="- LOG${dlim}$TSV_NOW${dlim}$key${dlim}$oldvalue${dlim}$newline"
    # combined file, log in another file ?
    echo "$item:log:$data" >> "$TSV_EXTRA_DATA_FILE"
    [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && echo "$data" >> $file

}
log_changes1()
{
    local key=$1
    local logtext="$2"
    #local oldvalue=$2
    #local newline=$3
    #local file=$4
    local dlim="~"
    TSV_NOW=`date "$TSV_DATE_FORMAT"`
    [ -z "$key" ] && die "key blank"
    #[ -z "$oldvalue" ] && die "oldvalue blank"
    #[ -z "$newline" ] && die "newline blank"
    #[ -z "$file" ] && die "flat file name blank"
    #data="- LOG${dlim}$TSV_NOW${dlim}$key${dlim}$oldvalue${dlim}$newline"
    data=$( echo -en "$logtext" | tr '\n' ' ')
    # combined file, log in another file ?
    echo "$item:log:$key:$TSV_NOW${dlim}$data" >> "$TSV_EXTRA_DATA_FILE"
    [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && echo "$data" >> $file

}
## get_code "type"
get_code()
{
    RESULT=
    CHOICES=`hash_echo "VALUES" "$1"`
    #echo "select a value for $1"
    ps="select a value for $1"
    #[ ! -z "$2" ] && echo "[default is $2]"
    #defaultval=${2:-"---"}
    defaultval="$2"
    if [ ! -z "${CHOICES}" ] 
    then
        #local input=`oldask` 
        ask "$ps" "$defaultval"
        echo "$ASKRESULT"
        RESULT=$ASKRESULT
    else
        echo "$defaultval"
        RESULT=$defaultval 
    fi
    RESULT=`convert_long_to_short_code $RESULT`
}

## get input from user, if user hits enter use default value
## get_input "username" "john"
## returns value in RESULT
get_input()
{
    local field=$1
    local defval="$2"
    local prompts=""
    local input
    
    [ ! -z defval ] && local prompts=" [default is $defval]"
    echo -n "Enter ${field}${prompts}: "
    read input
    [ -z "$input" ] && input="$defval"
    RESULT=$input
}


convert_due_date()
{
   local input="$1"
   local result
   if [ ${input:0:1} == '+' ];
   then
       input=${input:1}
       result=$(date --date "$input" "$TSV_DUE_DATE_FORMAT")
       result=$(date_calc "$input" "$TSV_DUE_DATE_FORMAT")
   else
       result=$input
   fi
   echo "$result"
}
## 
## option, prompt
## eaxmple:     process_quadoptions  "$SEND_EMAIL" "Send file by email?"
process_quadoptions()
{
    RESULT=""
    local input
    case "$1" in
        "yes" | "no" ) RESULT="$1";;
        "ask-yes" | "ask-no" ) 
        local yn=${1:4:1}
        local yesno=${1:4}
        local input
        while true 
        do
            echo -n "$2 y/n [default $yn]: "
            read input
            input=$(echo "$input" | tr "A-Z" "a-z")
            [[ -z "$input" || "${input:0:1}" == "$yn" ]] && input="$yesno"; break;
            local oppo_of_yn=$(echo "$yn" | tr "yn" "ny" )
            local oppo_of_yesno="yes"
            [ "$oppo_of_yn" == "n"] && oppo_of_yesno="no"
            [ "${input:0:1}" == "$oppo_of_yn" ] && input="$oppo_of_yesno"; break;
            loop
        done
        RESULT=$input
        ;;
    esac
}
# returns title for an item/task NEW TSV file
# just be careful that we  could change title and then show old value
tsv_get_title()
{
    item=${1:-$item}
    [ -z "$modified" -a  -z "$G_TITLE" -a $item == $saved_item ] && {
        echo "$G_TITLE"
        return 0
    }
    local mtitle=`tsv_get_rowdata $item | cut -f$TSV_TITLE_COLUMN `
    echo "$mtitle"
}
change_status()
{
    item=$1
    action=$2
    errmsg="usage: $TSV_PROGNAME $action task#"
    common_validation $1 "$errmsg"
    reply="status"; input="$action";
    oldvalue=`tsv_get_column_value $item $reply`
    #oldvalue=`get_value_for_id $item $reply`
    var=$( printf "%s" "${action:0:3}" | tr 'a-z' 'A-Z' )
    oldvaluelong=`convert_short_to_long_code "status" $oldvalue`
    [ "$oldvalue" == "$var" ] && die "$item is already $oldvalue ($oldvaluelong)"
    echo "$item is currently $oldvalue ($oldvaluelong)"
        newcode=`convert_long_to_short_code $input`
        newline="$reply: $newcode"
        #now=`date "$TSV_DATE_FORMAT"`
        [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
        # tsv stuff
        newcode=`convert_long_to_short_code $input`
        tsv_set_column_value $item $reply $newcode
        echo "$item is now $newcode ($input)"
        #log_changes $reply "$oldvalue" $newcode $file
        log_changes1 $reply "#$item $input"
        #mtitle=`get_title $item`
        mtitle=`tsv_get_title $item`
        [ ! -z "$EMAIL_TO" ] && echo "#$item changed from $oldvalue to $newcode" | mail -s "[$var] $mtitle" $EMAIL_TO
        #show_diffs 
        [ ! -z "$opt_comment" ] && {
        echo "Adding comment ($opt_comment) to $item"
            add_ml_comment "$opt_comment"
        }
}
## for actions that require a bug id
## sets item, file
## sets rowdata and lineno by calling tsv_get_rowdata...
## TODO set title and lineno in one shot, so we don't keep checking for it, maybe even other fields
common_validation()
{
    item=$1
    saved_item=$item
    # added paditem, so we don't need to keep doing it. 2009-11-20 19:37 
    paditem=$( printf "%4s" $item )
    shift
    local errmsg="$*"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    # OLD FILE STUFF
    #file=$ISSUES_DIR/${item}.txt
    #[ ! -r "$file" ] && die "No such file: $file"

    # tsv stuff
#    lineno=`tsv_lineno $item`
 ## sets rowdata and lineno
    tsv_get_rowdata_with_lineno $item
    ## creates rowarr
    convert_row_to_array

    G_TITLE=${G_ROWARR[ $(( TSV_TITLE_COLUMN-1 )) ]}
    [ $lineno -lt 1 ] && die "No such item: $item"
#    [ $TSV_VERBOSE_FLAG -gt 0 ] && grep "^title:" $file
}

## when displaying in columnar, use what widths to pad
get_display_widths()
{
    field="$1"
    case "$field" in
        "title" ) RESULT=40;;
        "id" ) RESULT=5;;
        "status" ) RESULT=5;;
        "severity" ) RESULT=5;;
        "type" ) RESULT=5;;
        * ) RESULT=10;;
    esac
}

add_ml_comment(){
    RESULT=0 
    reply="comment"
    if [ $# -gt 0 ]; then
        input=$*
    else
                echo "Enter new comment (^D to end):"
                if which rlwrap > /dev/null; then 
                    input=$( rlwrap cat )
                else
                    input=`cat`
                fi
    fi
                #read input
                [ -z "$input" ] || {
                    #[ -z "$reply" ] && die "No section for $reply found in $file"
                    #now=`date "$DATE_FORMAT"`
                    pretext="- $TSV_NOW: "
                    #input has newlines
                    # make in format (3/16): meaning 3 lines, 16 chars
                    howmanylines=$( echo -e "$input" | wc -cl | tr -s ' ' | sed 's/^ /(/;s/$/)/;s# #/#')
                    loginput=$( echo "$input" | tr '\n' '' )
                    RESULT=1 
                    ## TODO this should move to update_extra_header
                    # for tsv file
                    pretext="$item:com:$pretext"
                    # C-a processing, adding
                    echo "${pretext}$loginput" >> "$TSV_EXTRA_DATA_FILE"  # this has control A's, so we can pull one line and subst ^A with nl.
[ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && {
pretext="- $TSV_NOW: "
text=$( echo "$input" | sed "1s/^/$pretext/g" | sed '2,$s/^/                    \>/g' )
start=$(sed -n "/^$reply:/=" $file)
ex - $file<<!
${start}a
$text
.
x
!
}
        #log_changes "$reply" "$reply added.${loginput:0:25} ..." "${#loginput} chars" "$file"
        log_changes1 "$reply" "$reply added $howmanylines.${loginput:0:40} ..." 
        echo "$reply added to $item"
        [ "$TSV_ADD_COMMENT_COUNT_TO_TITLE" -gt 0 ] && add_comment_count_to_title;
    
}
} # add_ml
add_comment_count_to_title(){
    count=$( grep -c "^$item:com:" "$TSV_EXTRA_DATA_FILE" )
    # tsv stuff
    oldvalue=$( tsv_get_column_value $item "title" )
    newvalue=$( echo "$oldvalue" | sed  -e "s/ ([0-9]*)$//" -e  "s/$/ ($count)/" )
#    echo "updating title to $newvalue"
    tsv_set_column_value $item "title" "$newvalue"
#    echo "updated title to $newvalue"
}
add_fix(){
    item=$1
    reply="fix"
    description=$( get_extra_data $item $reply )
    oldvalue=$description
    lines=$(echo "$description"  | wc -l)
    [ -z "$description" ] && {
        description=$(echo "");lines=0;
    }
    echo "$description" > $TMP_FILE
    edit_tmpfile
    [ $RESULT -gt 0 ] && {
        text=$(cat $TMP_FILE)
        howmanylines=$( echo -e "$text" | wc -cl | tr -s ' ' | sed 's/^ /(/;s/$/)/;s# #/#')
        update_extra_data $item $reply "$text"
        log_changes1 $reply "Fix added $howmanylines. ${text:0:40}..."
        let modified+=1
    }
}

## returns title column, all rows - unused ?
tsv_titles(){
        #cut -c$TSV_TITLE_OFFSET1- "$TSV_FILE" 
        cut -f$TSV_TITLE_COLUMN "$TSV_FILE" 
}
## print titles of CSV file
tsv_headers(){
    #sed '1q' "$TSV_FILE"
    echo "id	status	severity	type	assigned_to	date_created	due_date	title"
    #cat "$TSV_TITLES_FILE"
}
# gives formatter header for printing
# see pretty_print
formatted_tsv_headers(){
    echo "  Id |Statu|Sever|Type |Assigned To |Date Created|  Due Date  |     Title"
    echo "-----+-----+-----+-----+------------+------------+------------+-----------------------"
}
## color the given data
## please set USE_PRI before calling else it will use $PRI_A
color_line(){
    USE_PRI=${USE_PRI:-"$PRI_A"}
    idata=$( sed 's/\(.*\)/'$USE_PRI'\1'${DEFAULT}'/g;' )
    # the following works and is a longer alternative
#    idata=""
#    while read data
#    do
#        #idata+=${USE_PRI}" $data "${DEFAULT}"\n"
#        idata+='\n'$( echo -e ${USE_PRI}"$data"${DEFAULT} )
#    done
    echo -e  "$idata"
}

# returns a serial number based on a file
# can be used for programs requiring a running id
# copied from ~/bin/incr_id on 2009-11-16 17:56 
get_next_id(){
    local idfile=$ISSUES_DIR/unique_id
    [ -f "$idfile" ] || echo "0" > "$idfile"
    uniqueid=`cat $idfile`
    let nextid=$uniqueid+1
    echo "$nextid" > $idfile
    echo $uniqueid
}
## Some tsv generic functions
# takes fieldname, => index of column, starting 1 (for cut etc)
tsv_column_index(){
    [ $# -ne 1 ] && { echo "===== tsv_column_index ERROR one param required"; }
    # put in hash or function to make faster
    [ -z "$titles_arr" ] &&  titles_arr=( $( tsv_headers | tr '\t' ' ' ) )

    #echo `get_word_position "$1" "$titles"`
    index=$(indexOf $1  "${titles_arr[@]}" )
    index=$(( index+1 ))
    echo $index
}
# returns index in list, starting 0
indexOf() {
   local pattern=$1
   local index list
   shift

   list=("$@")
   for index in "${!list[@]}"
   do
       [[ ${list[index]} = $pattern ]] && {
           echo $index
           return 0
       }
   done

   echo -1
   return 1
}

# given a string space delimited, returns which position that word is.
# starts with 1, in "aa bb cc dd" aa is 1, bb is 2, cc 3
# typically to use with cut which has base 1
get_word_position(){
    word="$1"
    string="$2"
    let ctr=1
#    echo "word:$word. string:$string."
    for w in $string
    do
#        echo "comp ($w) ($word) ($ctr)"
        [ "$w" == "$word" ] && { echo $ctr; return; }
        let ctr+=1
    done
    echo -1;
}
## returns row for an item
# please validate item at top of program.
tsv_get_rowdata(){
    item="$1"
    paditem=$( printf "%4s" $item )
    rowdata=$( grep "^$paditem" "$TSV_FILE" )
    [ -z "$rowdata" ] && { echo "ERROR ITEMNO $1"; return 99;}
    echo "$rowdata"
}
## since this function is called with $() it is run in its own shell and lineno will not be 
## returned. Calling common_valida tion would have ppulated lineno, though
tsv_get_rowdata_with_lineno(){
    item="$1"
    paditem=$( printf "%4s" $item )
    rowdata=$( grep -n "^$paditem" "$TSV_FILE" )
    [ -z "$rowdata" ] && { echo "ERROR ITEMNO $1"; return 99;}
    #lineno=$( cut -d':' -f1 <<< "$rowdata" )
    #rowdata=$( cut -d':' -f2- <<< "$rowdata" )
    lineno=${rowdata%%:*}
    rowdata=${rowdata#*:}
    G_LINENO=$lineno
    G_ROWDATA=$rowdata
}

# returns value of column for an item and fieldname
# bombs when description or fix entered
tsv_get_column_value(){
    item="$1"
    field="$2"
    #echo "item:$item,field:$field."
    paditem=$( printf "%4s" $item )
    rowdata=$( grep "^$paditem" "$TSV_FILE" )
    [ -z "$rowdata" ] && { echo "ERROR ITEMNO $1"; return;}
    #echo "rowdata:$rowdata"
    index=`tsv_column_index "$field"`
    #echo "index:$index"
    [ $index -lt 0 ] && { echo "ERROR FIELDNAME $2"; return;}
    echo "$rowdata" | cut -d $'\t' -f $index
}
tsv_get_index_value(){
    item="$1"
    index="$2"
    #echo "item:$item,field:$field"
    paditem=$( printf "%4s" $item )
    rowdata=$( grep "^$paditem" "$TSV_FILE" )
    [ -z "$rowdata" ] && { echo "ERROR itemno $1"; return;}
    #echo "rowdata:$rowdata"
    echo "$rowdata" | cut -d $'\t' -f $index
}
## given an item, returns linenumber
## remove after deleting call from del. REDUNDANT TODO
tsv_lineno(){
    item="$1"
    paditem=$( printf "%4s" $item )
    lineno=$( grep -n "^$paditem" "$TSV_FILE" | cut -d':' -f1  )
    [ -z "$lineno" ] && { echo -1; return;}
    echo $lineno
}
## deletes row from tsv file ONLY
## Does not delete other files since update uses this.
tsv_delete_item(){
    item=$1
    RESULT=0
    [ $lineno -lt 1 ] && { echo "No such item:$item"; RESULT=-1; return;}
    #row=$( sed "$lineno!d" "$TSV_FILE" )
    row="$rowdata"
    #echo "row:$row"
    [ -z "$row" ] && { echo "row blank!"; return; }
    [ ! -d "$DELETED_DIR" ] && mkdir "$DELETED_DIR";
    echo "$row" >> "$TSV_FILE_DELETED"
    sed -i.bak "${lineno}d" "$TSV_FILE"
    [ $? -eq 0 ] && echo "Deleted $item."
    #moved back here on 2009-11-19 12:34 since update does not delete and should not
    tsv_delete_other_files $item
    [ $? -eq 0 ] && echo "Deleted other files for $item."
}
    
tsv_delete_other_files(){
    item=$1
    RESULT=0

    # delete files from here
    grep "^$item:" "$TSV_EXTRA_DATA_FILE" >> deleted.extra.txt
    sed -i.bak "/^$item:/d" "$TSV_EXTRA_DATA_FILE"
    return $?
}
## updates tsv row with data for given
# item, columnname, value
# -1 on errors
tsv_set_column_value(){
    item=$1
    columnname=$2
    newvalue="$3"
    row=$( tsv_get_rowdata $item )
    echo "row:$row, lineno: $lineno"
    [ -z "$row" ] && { echo "row blank!"; return; }
    position=`tsv_column_index "$columnname"`
    echo "position:$position"
    newrow=$( echo "$row" | tr '\t' '\n' | sed $position"s/.*/$newvalue/" | tr '\n' '\t' )
    res=$?
    if [ $res -ne 0 ];
    then
        echo "Some error in conversion, can't proceed with operation"
        return $res
    fi
    [ -z "$newrow" ] && { echo "conversion resulted in a blank, can't go on. Program error!"; return 99;}
    newrow=$( echo "$newrow" | sed "s/$DELIM$//" )
    # could use $o
    #var=$(echo ${var%\t})
    echo "newrow:$newrow"
    echo "lineno:$lineno"
    [ -z "$lineno" ] && die "Lineno number, cannot update record. Pls check why."
## CAUTION: if lineno is blank, will update / overwrite the last row !!
ex - "$TSV_FILE"<<!
${lineno}c
$newrow
.
x
!
}

## fix for convert old code to new
## first 3 chars, then capitalize
convert_long_to_short_code(){
    old="$1"
    echo ${old:0:3} | tr 'a-z' 'A-Z'
}
## convert the 3 digit code to longer
# use only for display and prompting, not storing
convert_short_to_long_code(){
    codecat=$1
    codeval=$2
    case $codecat in
        "status" )
        echo "$codeval" | sed 's/CAN/canceled/;s/CLO/closed/;s/STO/stopped/;s/OPE/open/;s/STA/started/'
        ;;
        "severity" )
        echo "$codeval" | sed 's/NOR/normal/;s/MOD/moderate/;s/CRI/critical/'
        ;;
        "type" )
        echo "$codeval" | sed 's/BUG/bug/;s/ENH/enhancement/;s/FEA/feature/'
        ;;
        * )
        echo "---"
        ;;
    esac
}
convert_row_to_array(){
    OLDIFS="$IFS"
    IFS=$'\t'
    G_ROWARR=( $(echo "$G_ROWDATA" ) )
    IFS="$OLDIFS"
}

## print out the item like it is in the file.
# i have removed coloring of the labels since we may mail the file.
# however the caller can color the labels.
# echo -e "`b print 143 | sed 's/^\([^:]*\):/'$YELLOW'\1:'$DEFAULT'/g' `"
print_item(){
    errmsg="usage: $TSV_PROGNAME $action task#"
    common_validation $1 $errmsg
    #item=$1
    ## create an array
    convert_row_to_array
    output=""
    for field in $( echo $TSV_PRINTFIELDS )
    do
        index=`tsv_column_index "$field"`
        #value=$( echo "$rowdata" | cut -d $'\t' -f $index )
        index=$(( index - 1 ))
        value="${G_ROWARR[$index]}"
        xxfile=$( printf "%-13s" "$field" )
        #row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
        row=$( echo -e "$xxfile: " )
        output+=$( echo -en "\n$row" )
        output+=$( echo "$value" )
    done
        # read up the files containing multiline data
        xfields="description fix comment log"
        for xfile in $xfields
        do
            description=$( get_extra_data $item $xfile )
            [ ! -z "$description" ] && { 
            xxfile=$( printf "%-13s" "$xfile" )
            row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
            output+=$( echo -e "\n$row\n" )
            output+="\n"
            # C-a processing
            # next line was indenting second comment too
            #output+=$( echo "$description" | tr '' '\n' | sed 's/^/  /g;2,$s/^/  /g'  )
            output+=$( echo "$description" |  sed 's/^/  /g;'  )
            #echo "$description" | tr '' '\n' | sed 's/^/  /g;2,$s/^/                    /g'
            output+="\n"
        }
        done
    echo -e "$output"
    #echo "index:$index"
    #paste  <(echo $TSV_PRINTFIELDS | tr ' ' '\n') <(echo "$rowdata" | tr '\t' '\n')
}
## given a date, calculates how much time from now (upcoming or overdue)
## If overdue, then says overdue.
calc_overdue()
{
    local due_date="$1"
    local currow=$( date --date="$due_date" +%s )
    local today=$( date +%s )
    let seconds=currow-today
    text=""
    if ((seconds < 0)); then abs=-1; text="overdue";  else abs=1; fi
    seconds=$seconds*$abs
    days=$((seconds / (3600*24) ))
    hours=$((seconds / 3600))
    seconds=$((seconds % 3600))
    minutes=$((seconds / 60))
    seconds=$((seconds % 60))

    [ $days -gt 0 ] && {  echo "$days days $text"; return; }
    [ $hours -gt 0 ] && {  echo "$hours hours $text"; return; }
    [ $minutes -gt 0 ] && {  echo "$minutes minutes $text"; return; }

    #echo "$days days $hours hour(s) $minutes minute(s) $seconds second(s)"
    #echo "$days days $hours hour(s) "
}

# removed the pesky id in titles, to colorize titles i am colorizing data after last tab
# \+ does not work in my sed, but works in gsed
pretty_print(){
    #tomorrow=`date --date="tomorrow" '+%Y-%m-%d'`
    tomorrow=$( date_calc +1 )

    #dayafter=`date --date="+2 days" '+%Y-%m-%d'`
    dayafter=$( date_calc +2 )
    if (( $TSV_PRETTY_PRINT > 0 ));
    then
        local data=$( sed -e "s/${DELIM}\(....-..-..\) ..:../$DELIM\1/g;" \
            -e  "s/${DELIM}CRI${DELIM}/${DELIM}${PRI_A}CRI${DEFAULT}${DELIM}/g" \
            -e  "s/${DELIM}MOD${DELIM}/${DELIM}${PRI_A}MOD${DEFAULT}${DELIM}/g" \
            -e  "/^....${DELIM}CLO${DELIM}/s/^ /x/g" \
            -e  "/^....${DELIM}CAN${DELIM}/s/^ /x/g" \
            -e  "/^....${DELIM}OPE${DELIM}/s/^ /_/g" \
            -e  "/${DELIM}${tomorrow}${DELIM}/s/\(.*\)${DELIM}\(.*\)$/\1${DELIM}${PRI_A}\2${DEFAULT}/g" \
            -e  "/${DELIM}${dayafter}${DELIM}/s/\(.*\)${DELIM}\(.*\)$/\1${DELIM}${PRI_B}\2${DEFAULT}/g" \
            -e  "s/${tomorrow}/${PRI_A}${tomorrow}${DEFAULT}/g" \
            -e  "s/${dayafter}/${PRI_B}${dayafter}${DEFAULT}/g" \
            -e "s/$DELIM/$TSV_OUTPUT_DELIMITER/g" 
            )
            echo -e "$data"
            tasks=$( echo -e "$data" | grep -c . )
            total_tasks=$( grep -c . "$TSV_FILE" )
:<<DUMMY
            echo "--"
            echo -n "$tasks of $total_tasks issues shown from "
            show_source
        echo -e "$data" | \
        cut -d '|' -f2 | awk  '{a[$1] ++} END{for (i in a) printf " %s: %2d ",i, a[i]}' | \
        sed 's/CAN/canceled/;s/CLO/closed/;s/STO/stopped/;s/OPE/open/;s/STA/started/'

        echo -e "$data" | \
        cut -d '|' -f4 | awk  '{b[$1] ++} END{for (i in b) printf " %s: %2d ",i, b[i]}' | \
        sed 's/ENH/enhancements/;s/FEA/features/;s/BUG/bugs/;s/TAS/tasks/;'
        echo
DUMMY
    fi
}
# return fields from extra file (comments, description, fix)
#  2009-11-19 12:48 
get_extra_data(){
    item=$1
    reply=$2 # field name

    # tsv stuff
    # combined file approach
    regex="^$item:${reply:0:3}" 
    description=$( grep "^$item:${reply:0:3}" "$TSV_EXTRA_DATA_FILE"  | cut -d: -f3- )
    if [ ! -z "$description" ]; then
        if [ $reply == "log" ]; then
            echo "$description" | sed 's/^[^:]*:/On /;s/~/, /1;' |  tr '' ' '
        else
            echo "$description" | tr '' '\n'
        fi
    fi
}

## updates the long descriptive fields such as description, fix
## only changes TSV file. 
update_extra_data(){
    item=$1
    reply=$2
    local text="$3"
    text=$( echo "$text" | tr '\n' '' )
    i_desc_pref=$( echo "$text" | sed "s/^/$item:${reply:0:3}:/g" )
    sed -i.bak "/^$item:${reply:0:3}:/d" "$TSV_EXTRA_DATA_FILE"
    echo "$i_desc_pref" >> "$TSV_EXTRA_DATA_FILE"
}

## colors data passed in based on priority
color_by_priority(){
    data=$(
         sed '''
                s/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g;
                s/\(.*(B).*\)/'$PRI_B'\1'$DEFAULT'/g;
                s/\(.*(C).*\)/'$PRI_C'\1'$DEFAULT'/g;
                s/\(.*([D-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g;
          '''                                                   
          )
          echo -e "$data"
          
}

## prints path of data file, erquired since you may have multiple
show_source(){
  echo $( pwd )/$TSV_FILE
}
## short header for reports with on Id and title
short_title(){
    echo "   Id | B |      Title                                   "
    echo "------+---+----------------------------------------------"
}

## first use gnu date format to  calc
## if fails use BSD style date
## pass only "+n" or "-n". do not pass days or months.
## e.g. $( date_calc +3 )
date_calc()
{
DATE=date
val=${1:-"+0"}
local my_format=${2:-'+%Y-%m-%d'}
[ "$val" == "tomorrow" ] && val="+1";
[ "$val" == "dayafter" ] && val="+2";
today=$(date "$my_format")
$DATE --date="$val days" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    result=$( $DATE --date="$val days" "$my_format" )
else
    $DATE -v "${val}d" > /dev/null 2>&1
    if [ $? -eq 0 ]; then
        result=$( $DATE -v "${val}d" "$my_format" )
    else
        result=$today
        # last ditch resort to perl
        result=$( perl -le 'my ($y, $m, $d)=(localtime(time + '$val'*86400))[5,4,3]; $y+=1900; $m++;print "$y-$m-$d"' )
    fi
fi
echo "$result"
}
## add function creates tsv format file
create_tsv_file()
{
    del=$DELIM
    ASSIGNED_TO=$( printf "%-10s" "$ASSIGNED_TO" )
    ASSIGNED_TO=${ASSIGNED_TO:0:10}
    short_type=$( echo "${i_type:0:1}" | tr 'a-z' 'A-Z' )
    serialid=`get_next_id`
    item=$serialid
    task="[$short_type #$serialid]"
    todo="$task $atitle" # now used only in mail subject
    tabtitle="[#$serialid] $atitle"
    #now=`date "$DATE_FORMAT"`
    tabstat=$( echo ${i_status:0:3} | tr "a-z" "A-Z" )
    tabseve=$( echo ${i_severity:0:3} | tr "a-z" "A-Z" )
    tabtype=$( echo ${i_type:0:3} | tr "a-z" "A-Z" )
    tabid=$( printf "%4s" "$serialid" )
    tabfields="$tabid${del}$tabstat${del}$tabseve${del}$tabtype${del}$ASSIGNED_TO${del}$TSV_NOW${del}$i_due_date${del}$atitle"
    echo "$tabfields" >> "$TSV_FILE"
    [ -d "$ISSUES_DIR" ] || mkdir "$ISSUES_DIR"
# stop creating those files
#      [ ! -z "$i_desc" ] && echo "$i_desc" > $serialid.description.txt
      # combined file approach
      [ ! -z "$i_desc" ] && {
          i_desc_pref=$( echo "$i_desc" | sed "s/^/$serialid:des:/g" )
          #echo "$serialid:des:$i_desc" >> "$TSV_EXTRA_DATA_FILE"
          echo "$i_desc_pref" >> "$TSV_EXTRA_DATA_FILE"
      }
      [ "$TSV_CREATE_FLAT_FILE" -gt 0 ] && create_flat_file
}
# we are no longer creating this.
# however we can use this to dump, or just remove in a while
create_flat_file()
{
    editfile=$ISSUES_DIR/${serialid}.txt
      ## CAUTION: programs that use this require one space aftr colon, don't reformat this
    sed -e 's/^    //' <<EndUsage >"$editfile"
    title: $atitle
    id: $serialid
    description:
                $i_desc
    date_created: $TSV_NOW
    status: $tabstat
    severity: $tabseve
    type: $tabtype
    assigned_to: $ASSIGNED_TO
    due_date: $i_due_date
    comment: 

    fix: 
    log:

EndUsage
}
getoptlong()
{
    ## check for -- settings, break into key and value
    ## no spaces, :  used to delimit key and value
    #echo "inside getoptl"
    shifted=0
    OPT_PREFIX=${OPT_PREFIX:-opt}
    while true
    do
        if [[ "${1:0:2}" == "--" ]]; then
            f=${1:2}
            val="${f#*:}"
            key="${f%:*}"
            # declare will be local when we move this to a function
            #declare i_${key}=$val
            # sorry, in this case we were setting i_ vars
            read ${OPT_PREFIX}_${key} <<< $val
            export ${OPT_PREFIX}_${key} 
            #echo " i_${key}=$val"
            ((shifted+=1))
            shift
        else
            break
        fi
    done
    export long params
    [ $shifted -gt 0 ] && export ${!opt_@}
    #what's left, if you want
    i_rest=$*
    # check shifted to see how much to shift
}
# show what the symbols are
# enh and fea and task are deliberately dot and comma so that bug stands out.
legend(){
    echo
    echo '(-) open/unstarted,  (@) started,  (x) closed.   (#)  bug,  (.) enh/feature, (,) task'
}
 

## ADD FUNCTIONS ABOVE
out=
file=
Dflag=
while getopts lhpvVf:o:D:d:i: flag
do
    case "$flag" in
        (h) shorthelp;;
        (V) echo "$arg0: version @REVISION@ ($Date) Author: rkumar"; exit 0;;
        (v) 
        : $(( TSV_VERBOSE_FLAG++ ))
        ;;
        (f) file="$OPTARG";;
        p )
        TSV_PLAIN=1
        ;;
        (o) out="$OPTARG";;
        (D) Dflag="$Dflag $OPTARG";;
        (l) TSV_PRINT_DETAILS=1;; # print desc and comments withing "list"
        d )
        TSV_CFG_FILE=$OPTARG
        ;;
        (i) 
        ;;
        (*) usage;;
    esac
done
shift $(($OPTIND - 1))

# defaults if not yet defined
TSV_VERBOSE_FLAG=${TSV_VERBOSE_FLAG:-1}
TSV_PLAIN=${TSV_PLAIN:-0}

# Export all TSV_* variables
export ${!TSV_@}

export NONE=''
export BLACK='\\033[0;30m'
export RED='\\033[0;31m'
export GREEN='\\033[0;32m'
export BROWN='\\033[0;33m'
export BLUE='\\033[0;34m'
export PURPLE='\\033[0;35m'
export CYAN='\\033[0;36m'
export LIGHT_GREY='\\033[0;37m'
export DARK_GREY='\\033[1;30m'
export LIGHT_RED='\\033[1;31m'
export LIGHT_GREEN='\\033[1;32m'
export YELLOW='\\033[1;33m'
export LIGHT_BLUE='\\033[1;34m'
export LIGHT_PURPLE='\\033[1;35m'
export LIGHT_CYAN='\\033[1;36m'
export WHITE='\\033[1;37m'
export DEFAULT='\\033[0m'

# Default priority->color map.
export PRI_A=$YELLOW        # color for A priority
export PRI_B=$GREEN         # color for B priority
export PRI_C=$CYAN    # color for C priority
export PRI_X=$WHITE         # color for rest of them
# OLD flat file
TSV_SORT_COMMAND=${TSV_SORT_COMMAND:-env LC_COLLATE=C sort -f -k3}
# for tsv (list cannot use tsv_titles since FILELIST is not used
#TSV_SORT_COMMAND=${TSV_SORT_COMMAND:-env LC_COLLATE=C sort -f -k2}
TSV_SORT_COMMAND=${TSV_SORT_COMMAND:-"env LC_COLLATE=C sort -t$'\t' -k7 -r"}
REG_ID="^...."
REG_STATUS="..."
REG_SEVERITY="..."
REG_TYPE="..."
REG_DUE_DATE=".\{10\}"
REG_DATE_CREATED=".\{16\}"
REG_ASSIGNED_TO=".\{10\}"


if [ -z "$TSV_ACTIONS_DIR" -o ! -d "$TSV_ACTIONS_DIR" ]
then
    TSV_ACTIONS_DIR="$HOME/.bugzy.actions.d"
    export TSV_ACTIONS_DIR
fi


[ -r "$TSV_CFG_FILE" ] || die "Fatal error: Cannot read configuration file $TSV_CFG_FILE"

. "$TSV_CFG_FILE"

ACTION=${1:-$TSV_DEFAULT_ACTION}

[ -z "$ACTION" ]    && usage
# added RK 2009-11-06 11:00 to save issues (see edit)
ISSUES_DIR=$TSV_DIR/.todos
DELETED_DIR="$ISSUES_DIR/deleted"
TSV_FILE_DELETED="$DELETED_DIR/deleted.tsv"

if [ $TSV_PLAIN = 1 ]; then
    PRI_A=$NONE
    PRI_B=$NONE
    PRI_C=$NONE
    PRI_X=$NONE
    DEFAULT=$NONE
fi
cd $ISSUES_DIR


# == HANDLE ACTION ==
action=$( printf "%s\n" "$ACTION" | tr 'A-Z' 'a-z' )
if [ "$action" == command ]
then
    ## Get rid of "command" from arguments list
    shift
    ## Reset action to new first argument
    action=$( printf "%s\n" "$1" | tr 'A-Z' 'a-z' )
elif [ -d "$TSV_ACTIONS_DIR" -a -x "$TSV_ACTIONS_DIR/$action" ]
then
    "$TSV_ACTIONS_DIR/$action" "$@"
    cleanup
fi

#action=$( printf "%s\n" "$1" | tr 'A-Z' 'a-z' )
shift
  # we should do this earlier so that custom progs also get these params XXX
    getoptlong "$@"
    shift $shifted
    # FUTURE one can check for opt_help or if --help passed and pass to another function which has detailed help
    #set | grep '^opt_'
case $action in
    "print" ) # COMMAND: print details of one item
    print_item $1
    ;;
"add" | "a") # COMMAND: add an item (bug/task/enhancement)
    if [[ -z "$1" ]]; then
        echo -n "Enter a short title/subject: "
        read atitle
    else
        atitle=$*
    fi
    #check title for newline at end, this could leave a blank line in file
    [ -z "$atitle" ] && die "Title required for bug"
    atitle=$( echo "$atitle" | tr -d '\n' )
    [ "$PROMPT_DESC" == "yes" ] && {
        echo "Enter a description (^D to exit): "
        #read i_desc
        if which rlwrap > /dev/null; then 
            i_desc=$( rlwrap cat )
        else
            i_desc=`cat`
        fi
    }
    i_type=${DEFAULT_TYPE:-"bug"}
    i_severity=${DEFAULT_SEVERITY:-"normal"}
    i_status=${DEFAULT_STATUS:-"open"}
    [ "$PROMPT_DEFAULT_TYPE" == "yes" ] && {
        #i_type=`get_code "type" "$DEFAULT_TYPE"`
        get_code "type" "$DEFAULT_TYPE"
        i_type=$RESULT
    }
    [ "$PROMPT_DEFAULT_SEVERITY" == "yes" ] && {
        get_code "severity" "$DEFAULT_SEVERITY"
        i_severity=$RESULT
    }
    [ "$PROMPT_DEFAULT_STATUS" == "yes" ] && {
        get_code "status" "$DEFAULT_STATUS"
        i_status=$RESULT
    }
    prompts=
    i_due_date=`convert_due_date "$DEFAULT_DUE_DATE"`
    [ "$PROMPT_DUE_DATE" == "yes" ] && {
        [ ! -z "$i_due_date" ] && prompts=" [default is $i_due_date]"
        echo "Enter a due date $prompts: "
        echo "(You may enter values like 'tomorrow' or '+3 days')"
        read due_date
        [[ ${due_date:0:1} == "+" ]] && conversion_done=1;
        [ ! -z "$due_date" ] && i_due_date=$( convert_due_date "$due_date" )
        if [[ $conversion_done == 1 ]];
        then
            echo "Due date converted to $i_due_date"
        fi
    }
    [  -z "$i_due_date" ] && i_due_date=" "
    i_due_date=$( printf "%-10s" "$i_due_date" )
    prompts=
    [ "$PROMPT_ASSIGNED_TO" == "yes" ] && {
        [ ! -z "$ASSIGNED_TO" ] && prompts=" [default is $ASSIGNED_TO]"
        echo -n "Enter assigned to (10 chars) $prompts: "
        read assigned_to
        [ ! -z "$assigned_to" ] && ASSIGNED_TO=$assigned_to
    }


    del=$DELIM
    create_tsv_file


    process_quadoptions  "$SEND_EMAIL" "Send file by email?"
    #[ $RESULT == "yes" ] && get_input "emailid" "$ASSIGNED_TO"
    [ "$RESULT" == "yes" ] && {
        get_input "emailid" "$EMAIL_TO"

        [ ! -z "$EMAIL_TO" ] && { 
            body=`PRI_A=$NONE;DEFAULT=$NONE;print_item $item`
            echo -e "$body" | mail -s "$todo" $EMAIL_TO
        }
    }
    echo "Created $serialid"
    cleanup;;

"del" | "rm") # COMMAND: delete an item
    errmsg="usage: $TSV_PROGNAME $action task#"
    item=$1
    common_validation $1 $errmsg
    mtitle=`tsv_get_title $item`
            if  [ $TSV_TXT_FORCE = 0 ]; then
                echo "Delete '$mtitle'?  (y/n)"
                read ANSWER
            else
                ANSWER="y"
            fi
            if [ "$ANSWER" = "y" ]; then
                body=`PRI_A=$NONE;DEFAULT=$NONE;print_item $item`
                [ ! -d "$DELETED_DIR" ] && mkdir "$DELETED_DIR";
                # tsv stuff
                tsv_delete_item $item
                [ ! -z "$EMAIL_TO" ] && echo -e "$body" | mail -s "[DEL] $mtitle" $EMAIL_TO
                [ $TSV_VERBOSE_FLAG -gt 0 ] && echo "Bugzy: '$mtitle' deleted."
                cleanup
            else
                echo "Bugzy: No tasks were deleted."
            fi

       ;;


"modify" | "mod") # COMMAND: modify fields of an item
    errmsg="usage: $TSV_PROGNAME $action task#"
    modified=0
    item=$1
    common_validation $1 $errmsg
    mtitle=`tsv_get_title $item`
    echo "Modifying item titled '$mtitle'"
    MAINCHOICES="$TSV_EDITFIELDS"
    while true
    do
        CHOICES="$MAINCHOICES"
    ask "Select field to edit"
    reply=$ASKRESULT
    [ "$reply" == "quit" ] && {
      [ $modified -gt 0 ] && {
      mtitle=`tsv_get_title $item`
      body=`PRI_A=$NONE;DEFAULT=$NONE;print_item $item`
        [ ! -z "$EMAIL_TO" ] && echo -e "$body" | mail -s "[MOD] $mtitle" $EMAIL_TO
        }
      break
    }
    echo "reply is ($reply)"
    # tsv stuff
    [ "$reply" != "description" -a "$reply" != "fix"  -a "$reply" != "comment" ] && {
    oldvalue=$( tsv_get_column_value $item $reply )
    }
    [ -z "$oldvalue" ] || echo "Select new $reply (old was \"$oldvalue\")"
    CHOICES=`hash_echo "VALUES" "$reply"`
    if [ ! -z "${CHOICES}" ] 
    then
        ask
        input=$ASKRESULT
        [ "$input" == "quit" ] && continue;
        longcode=`convert_short_to_long_code $reply $input`
        newcode=`convert_long_to_short_code $input` # not required now since its new code
        echo "input is $longcode ($newcode)"
        newline="$reply: $newcode" # for FLAT file
        TSV_NOW=`date "$TSV_DATE_FORMAT"`
        [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
        tsv_set_column_value $item $reply $newcode
        #log_changes $reply $oldvalue $newcode $file
        log_changes1 $reply "$reply changed from $oldvalue to $newcode"
        let modified+=1
        echo "$item modified ..."
        #show_diffs
    else
        case $reply in
            "title" )
                echo "$oldvalue" > $TMP_FILE
                edit_tmpfile
                [ $RESULT -gt 0 ] && {
                   text=$(cat $TMP_FILE)
                   tsv_set_column_value $item $reply "$text"
                   #log_changes $reply "${#oldvalue} chars" "${#text} chars" "$file"
                   log_changes1 $reply "$reply changed to ${text:0:40}..."
                   [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed -i.bak "/^$reply:/s/^.*$/$reply: $text/" $file
                   #show_diffs 
                   let modified+=1
                }
            ;;
            "comment" )
                #add_comment
                add_ml_comment 
                [ $RESULT -gt 0 ] && {
                    #show_diffs
                    let modified+=1
                }

                ;;
            "due_date" )
            read due_date
            [[ ${due_date:0:1} == "+" ]] && conversion_done=1;
            [ ! -z "$due_date" ] && { due_date=`convert_due_date "$due_date"`
            if [[ $conversion_done == 1 ]];
            then
                echo "Due date converted to $due_date"
            fi
            text="$due_date"
                   tsv_set_column_value $item "due_date" "$text"

                   #log_changes $reply "${oldvalue}" "${text}" "$file"
                   log_changes1 $reply "$reply changed from ${oldvalue} to ${text}"
                   [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed -i.bak "/^$reply:/s/^.*$/$reply: $text/" $file
                   #show_diffs 
                   let modified+=1
                }
            ;;
            "description" | "fix" )
                description=$( get_extra_data $item $reply )
                oldvalue="$description"
                lines=$(echo "$description"  | wc -l)
                [ -z "$description" ] && {
                description=$(echo "# remove this line");lines=0;
                }
                echo "$description" > $TMP_FILE
                edit_tmpfile
                [ $RESULT -gt 0 ] && {
                   text=$(cat $TMP_FILE)
                   # tsv stuff
                   update_extra_data $item $reply "$text"
                   [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && {
                   start=$(sed -n "/^$reply:/=" $file)
                   let end=$start+$lines
                   sed -i.bak "$start,${end}d" $file
ex - $file<<!
${start}i
$reply:
$text
.
x
!
}
        #log_changes $reply "${#oldvalue} chars" "${#text} chars" "$file"
        howmanylines=$( echo -e "$text" | wc -cl | tr -s ' ' | sed 's/^ /(/;s/$/)/;s# #/#')
        log_changes1 $reply "$reply changed $howmanylines. ${text:0:40}..."
                   let modified+=1

    #show_diffs $file $file.bak.1 
    #rm $file.bak.1
                }
                
                ;;
            esac


        # actually we need to let user edit existing value in editor
    fi
done # while true
       cleanup;;


"list" | "ls") # COMMAND: list use -l for details
       _list "$@"
       cleanup;;


"liststat" | "lists" ) #COMMAND: lists items for a given status 
    valid="|OPE|CLO|STA|STO|CAN|"
    errmsg="usage: $TSV_PROGNAME $action $valid"
    status=$1
    [ -z "$status" ] && die "$errmsg"
    status=$( printf "%s\n" "$status" | tr 'a-z' 'A-Z' )

    ## all except given status
    FLAG=""
    [[ ${status:0:1} == "-" ]] && {
       FLAG="-v"
       status=${status:1}
    }
    status=${status:0:3}

    count=$(echo $valid | grep -c $status)
    [ $count -eq 1 ] || die "$errmsg"
    formatted_tsv_headers 
    grep  $FLAG "^....${DELIM}$status${DELIM}" "$TSV_FILE" \
        | eval ${TSV_SORT_COMMAND}           \
        | pretty_print
    ;;


"selectm" | "selm") # COMMAND: allows multiple criteria selection key value
    valid="|status|date_created|severity|type|"
    errmsg="usage: $TSV_PROGNAME $action \"type: BUG\" \"status: OPE\" ..."
    [ -z "$1" ] && die "$errmsg"

    # if you use grep -P then don't escape {
    status="..."
    type="..."
    severity="..."
    id=".\{4\}"
    date_created=".\{16\}"
    due_date=".\{10\}"
    assigned_to=".\{10\}"
    title="."

    #echo "selm received: $#,  $*"
    full_regex=0
    for ii in "$@"
    do
        field=$( expr "$ii" : '\([a-zA-Z0-9_]*\).*' )
        value=$( expr "$ii" : '.*[:=] *\(.*\)' )
        [[ "$field" == "status" || $field == "severity" || "$field" == "type" ]] && {
            value=$( printf "%s\n" "$value" | tr 'a-z' 'A-Z' )
            value=${value:0:3}
        }
        case "$field" in
            "status" ) status="$value";;
            "severity" ) severity="$value";;
            "type" ) type="$value";;
            "id" ) id="$value"; ;;
            "assigned_to" ) assigned_to="$value"; full_regex=1;;
            "due_date" ) due_date="$value"; full_regex=1;;
            "date_created" ) date_created="$value"; full_regex=1;;
            "title" ) title="$value"; full_regex=1;;
            * ) full_regex=1;;
        esac
    done
    regex="^${id}${DELIM}${status}${DELIM}${severity}${DELIM}${type}${DELIM}"
    #id  status  severity        type    assigned_to     date_created    due_date        title
    [ $full_regex -gt 0 ] && regex+="${assigned_to}${DELIM}${date_created}${DELIM}${due_date}${DELIM}${title}"
    [ $TSV_VERBOSE_FLAG -gt 1 ] && echo "regex:($regex)"
    #tsv_headers
    formatted_tsv_headers 
    # -P is GNU only, wont work everywhere, UGH
    #grep -P "$regex" "$TSV_FILE"
    grep "$regex" "$TSV_FILE" | pretty_print
    
    ;;

    # TODO formatting required
    # redo : sort on crit and colorize
"lbs") # COMMAND: list by severity
    formatted_tsv_headers
    words="CRI MOD NOR"
    ctr=1
    for ii in $words
    do
        regex="${REG_ID}${DELIM}${REG_TYPE}${DELIM}$ii"
        case $ctr in
            1)  USE_PRI="$PRI_A";;
            2)  USE_PRI="$PRI_B";;
            3)  USE_PRI="$PRI_C";;
            *)  USE_PRI="$PRI_X";;
        esac
        grep "$regex" "$TSV_FILE" | color_line 
        let ctr+=1
    done

    ;;
    
    "ope" | "sta" | "clo" | "can" | "sto" | \
    "open" | "started" | "closed" | "canceled" | "stopped" ) # COMMAND change status of given item/s
    [ ${#action} -eq 3 ] && action=$(echo "$action" | sed 's/can/canceled/;s/clo/closed/;s/sto/stopped/;s/ope/open/')
    for item in "$@"
    do
        #item=$1
        change_status $item "$action"
    done
    cleanup
        ;;

"pri" ) # COMMAND: give priority to a task, appears in title and colored and sorted in some reports

    errmsg="usage: $TSV_PROGNAME $action ITEM# PRIORITY
note: PRIORITY must be anywhere from A to Z."

    [ "$#" -ne 2 ] && die "$errmsg"
    common_validation $1 $errmsg
    newpri=$( printf "%s\n" "$2" | tr 'a-z' 'A-Z' )
    [[ "$newpri" = @([A-Z]) ]] || die "$errmsg"


        # tsv stuff
        oldvalue=$( tsv_get_column_value $item "title" )
        newvalue=$( echo "$oldvalue" | sed  -e "s/^([A-Z]) //" -e  "s/^/($newpri) /" )
        tsv_set_column_value $item "title" "$newvalue"
        log_changes1 "priority" "#$item priority set to $newvalue"
        [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed  -i.bak -e "/^title: /s/(.)//" -e  "s/^\(title: \)/\1($newpri) /" $file
        cleanup
        ;;
"depri" | "dp" ) # COMMAND: removes priority of task
        errmsg="usage: $TSV_PROGNAME $action ITEM#"
        common_validation $1 $errmsg 
        # tsv stuff
        oldvalue=$( tsv_get_column_value $item "title" )
        newvalue=$( echo "$oldvalue" | sed  -e "s/^(.) //" )
        tsv_set_column_value $item "title" "$newvalue"
        log_changes1 "priority" "#$item priority removed"
        [ "$TSV_WRITE_FLAT_FILE" -gt 0 ] && sed  -i.bak -e "/^title: /s/(.)//" $file
        #show_diffs 
        cleanup
        ;;


"show" ) # COMMAND: shows an item, defaults to last
        errmsg="usage: $TSV_PROGNAME show ITEM#"
        item=$1
        [ -z "$1" ] && {
            item=$( sed '$!d' "$TSV_FILE" | cut -f1 | sed 's/ *//g' )
            echo "No item passed. Showing last one ($item)"
        }
        common_validation $item $errmsg

        # read up the headers into an array
        declare -a headers
        let ctr=0
        titles=$( tsv_headers | tr '\t' ' ' )
        for LINE in $titles
        do
            headers[$ctr]=$LINE
            let ctr+=1
        done
        #paditem=$( printf "%4s" $item )
        #rowdata=$( grep "^$paditem" "$TSV_FILE" | tr '\t' '\n' )
        #echo "$rowdata" | while read field

        # put fields into hash so we can change the order
        OLDIFS=$IFS
        let ctr=0
        IFS=$'\t'
        for field in $( echo -e "$rowdata"  )
        do
            #echo "${headers[$ctr]}: $field"
            hash_set "rowdata" "${headers[$ctr]}" "$field"
            let ctr+=1
        done
        IFS=$OLDIFS
        ## we need to print iit in the following order
        xfields="title id status severity type assigned_to date_created due_date"
        for xfile in $xfields
        do
            xxfile=$( printf "%-13s" "$xfile" )
            row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
            echo -en "$row"
            hash_echo "rowdata" "$xfile"
            [ "$xfile" == "due_date" ] && { calc_overdue $( hash_echo "rowdata" "$xfile" ); }
        done
        echo
        # read up the files containing multiline data
        xfields="description fix comment log"
        for xfile in $xfields
        do
            description=$( get_extra_data $item $xfile )
            [ ! -z "$description" ] && { 
            xxfile=$( printf "%-13s" "$xfile" )
            row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
            echo -e "$row"
            #echo "$description"
            # moved to comment lines written as one line with control A in place of newline
            #echo "$description" | tr '' '\n' | sed 's/^/  /g;2,$s/^/                    /g'
            # C-a processing
            echo "$description" | sed 's/^/  /g;'
            echo
        }
        done

        ;;
"viewlog" | "viewcomment" ) # COMMAND: view comments for an item
        errmsg="usage: $TSV_PROGNAME $action ITEM#"
        common_validation $1 $errmsg 
        field=${action:4}
        data=$( get_extra_data $item $field )
        echo "$data"

        ;;

        # user may want to add one comment to many items
"comment" | "addcomment" ) # COMMAND: to add a comment to an item
        errmsg="usage: $TSV_PROGNAME $action ITEM#"
        common_validation $1 $errmsg 
        reply="comment"

        #add_comment
        shift
        add_ml_comment $*
        cleanup
        ;;



            #TODO headers and pipe separator
            #TODO remove CLO
"upcoming" | "upc" ) # COMMAND: shows upcoming tasks
            # now check field 7, convert to unix epoch and compare to now, if greater.
            # if less then break out, no more printing
            now=`date '+%Y-%m-%d'`
            #tomorrow=`date --date="tomorrow" '+%Y-%m-%d'`
            tomorrow=$( date_calc +1 )
            grep -v "${DELIM}CLO${DELIM}" "$TSV_FILE" | sort -t$'\t' -k7 -r | \
            sed -e 's/OPE/-/g;s/CLO/x/g;s/STA/@/g;s/STO/$/g;s/CAN/x/g'  \
            -e "s/${DELIM}\(....-..-..\) ..:../$DELIM\1/g;" \
            -e 's/BUG/#/g;s/ENH/./g;s/FEA/./g;s/TAS/,/g;' | \
            ( while read LINE
            do
                due_date=$( echo "$LINE" | cut -d  $'\t' -f7 )
                #currow=$( date --date="2009-11-25 00:00" +%s )
                currow=$( date --date="$due_date" +%s )
                today=$( date +%s )
                if [ $currow -ge $today ];
                then
                    if [ $TSV_NOW == ${due_date:0:10} ];
                    then
                        LINE=$( echo -e "$PRI_A$LINE$DEFAULT" )
                        echo -e "$LINE"
                    else
                        if [ $tomorrow == ${due_date:0:10} ];
                        then
                            LINE=$( echo -e "$PRI_B$LINE$DEFAULT" )
                            echo -e "$LINE"
                        else
                            echo "$LINE"
                        fi
                    fi
                else
                    break
                fi
            done
            ) | sed -e "s/$DELIM/$TSV_OUTPUT_DELIMITER/g" | color_by_priority 
            ;;

"archive" | "ar" ) # COMMAND: move closed and canceled bugs
            #regex="${REG_ID}${DELIM}(CLO|CAN)"
            regex="${REG_ID}${DELIM}C[LA][NO]"
            count=$( grep -c   "$regex" "$TSV_FILE" )
            toarch=$( grep   "$regex" "$TSV_FILE" | cut -f1 | sed 's/^ //g' )
            if [[ $count > 0 ]]; 
            then  
                sedfound=$( sed "/$regex/!d" "$TSV_FILE" | grep -c . )
                if [ $sedfound -lt $count ]; then
                    echo "Your regex is not working on sed. $sedfound items instead of $count"
                    exit 1
                fi
                grep   "$regex" "$TSV_FILE" >> "$TSV_ARCHIVE_FILE"
                # DARN sed wont take perl expressions
                sed -i.bak "/$regex/d" "$TSV_FILE"
                echo "$count row/s archived to $TSV_ARCHIVE_FILE";
                echo "cleaning other/older files: ($toarch)"
                #[ ! -d "archived" ] && mkdir archived;
                for f in $toarch
                do
                    echo "$f"
                    grep "^$f" ext.txt >> archive.ext.txt
                    sed -i.bak "/^$f/d" "$TSV_EXTRA_DATA_FILE"
                    #sed "/^$f/!d" "$TSV_EXTRA_DATA_FILE"
                    #[ -f "$f.txt" ] && mv "$f.txt" archived/
                    #mv $f.*.txt archived/  > /dev/null 2>&1
                    #rm $f.*bak  > /dev/null 2>&1
                done
            else 
                echo "nothing to archive";
            fi
            ;;

            # put symbold in global vars so consistent TODO, color this based on priority
            # now that we've removed id from title, i've had to do some jugglery to switch cols
"quick" | "q" ) # COMMAND a quick report showing status and title sorted on status
        stime=$SECONDS
        START=$(date +%s.%N)
        short_title
        cut -f1,2,4,8 "$TSV_FILE" | \
        sed -e "s/^\(....\)${DELIM}\(...\)/\2\1/" \
        -e 's/^OPE/-/g;s/^CLO/x/g;s/^STA/@/g;s/^STO/$/g;s/^CAN/x/g'  \
        -e 's/BUG/#/g;s/ENH/./g;s/FEA/./g;s/TAS/,/g;' | \
        sort -k1,1 -k3,4 | \
        color_by_priority | \
        pretty_print

        legend
        #show_source
        stime2=$SECONDS
        END=$(date +%s.%N)
        #echo $(( stime2 - stime )) " seconds"
        DIFF=$(echo "$END - $START" | bc)
        echo $DIFF " seconds."
            ;;

"grep" ) # COMMAND uses egrep to run a quick report showing status and title sorted on status
            regex="$@"
            [ $TSV_VERBOSE_FLAG -gt 1 ] && echo "$arg0: grep : $@"
            short_title
            egrep "$@" "$TSV_FILE" | cut -f1,2,4,8  | \
            sed -e  "s/^\(....\)${DELIM}\(...\)/\2\1/" \
            -e  's/^OPE/-/g;s/^CLO/x/g;s/^STA/@/g;s/^STO/$/g;s/^CAN/x/g'  \
            -e 's/BUG/#/g;s/ENH/ /g;s/FEA/ /g;s/TAS/./g;' | \
            sort -k1,1 | pretty_print
#        show_source
            ;;

"newest" ) # COMMAND a quick report showing  newest <n> items added
        count=${1:-10}
        tail -${count} "$TSV_FILE" | \
        cut -f1,2,6,8  | \
        sed "s/^\(....\)${DELIM}\(...\)/\2\1/"| \
        sed 's/^OPE/-/g;s/^CLO/x/g;s/^STA/@/g;s/^STO/$/g;s/^CAN/x/g' | \
        color_by_priority
        show_source
            ;;

"oldest" ) # COMMAND a quick report showing  oldest <n> items added
        count=${1:-10}
        egrep "${DELIM}OPE${DELIM}|${DELIM}STA${DELIM}" "$TSV_FILE" | \
        head -${count}  | \
        cut -f1,2,6,8  | \
        sed "s/^\(....\)${DELIM}\(...\)/\2\1/"| \
        sed 's/^OPE/-/g;s/^CLO/x/g;s/^STA/@/g;s/^STO/$/g;s/^CAN/x/g' | \
        color_by_priority
        show_source
            ;;

"tag" ) # COMMAND: adds a tag at end of title, with '@' prefixed, helps in searching.
 # TODO XXX tag added after comment !!!
            tag="@$1"
            errmsg="usage: $TSV_PROGNAME $action TAG ITEM#"
            [ -z "$1" ] && die "Tag required. $errmsg"
            shift
            [ $# -eq 0 ] && die "Item/s required. $errmsg"
            for item in "$@"
            do
                common_validation $item "$errmsg"
                ## CAUTION: we are adding to end of row, so if new column is added XXX
                sed -i.bak "/^$paditem/s/.*/& $tag/" "$TSV_FILE"
                log_changes1 "tag" "#$item tagged with $tag"
                [ "$?" -eq 0 ] && echo "Tagged $item with $tag";
            done
            cleanup
            ;;

            # what if one fix to be attached to several bugs ?
"fix" | "addfix" ) # COMMAND: add a fix / resolution for given item
        errmsg="usage: $TSV_PROGNAME $action ITEM#"
        common_validation $1 $errmsg 
        tsv_get_title $item
        echo "Enter a fix or resolution for $item"
        add_fix $item
        echo "Updated fix $item. To view, use: show $item"
        cleanup

        ;;
"status" ) # COMMAND: prints completion status of bugs, features, enhancements, tasks
        bugarch=$(grep -c BUG "$TSV_ARCHIVE_FILE" )
        enharch=$(grep -c ENH "$TSV_ARCHIVE_FILE" )
        feaarch=$(grep -c FEA "$TSV_ARCHIVE_FILE" )
        tasarch=$(grep -c TAS "$TSV_ARCHIVE_FILE" )
        bugctr=$bugarch
        bugclo=$bugarch
        feactr=$feaarch
        feaclo=$feaarch
        enhctr=$enharch
        enhclo=$enharch
        tasctr=$tasarch
        tasclo=$tasarch
        ctr=0
        data=$( cut -f2,4 $TSV_FILE)
        for LINE in $( echo "$data" )
        do
            ((ctr+=1))
        if [[ $LINE =~ BUG ]]
        then
            (( bugctr+=1 ))
            [[ $LINE =~ CLO ]] &&  (( bugclo+=1 ));
        else
            if [[ $LINE =~ FEA ]]
            then
                (( feactr+=1 ))
                [[ $LINE =~ CLO ]] &&  (( feaclo+=1 ));
            else
                if [[ $LINE =~ ENH ]]
                then
                    (( enhctr+=1 ))
                    [[ $LINE =~ CLO ]] &&  (( enhclo+=1 ));
                else
                    if [[ $LINE =~ TAS ]]
                    then
                        (( tasctr+=1 ))
                        [[ $LINE =~ CLO ]] &&  (( tasclo+=1 ));
                    fi
                fi
            fi
        fi
        done
        # actually, here we move closed items to archived so usually closed will be zero !!
        echo "bugs         : $bugclo / $bugctr " 
        echo "enhancements : $enhclo / $enhctr " 
        echo "features     : $feaclo / $feactr " 
        echo "tasks        : $tasclo / $tasctr " 
;;
"qadd" ) # COMMAND: quickly add an issue from command line, no prompting
## b qadd --type:bug --severity:cri --due_date:2009-12-26 "using --params: command upc needs formatting"
# TODO can we start with a priority too?
# validatoin required. TODO
    i_type=${DEFAULT_TYPE:-"bug"}
    i_severity=${DEFAULT_SEVERITY:-"normal"}
    i_status=${DEFAULT_STATUS:-"open"}
    i_due_date=`convert_due_date "$DEFAULT_DUE_DATE"`
    ## check for -- settings, break into key and value
    OPT_PREFIX="i"
    #getoptlong "$@"
    #shift $shifted
    for arg in ${!opt_@}
    do
        read ${OPT_PREFIX}_${arg:4} <<< $( eval 'echo -n "$'$arg' "') 
    done
    echo "type:$i_type"
    #echo "seve:$i_severity"
    #echo "left: $i_rest"
    atitle=$*
    #echo "title:$atitle"
    #read
    [ -z "$atitle" ] && die "Title required for bug"
    #check title for newline at end, this could leave a blank line in file
    del=$DELIM
    atitle=$( echo "$atitle" | tr -d '\n' )
    [  -z "$i_due_date" ] && i_due_date=" "
    i_due_date=$( printf "%-10s" "$i_due_date" )
      create_tsv_file
      [ ! -z "$EMAIL_TO" ] && echo "$tabfields" | tr '\t' '\n' | mail -s "$todo" $EMAIL_TO
      cleanup
      
;;
"recentlog" | "rl") # COMMAND: list recent logs
    # TODO, we should show the title too , somehow
    grep ':log:' "$TSV_EXTRA_DATA_FILE" | tail | cut -d : -f1,4- | sed 's/:/ | /1;s/~/ | /'
    ;;
"recentcomment" | "rc" ) # COMMAND: list recent comments 
    # TODO, we should show the title too , somehow
    # silly sed does not respect tab or newline, gsed does. So I went through some hoops to indent comment
    grep ':com:' "$TSV_EXTRA_DATA_FILE"| tail | cut -d : -f1,3- | sed 's/:/ | /1;s/~/ | /' | sed "s//   /g;" | tr '' '\n'
    ;;
"delcomment" ) # COMMAND: delete a given comment from an item
# TODO update comment count in title UGH
    errmsg="usage: $TSV_PROGNAME $action item# comment#"
    item=$1
    common_validation $1 $errmsg 
    [ -z "$item" ] && die "Item number required. $errmsg"
    number=$2
    [ -z "$number" ] && die "Comment number required. Use viewcomment to see comments. $errmsg"
    [ "$number" -lt 1 ] && die "Comment number should be 1 or more. $errmsg"
    unumber=$number
    number=$(( $number-1 ))
    OLDIFS="$IFS"; IFS=$'\n';declare -a comments=( $(grep "^${item}:com" "$TSV_EXTRA_DATA_FILE") );IFS="$OLDIFS"
    row=${comments[$number]}
    [ -z "$row" ] && die "No such comment. Highest is ${#comments[@]}"
    echo -e "\nThe comment is:\n"
    frow=$( echo -e "$row" | cut -d : -f3- | tr '' '\n' | sed '2,$s/^/    /' )
    echo -e "$frow"
    short_row=$( echo "${frow:0:50}" | tr '\n' ' ' )
    #sed "/$row/!d" "$TSV_EXTRA_DATA_FILE"
    if  [ $TSV_TXT_FORCE = 0 ]; then
        echo "Delete '$short_row'?  (y/n)"
        read ANSWER
    else
        ANSWER="y"
    fi
    if [ "$ANSWER" = "y" ]; then
        sed -i.bak "/$row/d" "$TSV_EXTRA_DATA_FILE"
        [ $TSV_VERBOSE_FLAG -gt 0 ] && echo "Bugzy: '$short_row' deleted."
        [ "$TSV_ADD_COMMENT_COUNT_TO_TITLE" -gt 0 ] && add_comment_count_to_title;
        [ ! -z "$EMAIL_TO" ] && echo -e "$frow" | mail -s "[DELCOMM] $item ($unumber) $short_row" $EMAIL_TO
        cleanup
    else
        echo "Bugzy: No comments were deleted."
    fi
    ;;

"help" )
    help
    ;;
* )
    usage
    ;;
esac
