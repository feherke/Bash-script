#!/bin/bash

# killrenegade   version 1.2   august 2008   written by Feherke
# kill the processes with given name which use to much resources


shopt -s extglob

signal=( '' 'SIGHUP' 'SIGINT' 'SIGQUIT' 'SIGILL' 'SIGTRAP' 'SIGABRT' 'SIGBUS' 'SIGFPE' 'SIGKILL' 'SIGUSR1' 'SIGSEGV' 'SIGUSR2' 'SIGPIPE' 'SIGALRM' 'SIGTERM' 'SIGSTKFLT' 'SIGCHLD' 'SIGCONT' 'SIGSTOP' 'SIGTSTP' 'SIGTTIN' 'SIGTTOU' 'SIGURG' 'SIGXCPU' 'SIGXFSZ' 'SIGVTALRM' 'SIGPROF' 'SIGWINCH' 'SIGIO' 'SIGPWR' 'SIGSYS' )
sect=( '' ); comm=(); user=(); uown=(); mcpu=(); mmem=(); sign=(); inte=()
sec=''
nr=0
verb=0


echo 'killrenegade   version 1.2   august 2008   written by Feherke'

while (( $# )); do
  case "$1" in
    '-i') shift; inifile="$1" ;;
    '--ini='*) inifile="${1#*=}" ;;
    '-V'|'--verbose') (( verb++ )) ;;
    '-v'|'--version') exit ;;
    '-h'|'--help'|'-?')
      cat <<ENDOFSYNTAX
kill the processes with given name which use to much resources
Syntax :
  killrenegade.sh [-i inifile] [-V]
Parameters :
  -i inifile | --ini=inifile  - settings file to be read ( killrenegade.ini )
  -V | --verbose  - verbose mode, use twice for more verbose ( no )
ENDOFSYNTAX
      exit
    ;;
  esac
  shift
done

selfdir="${0%/*}"
: "${inifile=${0%.sh}.ini}"
[[ -f "$inifile" ]] || { echo 'killrenegade: error no settings'; exit 1; }


echo -n 'reading settings... '

while read str; do
  [[ "$str" ]] || continue
  [[ "${str:0:1}" == '#' ]] && continue
  [[ "$str" == \[*\] ]] && {
    sec="${str:1:$(( ${#str}-2 ))}"
    [[ "$sec" == 'default' ]] && nr=0 || { [[ "$sec" != 'general' ]] && { nr=${#sect[@]}; sect[nr]="$sec"; } }
    continue
  }
  [[ "$sec" ]] || continue
  [[ "${str#?*=}" != "$str" ]] && {
    IFS='=' read -r key val <<< "$str"
    if [[ "$sec" == 'general' ]]; then
      eval "$key=$val"
    else
      case "$key" in
        'command') comm[nr]="$val" ;;
        'user') user[nr]="$val" ;;
        'belong') uown[nr]="$val" ;;
        'processor') mcpu[nr]="$val" ;;
        'memory') mmem[nr]="$val" ;;
        'signal') sign[nr]="$val" ;;
        'interval') inte[nr]="$val" ;;
      esac
    fi
  }
done < "$inifile"

(( nrsec=${#sect[@]}-1 ))

echo "ok, $nrsec sections found"


echo -n 'verifying settings... '

err=0
for ((i=1;i<=nrsec;i++)); do 
  comm[i]="${comm[i]:-comm[0]}"
  user[i]="${user[i]:-${user[0]:-root}}"
  uown[i]="${uown[i]:-${uown[0]:-no}}"
  mcpu[i]="${mcpu[i]:-${mcpu[0]:-10}}"
  mmem[i]="${mmem[i]:-${mmem[0]:-25}}"
  sign[i]="${sign[i]:-${sign[0]:-SIGTERM}}"
  inte[i]="${inte[i]:-${inte[0]:-60}}"
  last[i]=0
  [[ "${sign[$i]}" == @([[:alpha:]])* ]] || sign[i]="${signal[sign[i]]}"
  [[ "${comm[i]}" ]] || (( err++ ))
done

(( err )) && { echo "killrenegade: $err error(s) in settings"; exit 2; }

last[0]=$( date +'%s' )
[[ "$logfile" && ! -e "$logfile" ]] && touch "$logfile"
[[ "$logfile" && -x "$selfdir/killstatistic.awk" ]] || htmldir=''
[[ "$htmldir" && ! -e "$htmldir" ]] && mkdir -p "$htmldir"

echo 'ok, defaults used where needed'


[[ "$USER" != 'root' ]] && {
  echo "running as $USER, restrictions applied"
  for ((i=1;i<=nrsec;i++)); do 
    user[i]="$USER"
    uown[i]='yes'
  done
}

for ((i=0;i<=nrsec;i++)); do echo -e "$i\t${sect[i]}\t${comm[i]}\t${user[i]}\t${uown[i]}\t${mcpu[i]}\t${mmem[i]}\t${sign[i]}\t${inte[i]}"; done

(( verb )) && echo 'verbose mode on, will announce kills'


echo "started on $( date ), Ctrl-C to stop..."

while :; do
  (( verb>1 )) && date
  
  now=$( date +'%s' )
  for ((i=1;i<=nrsec;i++)); do
    if (( last[i]+inte[i]<=now )); then

      (( verb>1 )) && echo " - ${sect[i]}"

      ps h -C "${comm[i]}" -o 'pid user=twentycharacterswide %cpu %mem' | \
      while read pid user cpu mem; do

        [[ "${user[i]}" != '-' ]] && { grep -q -w $( sed -n '/no/i-v' <<< "${uown[i]}" ) "$user" <<< "${user[i]}" || continue; }

        cpui="${cpu%.*}"
        memi="${mem%.*}"

	(( cpui>mcpu[i] || memi>mmem[i] )) && {
	  (( verb )) && echo -n "kill ${comm[i]} ( $pid ) "
	  for sig in ${sign[i]}; do
	    (( verb )) && echo -n "$sig... "
	    kill -"$sig" "$pid" && break
	  done
	  (( verb )) && echo 'done'
          [[ "$logfile" ]] && echo -e "$user\t$( date +'%Y-%m-%d %H:%M:%S' )\t$cpu\t$mem\t${comm[$i]}\t$sig" >> "$logfile"
        }
	
      done
	
      last[i]=$now

    fi
  done

  [[ "$htmldir" ]] && (( last[0]+build<=now )) && {
    (( verb )) && echo 'build'
    "$selfdir/killstatistic.awk" -v htmldir="$htmldir" "$logfile" &
    last[0]=$now
  }

  next=0
  for ((i=1;i<=nrsec;i++)); do temp=$(( last[i]+inte[i] )); (( next==0 || next>temp )) && next=$temp; done

  now=$( date +'%s' )
  (( next>now )) && sleep $(( next-now ))
done
