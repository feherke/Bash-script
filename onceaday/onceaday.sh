#!/bin/bash

# onceaday.sh   version 1.1   august 2008   written by Feherke
# run commands only once a day


shopt -s extglob

pdate=''
pforce=0
pnotouch=0
pshow=''

while (( $# )); do
  case "$1" in
    '-d') shift; pdate="$1" ;;
    '--date='*) pdate="${1#*=}" ;;
    '-a'|'--all') pdate='*' ;;
    '-f'|'--force') pforce=1 ;;
    '-n'|'--no-touch') pnotouch=1 ;;
    '-s'|'--show') pshow='echo' ;;
    '-h'|'--help'|'-?')
      cat <<ENDOFTEXT
onceaday.sh   version 1.1   august 2008   written by Feherke
run commands only once a day

Syntax :
  onceaday.sh [-d date] [-a] [-f] [-n] [-s]

Parameters :
  -d date | --date=date  - run the commands sheduled for the given date
  -a | --all  - run all commands, regardless their scheduling
  -f | --force  - force running, even if already runned today
  -n | --no-touch  - do not touch the timestamp file
  -s | --show  - just show the matching commands, do not run them
ENDOFTEXT
      exit
    ;;
    '-v'|'--version')
      echo 'onceaday.sh 1.1'
      exit
    ;;
  esac
  shift
done

[[ "$pdate" ]] && { pforce=1; pnotouch=1; }

(( pforce )) || {
  [[ -f ~/'.onceaday' && "$( date -r ~/'.onceaday' +'%Y%j' )" == "$( date +'%Y%j' )" ]] && exit
}

(( pnotouch )) || touch ~/'.onceaday'

[[ -L "$0" ]] && self="$( readlink "$0" )" || self="$0"

config="${self%/*}/onceaday.ini"

[[ -f "$config" ]] || exit

int=( '0-59' '0-23' '1-31' '1-12' '0-6' )

[[ "$pdate" == '*' ]] || {
  for n in $( date ${pdate:+-d "$pdate"} +'%-M %k %e %-m %w' ); do now[i++]="$n"; done
}

while read -a data; do

  [[ ! "$data" || "${#data[@]}" -lt 6 || "${data[0]:0:1}" == '#' ]] && continue

  run=1
  [[ "$pdate" == '*' ]] || {
    for ((i=0;i<5;i++)); do
      [[ "${data[i]}" == '*' ]] && continue
      list=$( eval "echo \"$( sed -r 's/\*/'"${int[i]}"'/g;y/,/|/;s!([[:digit:]]{1,2})-([[:digit:]]{1,2})/?([[:digit:]]{0,2})!$( seq -s "|" \1 \3 \2 )!g' <<< "${data[i]}")\"" ) # '
      [[ "${now[i]}" != @($list) ]] && run=0
    done
  }

  (( run )) && {
    unset data[0] data[1] data[2] data[3] data[4]
    [[ "${data[5]:0:2}" == '~/' ]] && data[5]="$HOME/${data[5]:2}"
    if [[ -f "${data[5]}" && ! -x "${data[5]}" ]]; then
      if [[ "${data[5]##*.}" == 'txt' ]]; then
        $pshow cat ${data[*]}
      else
        $pshow source ${data[*]}
      fi
    else
      $pshow ${data[*]}
    fi
  }

done < "$config"
