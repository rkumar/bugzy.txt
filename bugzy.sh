#!/bin/bash
#*******************************************************#
# A simple file based bug tracker                       #
#                                                       #
# rkumar                                                #
# $Id$  #
#*******************************************************#
# TODO: display comments in some listing, long listing
# TODO: validate fields in show
# TODO - rename show. this should show one bug or full file
# TODO - put col widths in hash
#
#### --- cleanup code use at start ---- ####
TMP_FILE=${TMPDIR:-/tmp}/prog.$$
trap "rm -f $TMP_FILE.?; exit 1" 0 1 2 3 13 15
PROGNAME=$(basename "$0")
TODO_SH=$PROGNAME
#TODO_DIR="/Users/rahul/work/projects/rbcurse"
export PROGNAME
Date="2009-11-16"
DATE_FORMAT='+%Y-%m-%d %H:%M'
arg0=$(basename "$0")

TSV_FILE="data.tsv"
#TSV_TITLES_FILE="titles.tsv"
# what fields are we to prompt for in mod
EDITFIELDS="title description status severity type assigned_to due_date comment fix"
PRINTFIELDS="title id status severity type assigned_to date_created due_date"

#ext=${1:-"default value"}
#today=$(date +"%Y-%m-%d-%H%M")

#PROG_DEFAULT_ACTION="list" # this should be in a CFG file not here.
oneline_usage="$PROGNAME [-fhpantvV] [-d todo_config] action [task_number] [task_description]"
usage()
{   
    sed -e 's/^    //' <<EndUsage
    Usage: $oneline_usage
    Try '$PROGNAME -h' for more information.
EndUsage
    exit 1
}
help()
{
    sed -e 's/^    //' <<EndHelp
      Usage: $oneline_usage

      Actions:
        add "THING I NEED TO DO +project @context"
        a "THING I NEED TO DO +project @context"
          Adds THING I NEED TO DO to your todo.txt file on its own line.
          Project and context notation optional.
          Quotes optional.

        modify NUMBER
        mod NUMBER
          allows user to modify various fields of a bug

        edit NUMBER
          Opens bug file in editor for editing. May be disallowed

        del NUMBER [TERM]
        rm NUMBER [TERM]
          Deletes the item 

        depri NUMBER
        dp NUMBER
          Deprioritizes (removes the priority) from the item

        help
          Display this help message.

        list [TERM...]
        ls [TERM...]
          Displays all bug's that contain TERM(s) sorted by priority with line
          numbers.  If no TERM specified, lists entire todo.txt.

        longlist [Fields ...]
        ll type id severity status title
          Lists given fields from all files

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
          Displays the bug file

       lbs
          Lists bugs by severity.

       select key value
       sel status started
       sel severity critical
          lists titles for a key and value
          keys are  status date_created severity type

       selectm "type: bug" "status: open" ...
       selm "type=bug" "status=(open|started)" "severity=critical"
          A multiple criteria search.



EndHelp
    exit 0
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

hash_set "VALUES" "status" "open closed started stopped canceled "
hash_set "VALUES" "severity" "normal critical serious"
hash_set "VALUES" "type" "bug feature enhancement task"
hash_set "TSVVALUES" "status" "OPE CLO STA STO CAN"
hash_set "TSVVALUES" "severity" "NOR CRI SER"
hash_set "TSVVALUES" "type" "BUG FEA ENH TAS"
Edit_tmpfile()
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

## extracts multiline header from datafile and removes
## first and last line if keywords present
extract_header()
{
    key=$1
    file=$2
    inclusive=$(sed -n "/^$key:/,/^[a-z_]*:/p" $file)
    lastline=$(echo "$inclusive" | sed '$d')
    index=$(expr match "$lastline" "^[a-z_]*:")
    [ $index -gt 0 ] && inclusive=$(echo "$inclusive" | sed '$d')

    firstline=$(echo "$inclusive" | sed '1q')
    index=$(expr match "$firstline" "^$key: *$")
    if [ $index -gt 0 ] 
    then
       inclusive=$(echo "$inclusive" | sed '1d')
   else
       inclusive=$(echo "$inclusive" | sed "s/^$key: *//" )
    fi
    echo "$inclusive"
}


shopt -s extglob
list()
{
    ## Prefix the filter_command with the pre_filter_command
    filter_command="${pre_filter_command:-}"
    #echo "list 1 FILELIST: $FILELIST"
    #echo "list 2 FILELIST: $FILELIST"


    [ $VERBOSE_FLAG -gt 1 ] && echo "$arg0: list : $@"
    for search_term in "$@"
    do
    [ $VERBOSE_FLAG -gt 1 ] && echo "$arg0: search_term is $search_term "
        ## See if the first character of $search_term is a dash
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
    done
    [ $VERBOSE_FLAG -gt 1 ] && echo "$arg0: filter_command is $filter_command "

    ## If post_filter_command is set, append it to the filter_command
    [ -n "$post_filter_command" ] && {
        filter_command="${filter_command:-}${filter_command:+ | }${post_filter_command:-}"
    }
        #grep -h -m 1 '^title:' $FILELIST \
        #| cut -c 8-  \
        items=$(
        tsv_titles \
        | eval ${TODOTXT_SORT_COMMAND}                                        \
        | sed '''
                s/\(.*(A).*\)/'$PRI_A'\1'$DEFAULT'/g;
                s/\(.*(B).*\)/'$PRI_B'\1'$DEFAULT'/g;
                s/\(.*(C).*\)/'$PRI_C'\1'$DEFAULT'/g;
                s/\(.*([D-Z]).*\)/'$PRI_X'\1'$DEFAULT'/g;
          '''                                                   \
          )
    if [ "${filter_command}" ]; then
        filtered_items=$(echo -ne "$items" | eval ${filter_command})
    else
        filtered_items=$items
    fi
    echo -ne "$filtered_items\n"

    if [ $VERBOSE_FLAG -gt 0 ]; then
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

        cut -f2 "$TSV_FILE" | awk  '{a[$1] ++} END{for (i in a) print i": "a[i]}' | \
        sed 's/CAN/canceled/;s/CLO/closed/;s/STO/stopped/;s/OPE/open/;s/STA/started/'
:<<DUMMY
        statuses=$( grep -h -m 1 '^status:' $FILELIST | sort -u | cut -c 9- )
        for ii in $statuses
        do
            #echo  -n "$ii:"
            printf "%12s: " "$ii"
            grep -m 1 "^status: $ii" $FILELIST | wc -l
        done
DUMMY
    fi
}
greptitles()
{
    files=$*
    #echo "files: $files"
    [ -z "$files" ] && echo "No matching files" && exit 0
    #grep -h title $files | cut -d':' -f2- 
    #grep -h title $files | cut -c 8-
    FILELIST=$files
    #echo "greptitles FILELIST: $FILELIST"
    list
}
showtitles_where()
{
    key=$1
    value=$2
    #tasks=$(grep -l "$key:.*$value" $ISSUES_DIR/*.txt)
    tasks=$(grep -l "^$key:.*$value" $FILELIST)
    greptitles $tasks 
}
## a lot of problems passing crit with spaces in it
## send in criteria in one strnig and count of criteria.
showtitles_where_multi()
{
    local crit=$1
    local ctr=$2
    crit=$(echo $crit | sed 's/=/: /g')
    #echo "ctr: $ctr, crit: $crit"
    local file
    local files=""
    for file in $FILELIST
    do
        matches=$(egrep -c "$crit"  $file)
        #echo "matches: $matches"
        [ $matches -eq $ctr ] && files="$files $file"
    done
    #echo "files: $files"
    greptitles $files
}
print_tasks()
{
    [ -z "$FILELIST" ] && echo "No matching files" && exit 0
#    echo "coming in with $FILELIST"
    USEPRI=${USEPRI:-$DEFAULT}
        items=$(
        grep -h  '^title:' $FILELIST \
        | cut -c 8-  \
        | eval ${TODOTXT_SORT_COMMAND}                                        \
        | sed '''
                s/\(.*\)/'$USEPRI'\1'$DEFAULT'/g;
          '''                                                   \
          )
          echo -ne "$items\n"

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
    local now=`date "$DATE_FORMAT"`
    [ -z "$key" ] && die "key blank"
    [ -z "$oldvalue" ] && die "oldvalue blank"
    [ -z "$newline" ] && die "newline blank"
    [ -z "$file" ] && die "file blank"
    data="- LOG,$now,$key,$oldvalue,$newline"
    echo "$data" >> $file
    echo "$data" >> $item.log.txt

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
       result=$(date --date "$input" "$DATE_FORMAT")
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
## returns title for a task id OLD FILE
get_title()
{
    item=${1:-$item}
    local file=$ISSUES_DIR/$item.txt
    local mtitle=$(grep -m 1 "^title:" $file | cut -d':' -f2-)
    echo "$mtitle"
}
tsv_get_title()
{
    item=${1:-$item}
    local mtitle=`tsv_get_rowdata $item | cut -c63- `
    echo "$mtitle"
}
## returns value for id and key
get_value_for_id()
{
    local file=$ISSUES_DIR/$1.txt
    local key=$2
    [ -z "$2" ] && die "get_value_for_id requires 2 params"
    local oldvalue=$(grep -m 1 "^$key:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    echo "$oldvalue"
}
get_value_from_file()
{
    local file=$1
    local key=$2
    [ -z "$2" ] && die "get_value_from_file requires 2 params"
    local oldvalue=$(grep -m 1 "^$key:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    echo "$oldvalue"
}
change_status()
{
    item=$1
    action=$2
    errmsg="usage: $TODO_SH $action task#"
    common_validation $1 "$errmsg"
    reply="status"; input="$action";
    oldvalue=`get_value_for_id $item $reply`
    [ "$oldvalue" == "$action" ] && die "$item is already $oldvalue"
    var=$( printf "%s" "${action:0:3}" | tr 'a-z' 'A-Z' )
    echo "$item is currently $oldvalue"
        newline="$reply: $input"
        now=`date "$DATE_FORMAT"`
        sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
        # tsv stuff
        newcode=`conv_old_to_new_code $input`
        tsv_set_column_value $item $reply $newcode
    echo "$item is now $input"
        log_changes $reply "$oldvalue" $input $file
        mtitle=`get_title $item`
        [ ! -z "$EMAIL_TO" ] && cat "$file" | mail -s "[$var] $mtitle" $EMAIL_TO
        show_diffs 
}
## for actions that require a bug id
## sets item, file
common_validation()
{
    item=$1
    shift
    local errmsg="$*"
    #local argct=${3:-2}

    #[ "$#" -ne $argct ] && die "$errmsg"
    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    # OLD FILE STUFF
    file=$ISSUES_DIR/${item}.txt
    [ ! -r "$file" ] && die "No such file: $file"

    # tsv stuff
    lineno=`tsv_lineno $item`
    [ $lineno -lt 1 ] && die "No such item: $item"
#    [ $VERBOSE_FLAG -gt 0 ] && grep "^title:" $file
}
show_diffs()
{
    local file=${1:-$file}
    local filebak=${2:-$file.bak}
    [ "$SHOW_DIFFS_ON_UPDATE" == "yes" ] && diff $filebak $file
}
## prints various fields for an item number
# pass item number and then one ore more fields.
show_info()
{
    item=$1
    file=$ISSUES_DIR/${item}.txt
    shift
    local str=""
    local fields="$*"
    #if no field passed use title
    fields=${fields:-"title"}
    for ii in $fields
    do
        str="$str "`grep -m 1 "^$ii:" $file | cut -d':' -f2-`" |"
    done
    echo "$str" #| tr '\n' '|'
}
show_info1()
{
    item=$1
    file=$ISSUES_DIR/${item}.txt
    data=$( cat $file )
    shift
    local str=""
    local fields="$*"
    #if no field passed use title
    fields=${fields:-"title"}
    for ii in $fields
    do
        str="$str "`echo "$data" | grep -m 1 "^$ii:" | cut -d':' -f2-`" |"
    done
    echo "$str" #| tr '\n' '|'
}
# unused
show_info2()
{
    item=$1
    file=$ISSUES_DIR/${item}.txt
    data=$( cat $file )
    shift
    local str=""
    local fields="$*"
    #if no field passed use title
    fields=${fields:-"title"}
    for ii in $fields
    do
        str="$str "`echo "$data" | grep -m 1 "^$ii:" | cut -d':' -f2-`" |"
    done
    echo "$str" #| tr '\n' '|'
}

## when displaying in columnar, use what widths to pad
get_display_widths()
{
    field="$1"
    case "$field" in
        "title" ) RESULT=40;;
        "id" ) RESULT=5;;
        "status" ) RESULT=8;;
        "severity" ) RESULT=8;;
        "type" ) RESULT=8;;
        * ) RESULT=10;;
    esac
}

