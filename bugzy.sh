#!/bin/bash
#*******************************************************#
# A simple file based bug tracker                       #
#                                                       #
# rkumar                                                #
# $Id$  #
#*******************************************************#
## TODO : AAA editing of title and other single line  - DONE for comment
## TODO : BBB add id to format since user can edit id from title - DONE
## TODO : CCC comment adding, no need to edit, just add
#
#
#### --- cleanup code use at start ---- ####
TMP_FILE=${TMPDIR:-/tmp}/prog.$$
trap "rm -f $TMP_FILE.?; exit 1" 0 1 2 3 13 15
PROGNAME=$(basename "$0")
TODO_SH=$PROGNAME
#TODO_DIR="/Users/rahul/work/projects/rbcurse"
export PROGNAME
Date="2009-11-06"
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
    FILELIST=${FILELIST:-$ISSUES_DIR/*.txt}
    #echo "list 2 FILELIST: $FILELIST"


    [ $VERBOSE_FLAG -gt 0 ] && echo "$arg0: list : $@"
    for search_term in "$@"
    do
    [ $VERBOSE_FLAG -gt 0 ] && echo "$arg0: search_term is $search_term "
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
    [ $VERBOSE_FLAG -gt 0 ] && echo "$arg0: filter_command is $filter_command "

    ## If post_filter_command is set, append it to the filter_command
    [ -n "$post_filter_command" ] && {
        filter_command="${filter_command:-}${filter_command:+ | }${post_filter_command:-}"
    }
        items=$(
        grep -h 'title' $FILELIST \
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
}
greptitles()
{
    files=$*
    #echo "files: $files"
    [ -z "$files" ] && echo "No matching files" && exit 0
    #grep -h title $files | cut -d':' -f2- 
    #grep -h title $files | cut -c 8-
    FILELIST=$files
    export FILELIST
    #echo "greptitles FILELIST: $FILELIST"
    list
}
showtitles_where()
{
    key=$1
    value=$2
    tasks=$(grep -l "$key:.*$value" $ISSUES_DIR/*.txt)
    #echo "tasks: $tasks"
    greptitles $tasks 
}
print_tasks()
{
    [ -z "$FILELIST" ] && echo "No matching files" && exit 0
    USEPRI=${USEPRI:-$DEFAULT}
        items=$(
        grep -h 'title' $FILELIST \
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
    key=$1
    oldvalue=$2
    newline=$3
    file=$4
    now=`date '+%Y-%m-%d %H:%M'`
    echo "- LOG,$now,$key,$oldvalue,$newline" >> $file

}
## ADD FUNCTIONS HERE
VERBOSE_FLAG=0
out=
file=
Dflag=
while getopts hvVf:o:D:d: flag
do
    case "$flag" in
    (h) help; exit 0;;
    (V) echo "$arg0: version @REVISION@ ($Date) Author: rkumar"; exit 0;;
    (v) VERBOSE_FLAG=1;;
    (f) file="$OPTARG";;
    (o) out="$OPTARG";;
    (D) Dflag="$Dflag $OPTARG";;
    d )
        PROG_CFG_FILE=$OPTARG
        ;;
    (*) usage;;
    esac
done
shift $(($OPTIND - 1))

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
        read input
    else
        input=$*
    fi
    serialid=`incr_id`
    task="[Task #$serialid]"
    todo="$task $input"
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

    date_created: $now
    status: open
    severity: normal
    type: task
    comment: 

    fix: 
    log:

EndUsage
    $EDITOR $editfile
    fi
       cleanup;;
"del" | "rm")
    errmsg="usage: $TODO_SH del task#"
    item=$1
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    grep "title" $file
    mv $file $file.bak

       cleanup;;
"edit" | "ed")
    errmsg="usage: $TODO_SH ed task#"
    item=$1
    [ -z "$item" ] && die "$errmsg"

    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    $EDITOR $file

       cleanup;;
"modify" | "mod")
    errmsg="usage: $TODO_SH $action task#"
    item=$1
    hash_set "VALUES" "status" "open closed started stopped canceled "
    hash_set "VALUES" "severity" "critical serious normal"
    hash_set "VALUES" "type" "bug feature enhancement task"
    severity_values="critical serious normal"
    type_values="bug feature enhancement task"
    [ -z "$item" ] && die "$errmsg"
    [[ "$item" = +([0-9]) ]] || die "$errmsg"
    file=$ISSUES_DIR/${item}.txt
    CHOICES=$(grep '^[a-z_0-9]*:' $file | egrep -v '^log:|^date_|^id:' | cut -d':' -f1  )
    echo "Select field to edit"
    #echo $CHOICES
    reply=`ask` 
    #echo "reply is $reply"
    oldvalue=$(grep "^$reply:" $file | cut -d':' -f2-)
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
        #echo "- LOG,$now,$reply,$oldvalue,$newline" >> $file
        echo "done ..."
        cat $file
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
                   diff $file $file.bak
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
    [ $VERBOSE_FLAG -gt 0 ] && {
    echo "edited file is:"
    cat $file | sed 's/^/> /'
    echo " "
    }
    diff $file $file.bak.1
                }
                
                ;;
            esac


        # actually we need to let user edit existing value in editor
    fi
       cleanup;;
"move" | "mv")
    echo "action is $action"
    echo "left is $*"
       cleanup;;
"list" | "ls")
    FILELIST=${FILELIST:-$ISSUES_DIR/*.txt}
    list "$@"
       cleanup;;
"liststat" | "lists")
    valid="|open|closed|started|stopped|canceled|"
    errmsg="usage: $TODO_SH $action $valid"
    status=$1
    [ -z "$status" ] && die "$errmsg"
    status=$( printf "%s\n" "$status" | tr 'A-Z' 'a-z' )

    count=$(echo $valid | grep -c $status)
    [ $count -eq 1 ] || die "$errmsg"
    tasks=$(grep -l "status: *$status" $ISSUES_DIR/*.txt)
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
"lbs")
    tasks=$(grep -l "severity: critical" $ISSUES_DIR/*.txt)
    #echo "tasks $tasks"
    USEPRI=$PRI_A
    export USEPRI
    FILELIST=$tasks
    export FILELIST
    [ -z "$FILELIST" ] || print_tasks
    tasks=$(grep -l "severity: serious" $ISSUES_DIR/*.txt)
    #echo "tasks $tasks"
    USEPRI=$PRI_B
    export USEPRI
    FILELIST=$tasks
    export FILELIST
    [ -z "$FILELIST" ] || print_tasks
    tasks=$(grep -l "severity: normal" $ISSUES_DIR/*.txt)
    #echo "tasks $tasks"
    USEPRI=
    export USEPRI
    FILELIST=$tasks
    export FILELIST
    [ -z "$FILELIST" ] || print_tasks
    ;;
    
* )
    usage
    ;;
esac
