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
#
#### --- cleanup code use at start ---- ####
TMP_FILE=${TMPDIR:-/tmp}/prog.$$
trap "rm -f $TMP_FILE.?; exit 1" 0 1 2 3 13 15
PROGNAME=$(basename "$0")
TODO_SH=$PROGNAME
#TODO_DIR="/Users/rahul/work/projects/rbcurse"
export PROGNAME
Date="2009-11-06"
DATE_FORMAT='+%Y-%m-%d %H:%M'
arg0=$(basename "$0")

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

        addto DEST "TEXT TO ADD"
      See "help" for more details.
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
    exit 0
}
ask()
{
    select CHOICE in $CHOICES
    do
        echo "$CHOICE"
        return
    done
}

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


# Emulates:  echo hash[key]
#
# Params:
# 1 - hash
# 2 - key
# 3 - echo params (like -n, for example)
function hash_echo {
    eval "echo $3 \"\$${Hash_config_varname_prefix}${1}_${2}\""
}
hash_set "VALUES" "status" "open closed started stopped canceled "
hash_set "VALUES" "severity" "normal critical serious"
hash_set "VALUES" "type" "bug feature enhancement task"
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
        items=$(
        grep -h -m 1 '^title:' $FILELIST \
        | cut -c 8-  \
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
        TOTALTASKS=$( ls $ISSUES_DIR/*.txt | wc -l )


        echo "--"
        echo "${NUMTASKS:-0} of ${TOTALTASKS:-0} issues shown from $ISSUES_DIR"

        statuses=$( grep -h -m 1 '^status:' $FILELIST | sort -u | cut -c 9- )
        for ii in $statuses
        do
            #echo  -n "$ii:"
            printf "%12s: " "$ii"
            grep -m 1 "^status: $ii" $FILELIST | wc -l
        done
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
    local now=`date '+%Y-%m-%d %H:%M'`
    echo "- LOG,$now,$key,$oldvalue,$newline" >> $file

}
## get_code "type"
get_code()
{
    RESULT=
    CHOICES=`hash_echo "VALUES" "$1"`
    echo "select a value for $1"
    [ ! -z "$2" ] && echo "[default is $2]"
    defaultval=${2:-"---"}
    if [ ! -z "${CHOICES}" ] 
    then
        local input=`ask` 
        [ -z "$input" ] && input=$defaultval
        echo "$input"
        RESULT=$input
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
       result=$(date --date "$ginput" "$DATE_FORMAT")
   else
       result=$ginput
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
## returns title for a task id
get_title()
{
    item=${1:-$item}
    local file=$ISSUES_DIR/$item.txt
    local mtitle=$(grep -m 1 "^title:" $file | cut -d':' -f2-)
    echo "$mtitle"
}
## returns value for id and key
get_value_for_id()
{
    local file=$ISSUES_DIR/$1.txt
    local key=$2
    [ -z "$2" ] && die "get_value requires 2 params"
    local oldvalue=$(grep -m 1 "^$key:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    echo "$oldvalue"
}
get_value_from_file()
{
    local file=$1
    local key=$2
    [ -z "$2" ] && die "get_value requires 2 params"
    local oldvalue=$(grep -m 1 "^$key:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    echo "$oldvalue"
}
change_status()
{
    item=$1
    action=$2
    errmsg="usage: $TODO_SH $action task#"
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    [ ! -r "$file" ] && die "No such file: $file"
    reply="status"; input="$action";
    oldvalue=`get_value_for_id $item $reply`
    [ "$oldvalue" == "$action" ] && die "$item is already $oldvalue"
    var=$( printf "%s" "${action:0:3}" | tr 'a-z' 'A-Z' )
    echo "$item is currently $oldvalue"
        newline="$reply: $input"
        now=`date '+%Y-%m-%d %H:%M'`
        sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
    echo "$item is now $input"
        log_changes $reply "$oldvalue" $input $file
        mtitle=`get_title $item`
        [ ! -z "$EMAIL_TO" ] && cat "$file" | mail -s "[$var] $mtitle" $EMAIL_TO
        show_diffs 
}
## for actoins that require a bug id
## sets item, file
common_validation()
{
    item=$1
    shift
    local errmsg="$*"
    #local argct=${3:-2}

    #[ "$#" -ne $argct ] && die "$errmsg"
    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    [ ! -r "$file" ] && die "No such file: $file"

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
    count=$( echo $fields | tr ' ' '\n' | wc -l ) 
        str1=""
        declare -a widths
        ctr=0
        for ii in $fields
        do
            get_display_widths $ii
            widths[$ctr]=$RESULT
            let ctr+=1
            if [ -z "$str1" ];
            then
                str1=$( grep "^${ii}:" $FILELIST )
            else
                str1="$str1\n"$( grep "^${ii}:" $FILELIST )
            fi
        done
        str=""
        #for file in *.txt #$FILELIST
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

     
## ADD FUNCTIONS HERE
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
TODOTXT_SORT_COMMAND=${TODOTXT_SORT_COMMAND:-env LC_COLLATE=C sort -f -k3}


[ -r "$PROG_CFG_FILE" ] || die "Fatal error: Cannot read configuration file $PROG_CFG_FILE"

. "$PROG_CFG_FILE"

ACTION=${1:-$PROG_DEFAULT_ACTION}

[ -z "$ACTION" ]    && usage
# added RK 2009-11-06 11:00 to save issues (see edit)
ISSUES_DIR=$TODO_DIR/.todos

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

FILELIST=${FILELIST:-*.txt}
#[ $# -eq 0 ] && {
#exit 0;
#}

# == HANDLE ACTION ==
action=$( printf "%s\n" "$ACTION" | tr 'A-Z' 'a-z' )

#action=$( printf "%s\n" "$1" | tr 'A-Z' 'a-z' )
shift

case $action in
"add" | "a")
    if [[ -z "$1" ]]; then
        echo -n "Enter a short title/subject: "
        read atitle
    else
        atitle=$*
    fi
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
    prompts=
    [ "$PROMPT_ASSIGNED_TO" == "yes" ] && {
        [ ! -z "$ASSIGNED_TO" ] && prompts=" [default is $ASSIGNED_TO]"
        echo -n "Enter assigned to $prompts: "
        read assigned_to
        [ ! -z "$assigned_to" ] && ASSIGNED_TO=$assigned_to
    }

    serialid=`incr_id`
    task="[Task #$serialid]"
    todo="$task $atitle"
    [ -d "$ISSUES_DIR" ] || mkdir "$ISSUES_DIR"
    editfile=$ISSUES_DIR/${serialid}.txt
    if [ -f $editfile ];
    then
        $EDITOR $editfile
    else
      #  echo "title: $todo" > "$editfile"
        now=`date '+%Y-%m-%d %H:%M'`
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
    $EDITOR $editfile
    fi
    process_quadoptions  "$SEND_EMAIL" "Send file by email?"
    #[ $RESULT == "yes" ] && get_input "emailid" "$ASSIGNED_TO"
    [ "$RESULT" == "yes" ] && {
        get_input "emailid" "$EMAIL_TO"
        #"cat $file | mail -s $title  "
        [ ! -z "$EMAIL_TO" ] && cat "$editfile" | mail -s "$todo" $EMAIL_TO
    }

       cleanup;;
"del" | "rm")
    errmsg="usage: $TODO_SH $action task#"
    item=$1
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    # TODO only confirm if not forced
    grep -m 1 "^title" $file
    mv $file $file.bak

       cleanup;;
"edit" | "ed")
    errmsg="usage: $TODO_SH $action task#"
    item=$1
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    $EDITOR $file

       cleanup;;
"modify" | "mod")
    errmsg="usage: $TODO_SH $action task#"
    modified=0
    item=$1
    severity_values="critical serious normal"
    type_values="bug feature enhancement task"
    [ -z "$item" ] && die "$errmsg"
    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    MAINCHOICES=$(grep '^[a-z_0-9]*:' $file | egrep -v '^log:|^date_|^id:' | cut -d':' -f1  )
    MAINCHOICES="$MAINCHOICES quit"
    while true
    do
        CHOICES="$MAINCHOICES"
    echo "Select field to edit"
    #echo $CHOICES
    reply=`ask` 
    [ "$reply" == "quit" ] && {
      [ $modified -gt 0 ] && {
      mtitle=$(grep -m 1 "^title:" $file | cut -d':' -f2-)
        [ ! -z "$EMAIL_TO" ] && cat "$file" | mail -s "[MOD] $mtitle" $EMAIL_TO
        }
      break
    }
    #echo "reply is $reply"
    oldvalue=$(grep -m 1 "^$reply:" $file | cut -d':' -f2-)
    oldvalue=${oldvalue## }
    [ -z "$oldvalue" ] || echo "Select new $reply (old was \"$oldvalue\")"
    CHOICES=`hash_echo "VALUES" "$reply"`
    if [ ! -z "${CHOICES}" ] 
    then
        input=`ask` 
        echo "input is $input"
        newline="$reply: $input"
        now=`date '+%Y-%m-%d %H:%M'`
        sed -i.bak -e "/^$reply: /s/.*/$newline/" $file
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
                   log_changes $reply "${#oldvalue} chars" "${#text} chars" "$file"
                   show_diffs 
                   let modified+=1
                }
            ;;
            "comment" )
            # CCC
                echo "Enter new $reply:"
                read input
                [ -z "$input" ] || {
                    start=$(sed -n "/^$reply:/=" $file)
                    now=`date '+%Y-%m-%d %H:%M'`
                    text="- $now: $input"
ex - $file<<!
${start}a
$text
.
x
!
        log_changes $reply "${input:0:15} ..." "${#input} chars" "$file"
                   let modified+=1
    }
                ;;
            "description" | "fix" )
            # FIXME single line keys like title bonking
            # i print them on next line, since i don't know they were on same row.
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
    show_diffs $file $file.bak.1 
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
"select" | "sel")
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

        fields=$( echo "$fields" | sed 's/ /|^/g' )
        fields="^$fields"
        echo "fields::$fields"
        data=$( egrep -h $fields $FILELIST | cut -d':' -f2- )
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
        "log" )
        errmsg="usage: $TODO_SH $action ITEM#"
        common_validation $1 $errmsg 
        data=`extract_header $action $file`
        echo "$data"

        ;;

* )
    usage
    ;;
esac