## TOO SLOW, DONT USE
show_info3(){
    fields=$*
    echo "F: $fields"
        for file in $FILELIST
        do
            str=""
            data=$(cat $file)
            for ii in $fields
            do
                get_display_widths $ii
                w=$RESULT
                f=`echo "$data" | grep -m 1 "^$ii:" | cut -d':' -f2-`
                str="$str "$(printf "%-*s" $w "$f" )" |"
                #str="$str "`echo "$data" | grep -m 1 "^$ii:" | cut -d':' -f2-`" |"
            done
            echo "$str" #| tr '\n' '|'
        done
    }
    # shows columnar data for given fields
    # TODO : add titles and how many rows displayed
show_info4(){
    fields=$*
    echo "fields:$fields"
    count=$( echo $fields | tr ' ' '\n' | wc -l ) 
        str1=""
        declare -a widths
        ctr=0
        for ii in $fields
        do
            get_display_widths $ii
            widths[$ctr]=$RESULT
            let ctr+=1
            # grep the fields from the files
            if [ -z "$str1" ];
            then
                str1=$( grep "^${ii}:" $FILELIST )
            else
                str1="$str1\n"$( grep "^${ii}:" $FILELIST )
            fi
        done
        str=""
        #for file in *.txt #$FILELIST
        # now grep out each file from the combined data
        for file in $FILELIST
        do
            if [ -z "$str" ];
            then
                str=$( echo -e "$str1" | grep "^$file" | cut -d':' -f3- )
            else
                str="$str\n"$( echo -e "$str1" | grep "^$file" | cut -d':' -f3- )
            fi
        done
        ## ideally we should use a control break in case someone deletes a field
        ctr=0
        echo "count: $count"
        echo -e "$str" | while read LINE
        do
            [ -z "$LINE" ] && continue;
            #f=$( echo "$LINE" | cut -d':' -f3- )
            #    echo -n "$f | "
                #echo -n "$LINE | "
                printf "%-*s | " ${widths[$ctr]} "$LINE"
                #echo  "$LINE | "
                let ctr+=1
                if [ $ctr -eq $count ];
                then
                    ctr=0
                    echo ""
                fi
                :
        done
                #get_display_widths $ii
                #w=$RESULT
                #str="$str "$(printf "%-*s" $w "$f" )" |"
    }
add_comment(){
    RESULT=0 
                echo "Enter new comment:"
                read input
                [ -z "$input" ] || {
                    start=$(sed -n "/^$reply:/=" $file)
                    [ -z "$reply" ] && die "No section for $reply found in $file"
                    now=`date "$DATE_FORMAT"`
                    text="- $now: $input"
ex - $file<<!
${start}a
$text
.
x
!
        log_changes "$action" "${input:0:15} ..." "${#input} chars" "$file"
        RESULT=1 
        # for tsv file
        echo "$text" >> $item.comment.txt
    }
}
## returns field value given a field
## please pipe data of a file to this.
get_value(){
    key=$1
    let len=${#key}+3
    #RESULT=$( grep -m 1 "^$key:" | cut -c ${len}- )
    grep -m 1 "^$key:" | cut -c ${len}-
}
get_value_from_line(){
    cut -d':' -f2-
}

get_field_index(){
    case $field in
        "title" ) echo 1;;
        "type" ) echo 2;;
        "severity" ) echo 3;;
        "status" ) echo 4;;
        "id" ) echo 7;;
        "date_created" ) echo 8;;
        "due_date" ) echo 9;;
        "assigned_to" ) echo 10;;
        *) echo 0
    esac
}
## reads data passed as args into field_array
# I could have done this
# read -r -a sender <<< "$value"
array_data(){
    data="$*"
    declare -a field_array
    #echo "$data" | while read LINE
    # while read opens a subshell, so values are lost in parent shell
    for LINE in $( echo "$data" )
    do
        #field=$( get_value_from_line "$data" )
        field=$( expr "$LINE" : '^\(.*\):' )
        value=$( expr "$LINE" : '.*: \(.*\)' )
        index=$( get_field_index $field )
        #[ $index -gt 0 ] && field_array[ $index ]=$value
        field_array[ $index ]=$value
    done
}
# uses global hash to hash file data
# very likely to carry over value of previous row into next if next key not present
hash_data(){
    data="$*"
    #echo "$data" | while read LINE
    lastfield="dummy"
            firstline=0
        OLDIFS=$IFS
    IFS=$'\n'
    for LINE in $( echo "$data" )
    do
        #echo "LINE:$LINE"
        field=$( expr "$LINE" : '^\([a-z_0-9]*\):' )
        if [ ! -z "$field" ];
        then
            lastfield=$field
            value=$( expr "$LINE" : '.*: \(.*\)' )
            #echo "setting:$field. to:$value."
            hash_set "DATA" "$field" "$value"
            firstline=1
        else
            value=`hash_echo "DATA" "$lastfield"`
            if [ $firstline -gt 0 ];
            then
                if [ -z "$value" ];
                then
                    value="$LINE"
                else
                    value+="\n$LINE"
                fi
            else
                value+="\n$LINE"
            fi
            hash_set "DATA" "$lastfield" "$value"
            firstline=0
        fi
    
    done
    IFS=$OLDIFS
}
## returns title column, all rows
tsv_titles(){
        cut -c63- "$TSV_FILE" 
}
## print titles of CSV file
tsv_headers(){
    #sed '1q' "$TSV_FILE"
    echo "id	status	severity	type	assigned_to	date_created	due_date	title"
    #cat "$TSV_TITLES_FILE"
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
# takes fieldname, => index of column
tsv_column_index(){
    [ $# -ne 1 ] && { echo "===== tsv_column_index ERROR one param required"; }
    # put in hash or function to make faster
    local titles=$( tsv_headers | tr '\t' ' ' )
    echo `get_word_position "$1" "$titles"`
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
    [ -z "$rowdata" ] && { echo "ERROR ITEMNO $1"; return -1;}
    echo "$rowdata"
}

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
    lineno=`tsv_lineno $item`
    [ $lineno -lt 1 ] && { echo "No such item:$item"; RESULT=-1; return;}
    row=$( sed "$lineno!d" "$TSV_FILE" )
    #echo "row:$row"
    [ -z "$row" ] && { echo "row blank!"; return; }
    [ ! -d "$DELETED_DIR" ] && mkdir "$DELETED_DIR";
    echo "$row" >> "$TSV_FILE_DELETED"
    sed -i.bak "${lineno}d" "$TSV_FILE"
}
    
tsv_delete_other_files(){
    item=$1
    RESULT=0

    # move up the files containing multiline data
    xfields="description fix comment log"
    for xfile in $xfields
    do
        dfile="${item}.${xfile}.txt" 
        [ -f "$dfile" ] && { 
        mv "$dfile" "$DELETED_DIR"
    }
    done
    [ $VERBOSE_FLAG -gt 1 ] && ls -ltrh "$DELETED_DIR"
}
## updates tsv row with data for given
# item, columnname, value
# -1 on errors
tsv_set_column_value(){
    item=$1
    lineno=`tsv_lineno $item`
    #echo "line:$lineno"
    columnname=$2
    newvalue=$3
#    wc -l "$TSV_FILE"
    row=$( sed "$lineno!d" "$TSV_FILE" )
    #echo "row:$row"
    [ -z "$row" ] && { echo "row blank!"; return; }
    #sed -i.bak "${lineno}d" "$TSV_FILE"
    tsv_delete_item $item
#    wc -l "$TSV_FILE"
    position=`tsv_column_index "$columnname"`
    #echo "position:$position"
    newrow=$( echo "$row" | tr '\t' '\n' | sed $position"s/.*/$newvalue/" | tr '\n' '\t' )
    #echo "newrow:$newrow"

ex - "$TSV_FILE"<<!
${lineno}i
$newrow
.
x
!
#echo
#diff "$TSV_FILE" "$TSV_FILE".bak
#    wc -l "$TSV_FILE"
#    echo
#    grep "$1" "$TSV_FILE"
}

## fix for convert old code to new
## first 3 chars, then capitalize
conv_old_to_new_code(){
    old="$1"
    echo ${old:0:3} | tr 'a-z' 'A-Z'
}

print_item(){
    item=$1
    rowdata=`tsv_get_rowdata $item`
    output=""
    for field in $( echo $PRINTFIELDS )
    do
        index=`tsv_column_index "$field"`
        value=$( echo "$rowdata" | cut -d $'\t' -f $index )
        xxfile=$( printf "%-13s" "$field" )
        row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
        output+=$( echo -en "\n$row" )
        output+=$( echo "$value" )
    done
        # read up the files containing multiline data
        xfields="description fix comment log"
        for xfile in $xfields
        do
            dfile="${item}.${xfile}.txt" 
            [ -f "$dfile" ] && { 
            xxfile=$( printf "%-13s" "$xfile" )
            row=$( echo -e $PRI_A"$xxfile: \n"$DEFAULT )
            output+=$( echo -e "\n$row\n" )
            output+="\n"
            output+=$( cat "$dfile"  )
            output+="\n"
        }
        done
    echo -e "$output"
    #echo "index:$index"
    #paste  <(echo $PRINTFIELDS | tr ' ' '\n') <(echo "$rowdata" | tr '\t' '\n')
}

## ADD FUNCTIONS ABOVE
out=
file=
Dflag=
while getopts hpvVf:o:D:d:i: flag
do
    case "$flag" in
    (h) help; exit 0;;
    (V) echo "$arg0: version @REVISION@ ($Date) Author: rkumar"; exit 0;;
    (v) 
        : $(( VERBOSE_FLAG++ ))
        ;;
    (f) file="$OPTARG";;
    p )
        TODOTXT_PLAIN=1
        ;;
    (o) out="$OPTARG";;
    (D) Dflag="$Dflag $OPTARG";;
    d )
        PROG_CFG_FILE=$OPTARG
        ;;
     (i) _FILES="$OPTARG"
         ;;
    (*) usage;;
    esac
done
shift $(($OPTIND - 1))

# defaults if not yet defined
VERBOSE_FLAG=${VERBOSE_FLAG:-1}
TODOTXT_PLAIN=${TODOTXT_PLAIN:-0}
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
#TODOTXT_SORT_COMMAND=${TODOTXT_SORT_COMMAND:-env LC_COLLATE=C sort -f -k3}
# for tsv
TODOTXT_SORT_COMMAND=${TODOTXT_SORT_COMMAND:-env LC_COLLATE=C sort -f -k2}
REG_ID="^...."
REG_STATUS="..."
REG_SEVERITY="..."
REG_TYPE="..."
REG_DUE_DATE=".{16}"
REG_DATE_CREATED=".{16}"
REG_ASSIGNED_TO=".{10}"


[ -r "$PROG_CFG_FILE" ] || die "Fatal error: Cannot read configuration file $PROG_CFG_FILE"

. "$PROG_CFG_FILE"

ACTION=${1:-$PROG_DEFAULT_ACTION}

[ -z "$ACTION" ]    && usage
# added RK 2009-11-06 11:00 to save issues (see edit)
ISSUES_DIR=$TODO_DIR/.todos
DELETED_DIR="$ISSUES_DIR/deleted"
TSV_FILE_DELETED="$DELETED_DIR/deleted.tsv"

if [ $TODOTXT_PLAIN = 1 ]; then
    PRI_A=$NONE
    PRI_B=$NONE
    PRI_C=$NONE
    PRI_X=$NONE
    DEFAULT=$NONE
fi
cd $ISSUES_DIR

# evaluate given item numbers so grep doesn't give errors later. One can used grep -s also.
[ -z "$_FILES" ] || {
    comm="ls $_FILES.txt 2> /dev/null"
    [ $VERBOSE_FLAG -gt 1 ] && echo "comm:$comm"
    _FILES=$( eval $comm )
    FILELIST=$_FILES
    [ $VERBOSE_FLAG -gt 1 ] && echo "filelist:$FILELIST"
}

FILELIST=${FILELIST:-$( ls *.txt | grep "[0-9]\+\.txt") }
#[ $# -eq 0 ] && {
#exit 0;
#}

# == HANDLE ACTION ==
action=$( printf "%s\n" "$ACTION" | tr 'A-Z' 'a-z' )

#action=$( printf "%s\n" "$1" | tr 'A-Z' 'a-z' )
shift

case $action in
    "print" )
    print_item $1
    ;;
"add" | "a")
    if [[ -z "$1" ]]; then
        echo -n "Enter a short title/subject: "
        read atitle
    else
        atitle=$*
    fi
    [ -z "$atitle" ] && die "Title required for bug"
    [ "$PROMPT_DESC" == "yes" ] && {
        echo -n "Enter a description: "
        read i_desc
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
        echo -n "Enter a due date $prompts: "
        read due_date
        [ ! -z "$due_date" ] && i_due_date=`convert_due_date "$due_date"`
    }
    [  -z "$i_due_date" ] && i_due_date=" "
    i_due_date=$( printf "%-16s" "$i_due_date" )
    prompts=
    [ "$PROMPT_ASSIGNED_TO" == "yes" ] && {
        [ ! -z "$ASSIGNED_TO" ] && prompts=" [default is $ASSIGNED_TO]"
        echo -n "Enter assigned to (10 chars) $prompts: "
        read assigned_to
        [ ! -z "$assigned_to" ] && ASSIGNED_TO=$assigned_to
    }
    ASSIGNED_TO=$( printf "%-10s" "$ASSIGNED_TO" )
    ASSIGNED_TO=${ASSIGNED_TO:0:10}

    short_type=$( echo "${i_type:0:1}" | tr 'a-z' 'A-Z' )

    #serialid=`incr_id`
    serialid=`get_next_id`
    task="[$short_type #$serialid]"
    todo="$task $atitle"
    tabtitle="[#$serialid] $atitle"
    [ -d "$ISSUES_DIR" ] || mkdir "$ISSUES_DIR"
    editfile=$ISSUES_DIR/${serialid}.txt
    if [ -f $editfile ];
    then
        $EDITOR $editfile
    else
      #  echo "title: $todo" > "$editfile"
        now=`date "$DATE_FORMAT"`
    sed -e 's/^    //' <<EndUsage >"$editfile"
    title: $todo
    id: $serialid
    description:
    $i_desc
    date_created: $now
    status: $i_status
    severity: $i_severity
    type: $i_type
    assigned_to: $ASSIGNED_TO
    due_date: $i_due_date
    comment: 

    fix: 
    log:

EndUsage
    #$EDITOR $editfile
    fi
    ## save as tab delimited -- trying out
      del="	"
      tabstat=$( echo ${i_status:0:3} | tr "a-z" "A-Z" )
      tabseve=$( echo ${i_severity:0:3} | tr "a-z" "A-Z" )
      tabtype=$( echo ${i_type:0:3} | tr "a-z" "A-Z" )
      tabid=$( printf "%4s" "$serialid" )
      
      #tabfields="$tabstat${del}$tabseve${del}$tabtype${del}$serialid${del}$now${del}$ASSIGNED_TO${del}$i_due_date${del}$todo"
      tabfields="$tabid${del}$tabstat${del}$tabseve${del}$tabtype${del}$ASSIGNED_TO${del}$now${del}$i_due_date${del}$tabtitle"
      echo "$tabfields" >> "$TSV_FILE"
      [ ! -z "$i_desc" ] && echo "$i_desc" > $serialid.description.txt

    process_quadoptions  "$SEND_EMAIL" "Send file by email?"
    #[ $RESULT == "yes" ] && get_input "emailid" "$ASSIGNED_TO"
    [ "$RESULT" == "yes" ] && {
        get_input "emailid" "$EMAIL_TO"
        #"cat $file | mail -s $title  "
        [ ! -z "$EMAIL_TO" ] && cat "$editfile" | mail -s "$todo" $EMAIL_TO
    }
    echo "Created $serialid"

       cleanup;;
"del" | "rm")
    errmsg="usage: $TODO_SH $action task#"
    item=$1
    common_validation $1 $errmsg

    # TODO only confirm if not forced
    grep -m 1 "^title" $file
    mtitle=`get_title $item`  # OLD
    body=$( cat $file )  # OLD
    [ ! -d "$DELETED_DIR" ] && mkdir "$DELETED_DIR";
    #mv $file "$DELETED_DIR/`basename $file`.del" || mv $file $file.del
    mv $file $file.del
    mv $file.del "$DELETED_DIR/"
    # tsv stuff
    tsv_delete_item $item
    tsv_delete_other_files $item
    [ ! -z "$EMAIL_TO" ] && echo -e "$body" | mail -s "[DEL] $mtitle" $EMAIL_TO
    

       cleanup;;
"edit" | "ed")
    errmsg="usage: $TODO_SH $action task#"
    item=$1
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    common_validation $item "$errmsg"
    $EDITOR $file

       cleanup;;
"modify" | "mod")
    errmsg="usage: $TODO_SH $action task#"
    modified=0
    item=$1
    common_validation $1 $errmsg
    #severity_values="critical serious normal"
    #type_values="bug feature enhancement task"
    #MAINCHOICES=$(grep '^[a-z_0-9]*:' $file | egrep -v '^log:|^date_|^id:' | cut -d':' -f1  )
    MAINCHOICES="$EDITFIELDS"
    #MAINCHOICES="$MAINCHOICES quit"
    while true
    do
        CHOICES="$MAINCHOICES"
    #echo "Select field to edit"
    ask "Select field to edit"
    #echo $CHOICES
    #reply=`oldask` 
    reply=$ASKRESULT
    [ "$reply" == "quit" ] && {
      [ $modified -gt 0 ] && {
      #mtitle=$(grep -m 1 "^title:" $file | cut -d':' -f2-)
      mtitle=`tsv_get_title $item`
      body=`PRI_A=$NONE;DEFAULT=$NONE;print_item $item`
        [ ! -z "$EMAIL_TO" ] && echo -e "$body" | mail -s "[MOD] $mtitle" $EMAIL_TO
        }
      break
    }
    echo "reply is ($reply)"
    oldvalue=$(grep -m 1 "^$reply:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    [ -z "$oldvalue" ] || echo "Select new $reply (old was \"$oldvalue\")"
    CHOICES=`hash_echo "VALUES" "$reply"`
    if [ ! -z "${CHOICES}" ] 
    then
        #input=`oldask` 
        ask
        input=$ASKRESULT
        echo "input is ($input)"
        newline="$reply: $input"
        now=`date "$DATE_FORMAT"`
        sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
        newcode=`conv_old_to_new_code $input`
        tsv_set_column_value $item $reply $newcode
        log_changes $reply $oldvalue $input $file
                   let modified+=1
        #echo "- LOG,$now,$reply,$oldvalue,$newline" >> $file
        echo "done ..."
        show_diffs
    else
        case $reply in
            "title" )
                # AAA
                echo "$oldvalue" > $TMP_FILE
                edit_tmpfile
                [ $RESULT -gt 0 ] && {
                   text=$(cat $TMP_FILE)
                   sed -i.bak "/^$reply:/s/^.*$/$reply: $text/" $file
                   tsv_set_column_value $item $reply $text
                   log_changes $reply "${#oldvalue} chars" "${#text} chars" "$file"
                   show_diffs 
                   let modified+=1
                }
            ;;
            "comment" )
                   cp $file $file.bak
                add_comment
                [ $RESULT -gt 0 ] && {
                    show_diffs
                    let modified+=1
                }

                ;;
            "due_date" )
            read due_date
            [ ! -z "$due_date" ] && { due_date=`convert_due_date "$due_date"`
            text="$due_date"
                   sed -i.bak "/^$reply:/s/^.*$/$reply: $text/" $file
                   tsv_set_column_value $item "due_date" "$text"

                   log_changes $reply "${oldvalue}" "${text}" "$file"
                   show_diffs 
                   let modified+=1
                }
            ;;
            "description" | "fix" )
                description=`extract_header $reply $file`
                oldvalue=$description
                lines=$(echo "$description"  | wc -l)
                [ -z "$description" ] && {
                description=$(echo "# remove this line");lines=0;
                }
                echo "$description" > $TMP_FILE
                edit_tmpfile
                [ $RESULT -gt 0 ] && {
                   cp $file $file.bak.1
                   start=$(sed -n "/^$reply:/=" $file)
                   let end=$start+$lines
                   sed -i.bak "$start,${end}d" $file
                   text=$(cat $TMP_FILE)
ex - $file<<!
${start}i
$reply:
$text
.
x
!
        log_changes $reply "${#oldvalue} chars" "${#text} chars" "$file"
                   let modified+=1
    [ $VERBOSE_FLAG -gt 1 ] && {
    echo "edited file is:"
    cat $file | sed 's/^/> /'
    echo " "
    }
    # tsv stuff
    echo "$text" > $item.$reply.txt

    show_diffs $file $file.bak.1 
    rm $file.bak.1
                }
                
                ;;
            esac


        # actually we need to let user edit existing value in editor
    fi
done # while true
       cleanup;;
"move" | "mv")
    echo "action is $action"
    echo "left is $*"
       cleanup;;
"list" | "ls")
    list "$@"
       cleanup;;
"liststat" | "lists")
   ## if - is given, e.g. -open, then all but open are shown
    valid="|open|closed|started|stopped|canceled|"
    errmsg="usage: $TODO_SH $action $valid"
    status=$1
    [ -z "$status" ] && die "$errmsg"
    status=$( printf "%s\n" "$status" | tr 'A-Z' 'a-z' )

    ## all except given status
    FLAG=""
    [[ ${status:0:1} == "-" ]] && {
       FLAG="-L"
       status=${status:1}
    }

    count=$(echo $valid | grep -c $status)
    [ $count -eq 1 ] || die "$errmsg"
    tasks=$(grep -l -m 1 $FLAG "^status: *$status" $FILELIST)
    greptitles $tasks 
    ;;
    # XXX
    "tsvlists" )
    valid="|OPE|CLO|STA|STO|CAN|"
    errmsg="usage: $TODO_SH $action $valid"
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
    #tasks=$(grep -l -m 1 $FLAG "^status: *$status" $FILELIST)
    tsv_headers
    grep -P $FLAG "^....\t$status\t" "$TSV_FILE"
    ;;
"select" | "sel")
    ## lists titles for a key and value
    ## keys are  status date_created severity type
    valid="|status|date_created|severity|type|"
    errmsg="usage: $TODO_SH $action $valid"
    key=$1
    value=$2
    [ -z "$key" ] && die "$errmsg"
    [ -z "$value" ] && die "$errmsg"
    key=$( printf "%s\n" "$key" | tr 'A-Z' 'a-z' )

    count=$(echo $valid | grep -c $key)
    [ $count -eq 1 ] || die "$errmsg"
    showtitles_where $*
    
    ;;
"selectm" | "selm")
    valid="|status|date_created|severity|type|"
    errmsg="usage: $TODO_SH $action \"type: bug\" \"status: open\" ..."
    [ -z "$1" ] && die "$errmsg"
    #[ -z "$key" ] && die "$errmsg"
    #[ -z "$value" ] && die "$errmsg"
    #key=$( printf "%s\n" "$key" | tr 'A-Z' 'a-z' )

    #echo "selm received: $#,  $*"
    ctr=1
    crit=$1
    shift
    for ii in "$@"
    do
        crit="$crit|$ii"
        let ctr+=1
    done
    showtitles_where_multi "$crit" $ctr
    
    ;;
    # XXX
"tsvselectm" | "tsvselm")
    valid="|status|date_created|severity|type|"
    errmsg="usage: $TODO_SH $action \"type: bug\" \"status: open\" ..."
    [ -z "$1" ] && die "$errmsg"
    #[ -z "$key" ] && die "$errmsg"
    #[ -z "$value" ] && die "$errmsg"
    #key=$( printf "%s\n" "$key" | tr 'A-Z' 'a-z' )

    status="..."
    type="..."
    severity="..."
    id=".{4}"
    date_created=".{16}"
    due_date=".{16}"
    assigned_to=".{10}"
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
    regex="^${id}\t${status}\t${severity}\t${type}\t"
    #id  status  severity        type    assigned_to     date_created    due_date        title
    [ $full_regex -gt 0 ] && regex+="${assigned_to}\t${date_created}\t${due_date}\t${title}"
    echo "regex:$regex"
    tsv_headers
    grep -P "$regex" "$TSV_FILE"
    
    ;;
"lbs")
    OLDLIST=$FILELIST
    tasks=$(grep -l -m 1 "^severity: critical" $FILELIST)
    #echo "tasks $tasks"
    USEPRI=$PRI_A
    FILELIST=$tasks
    [ -z "$FILELIST" ] || print_tasks
    FILELIST=$OLDLIST
    tasks=$(grep -l -m 1 "^severity: serious" $FILELIST)
    #echo "tasks[$tasks]"
    USEPRI=$PRI_B
    FILELIST=$tasks
    [ -z "$FILELIST" ] || print_tasks
    FILELIST=$OLDLIST
    tasks=$(grep -l -m 1 "^severity: normal" $FILELIST)
    #echo "tasks:$tasks:"
    USEPRI=
    FILELIST=$tasks
    [ -z "$FILELIST" ] || print_tasks
    ;;
"tsvlbs")
    tsv_headers
    words="CRI SER NOR"
    ctr=1
    for ii in $words
    do
        regex="^${REG_ID}\t${REG_TYPE}\t$ii"
        case $ctr in
            1)  USE_PRI="$PRI_A";;
            2)  USE_PRI="$PRI_B";;
            3)  USE_PRI="$PRI_C";;
            *)  USE_PRI="$PRI_X";;
        esac
        grep -P "$regex" "$TSV_FILE" | color_line 
        let ctr+=1
    done

    
    ;;
    "ope" | "sta" | "clo" | "can" | "sto" | \
    "open" | "started" | "closed" | "canceled" | "stopped" )
    [ ${#action} -eq 3 ] && action=$(echo "$action" | sed 's/can/canceled/;s/clo/closed/;s/sto/stopped/;s/ope/open/')
        item=$1
        change_status $item "$action"
        ;;

    "pri" )

    errmsg="usage: $TODO_SH $action ITEM# PRIORITY
note: PRIORITY must be anywhere from A to Z."

    [ "$#" -ne 2 ] && die "$errmsg"
    common_validation $1 $errmsg
    newpri=$( printf "%s\n" "$2" | tr 'a-z' 'A-Z' )
    [[ "$newpri" = @([A-Z]) ]] || die "$errmsg"

    #sed -e $item"s/^(.) //" -e $item"s/^/($newpri) /" "$TODO_FILE" > /dev/null 2>&1

    #if [ "$?" -eq 0 ]; then
        #it's all good, continue
        [ $VERBOSE_FLAG -gt 1 ] && grep "^title:" $file
        show_info $item
        sed  -i.bak -e "s/^\(title: \[.*\]\) (.)/\1/" -e  "s/^\(title: \[.*\]\)/\1 ($newpri)/" $file
        [ $VERBOSE_FLAG -gt 1 ] && grep "^title:" $file
        show_info $item 'title' 'type' 'status'
        show_diffs 
        cleanup
    #else
    #    die "$errmsg"
    #fi;;
        ;;
        "depri")
        errmsg="usage: $TODO_SH $action ITEM#"
        common_validation $1 $errmsg 
        get_title
        sed  -i.bak "s/^\(title: \[.*\]\) (.)/\1/" $file
        get_title
        show_diffs 
        cleanup
        ;;

        "showold" )
        # TODO validate fields given
        ## this is slow since each file is opened and each field is grepped
        # time will be proportional to # of bugs
        fields="$*"
        fields=${fields:-"id status severity type title"}
        show_info3 $fields
#        ids=$( grep -h '^id:' $FILELIST | cut -c 5- )
#        for item in $ids
#        do
#            show_info1 $item $fields
#        done
        ;;
        "show" )
        errmsg="usage: $TODO_SH show ITEM#"
        common_validation $1 $errmsg
        data=$( sed "s/^\([a-z0-9_]*\):\(.*\)/$PRI_A\1:$DEFAULT\2/g;" $file )
        echo -e "$data"
        ;;
        "tsvshow" )
        errmsg="usage: $TODO_SH show ITEM#"
        common_validation $1 $errmsg

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
        rowdata=$( tsv_get_rowdata $item )
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
        done
        echo
        # read up the files containing multiline data
        xfields="description fix comment log"
        for xfile in $xfields
        do
            dfile="${item}.${xfile}.txt" 
            [ -f "$dfile" ] && { 
            xxfile=$( printf "%-13s" "$xfile" )
            row=$( echo -e $PRI_A"$xxfile: "$DEFAULT )
            echo -e "$row"
            cat "$dfile" 
            echo
        }
        done

        ;;
        "ll" | "longlist" )
        # TODO validate fields given
        # TODO titles
        fields="$*"
        fields=${fields:-"id status severity type title"}
        show_info4 $fields
        ;;

        "ll1" )
        ## FASTEST
        # this uses egrep and is very fast compared to show which selects each field
        # however, no control over order of fields
        fields="$*"
        fields=${fields:-"id status severity type title"}
        count=$( echo $fields | tr ' ' '\n' | wc -l ) 
        #count=$#
        ff=""
        for f in $fields
        do
            ff+="|^$f"
        done
        fields=$( echo $ff | cut -c2- )

        #fields=$( echo "$fields" | sed 's/ /|^/g' )
        #fields="^$fields"
        echo "fields::$fields"
        data=$( egrep -h "$fields" $FILELIST | cut -d':' -f2- )
        #echo "$data" | paste -d '|' - - - - - 
        #echo "$data" | paste -d '||||\n' - - - - -
        # pasting the lines together, paste does not let us change number of lines programmatically
        # this approach can give errors if field order changed in some files
        ctr=0
        echo "$data" | while read LINE
        do
                echo -n "$LINE | "
                let ctr+=1
                if [ $ctr -eq $count ];
                then
                    ctr=0
                    echo ""
                fi
                :
        done

        ;;
        "ll2" )
        # this is a modification of ll1 and does give the data in requested field order
        fields="$*"
        fields=${fields:-"id status severity type title"}
        echo "$fields"
        count=$( echo $fields | tr ' ' '\n' | wc -l ) 
        # create sed string to replace field name with a number so we can sort by number i/o field
        ctr=0
        seds=""
        for f in $fields
        do
            seds+="s/:$f:/:$ctr:/g;"
            let ctr+=1
        done
        #echo "seds:$seds"

        fields=$( echo "$fields" | sed 's/ /|^/g' )
        fields="^$fields"
        #echo "fields::$fields"
        data=$( egrep "$fields" $FILELIST | sed $seds | sort | cut -d':' -f3- )
        ctr=0
        echo "$data" | while read LINE
        do
                echo -n "$LINE | "
                let ctr+=1
                if [ $ctr -eq $count ];
                then
                    ctr=0
                    echo ""
                fi
                :
        done

        ;;
        "viewlog" | "viewcomment" )
        errmsg="usage: $TODO_SH $action ITEM#"
        common_validation $1 $errmsg 
        field=${action:4}
        data=`extract_header $field $file`
        echo "$data"

        ;;
        "comment" | "addcomment" )
        errmsg="usage: $TODO_SH $action ITEM#"
        common_validation $1 $errmsg 
        cp $file $file.bak
        reply="comment"

        add_comment
                [ $RESULT -gt 0 ] && {
                    show_diffs
                }
        cleanup
        ;;
        "upcoming" | "upc" )
            tasks=$(egrep -l -m 1 $FLAG "^status: (started|open)" $FILELIST)
            RESULT="ax"
            export RESULT
            for ii in $tasks
            do
                data=$( cat $ii )
                #echo "$data" | grep -m 1 "^due_date:" | cut -d':' -f2-
                due_date=$( echo "$data" | get_value "due_date" )
                itype=$( echo "$data" | get_value "type" )
                severity=$( echo "$data" | get_value "severity" )
                title=$( echo "$data" | get_value "title" )
                status=$( echo "$data" | get_value "status" )
                #echo "$data" | get_value "date_created"
                #echo "$RESULT"
                [ -z "$due_date" ] && due_date="                "
                echo "$ii $due_date ${status:0:3} ${severity:0:3} ${itype:0:3} $title"
            done
            ;;
        "upcoming2" | "upc2" )
        # uses hash_data but is slow
            tasks=$(egrep -l -m 1 $FLAG "^status: (started|open)" $FILELIST)
            output=""
            for ii in $tasks
            do
                data=$( cat $ii )
#                array_data "$data" # this did not work since it was in a subshell
#                itype=${field_array[ $( get_field_index "type" ) ]}
#                severity=${field_array[ $( get_field_index "severity" ) ]}
#                status=${field_array[ $( get_field_index "status" ) ]}
#                title=${field_array[ $( get_field_index "title" ) ]}
                 hash_data "$data"
                 itype=`hash_echo "DATA" "type"`
                 severity=$( hash_echo "DATA" "severity" )
                 due_date=$( hash_echo "DATA" "due_date" )
                 title=$( hash_echo "DATA" "title" )
                 status=$( hash_echo "DATA" "status" )
                 #desc=$( hash_echo "DATA" "description" )
                 #echo "$ii"
                 #echo -e "$desc"

                [ -z "$due_date" ] && due_date="                "
                #echo "$ii\t$due_date\t${status:0:3}\t${severity:0:3}\t${itype:0:3} $title"
                output+="$ii\t$due_date\t${status:0:3}\t${severity:0:3}\t${itype:0:3} $title\n"
            done
            echo -e "$output" | sort -k2
            ;;
            "tsvupc" )
            # now check field 7, convert to unix epoch and compare to now, if greater.
            # if less then break out, no more printing
            now=`date '+%Y-%m-%d'`
            tomorrow=`date --date="tomorrow" '+%Y-%m-%d'`
            cat "$TSV_FILE" | sort -t$'\t' -k7 -r | while read LINE
            do
                due_date=$( echo "$LINE" | cut -f7 )
                #currow=$( date --date="2009-11-25 00:00" +%s )
                currow=$( date --date="$due_date" +%s )
                today=$( date +%s )
                if [ $currow -ge $today ];
                then
                    if [ $now == ${due_date:0:10} ];
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
            ;;


* )
    usage
    ;;
esac
