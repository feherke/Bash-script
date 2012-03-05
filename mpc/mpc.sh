#!/bin/bash

# mpc frontend   version 1.6   may 2011   written by Feherke
# simple frontend for the mpc client for mpd

shopt -s extglob

readonly version='1.6'

if [[ "$1" == 'main' ]]; then ### display main dialog ###

# button color
  x='3'; c='3'; v='3'; r='3'; s='3'; i='3'; f='3'

# read status
  action=''
  title=''
  while read -r str; do
    if [[ "$str" =~ ^\[(playing|paused)\][[:space:]]+#.*\(([[:digit:]]+)%\) ]]; then # current action
      action="${BASH_REMATCH[1]}"
      position="${BASH_REMATCH[2]}"
    elif [[ "$str" =~ volume:[[:space:]]*([[:digit:]]+)%[[:space:]]+repeat:[[:space:]]*(on|off)[[:space:]]+random:[[:space:]]*(on|off)([[:space:]]+single:[[:space:]]*(on|off))? ]]; then # playing mode
      volume="${BASH_REMATCH[1]}"
      [[ "${BASH_REMATCH[2]}" == 'on' ]] && r='1'
      [[ "${BASH_REMATCH[3]}" == 'on' ]] && s='1'
      [[ "${BASH_REMATCH[5]}" == 'on' ]] && i='1'
      [[ ! "${BASH_REMATCH[5]}" ]] && i='7' # inactive before mpd v0.15
    elif [[ "$str" =~ ^file:[[:space:]](.*) ]]; then # file: on title's second line
      file="${BASH_REMATCH[1]}"
    else # nothing special, probably title's first line
      [[ "$title" ]] || title="$str"
    fi
  done <<< "$( mpc -f '[[[%artist% - ]%title%]|%name%|%file%]\nfile: %file%' )"

  case "$action" in
    'playing') x='1' ;;
    'paused') c='1' ;;
    '') v='1' ;;
  esac

  str="$( mpc crossfade )" # crossfade status
  [[ "$str" =~ crossfade:[[:space:]]+([[:digit:]]+) ]] && {
    cross="${BASH_REMATCH[1]}"
    (( cross )) && f='1'
  }

# current title
  [[ "$action" == '' ]] && title='[      no play in progress       ]' || echo -en "\e]2;$title - MPC\007"
  title="${title##*/}"; title="${title%.*}"
  echo -e "\e[3${x}m${title:0:34}\e[0m"

# playing progress
  [[ "$action" == '' ]] && {
    echo $'\e[33m----------------------------------\e[0m'
  } || { [[ "$file" =~ ^https?:// ]] && {
    echo $'\e[33m[       streaming content        ]\e[0m'
  } || {
    (( position=position*34/100 ))
    echo -n $'\e[31m'
    for ((j=0;j<position;j++)); do echo -n '-'; done
    echo -n $'\e[41;30mO\e[0;33m'
    for ((j=position+1;j<34;j++)); do echo -n '-'; done
    echo $'\e[0m'
  }; }

# button group
  echo -e "\e[43;30m|<\e[0m \e[4$x;30m >\e[0m \e[4$c;30m||\e[0m \e[4$v;30m[]\e[0m \e[43;30m>|\e[0m  \e[4$r;30m»»\e[0m \e[4$s;30m¿?\e[0m \e[4$i;30m()\e[0m \e[43;30m.<\e[0m \e[4$f;30m><\e[0m  \e[43;30m:=\e[0m"
  echo 'z  x  c  v  b   r  s  i  a  f   p'

# volume slider
  for ((j=0;j<=10;j++)); do
    (( j )) && echo -n '--'
    (( j==volume/10 )) && echo -n $'\e[41;30mO\e[0m' || echo -n $'\e[43;30m|\e[0m'
  done
  echo -e "  \e[43;30mi\e[0m"
  for ((j=0;j<=10;j++)); do
    (( j )) && { (( j-1==volume/10 )) && echo -n '+' || echo -n ' '; }
    (( j )) && echo -n "${j: -1}" || echo -n 'm'
    (( j<10 )) && { (( j+1==volume/10 )) && echo -n '-' || echo -n ' '; }
  done
  echo -n '  ?'

# read command
  read -n 1 -s -t 5 a
  case "$a" in
    'z') par='prev' ;;
    'x') par='play' ;;
    'c') par='pause' ;;
    'v') par='stop' ;;
    'b') par='next' ;;
    'r') par='repeat' ;;
    's') par='random' ;;
    'i') par='single' ;;
    'a') par=( 'seek' '0%' ) ;;
    'f') par=( 'crossfade' "$(( cross?0:2 ))" ) ;;
    'm') par=( 'volume' '0' ) ;;
    '1'|'2'|'3'|'4'|'5'|'6'|'7'|'8'|'9') par=( 'volume' "${a}0" ) ;;
    '0') par=( 'volume' '100' ) ;;
    '+'|'-') par=( 'volume' "$a"'10' ) ;;
    'p') xterm -geometry '39x30-5-30' +sb -bg 'black' -fg 'gray' -T 'MPC Playlist' -e "$0" 'playlist' ;;
    '?') xterm -geometry '45x13-5-30' +sb -bg 'black' -fg 'gray' -T 'MPC Information' -e "$0" 'statinfo' ;;
  esac
  [[ "${par[*]}" ]] && mpc -q "${par[@]}"

elif [[ "$1" == 'playlist' ]]; then ### display playlist dialog ###

# playlist list
  IFS=$'\n'
  list=( $( mpc lsplaylists | sort -f ) )
  IFS=$' \t\n'

  nrlist="${#list[@]}"
  nrpage="$(( (nrlist+26-1)/26 ))"
  page='0'

# loop to make possible the paging
  while :; do
    clear

# playlist page
    for ((j=0;j<26;j++)); do
      (( page*26+j<nrlist )) && printf $'\e[33m%b\e[0m %s\n' "$( printf '\\x%x' "$(( j+97 ))" )" "${list[page*26+j]:0:33}" || echo # "
    done

# playlist pager
    for ((j=0;j<10;j++)); do
      (( j<nrpage )) && {
        str="${list[j*26]:0:1}"
        str2="${list[j*26+25]:-${list[nrlist-1]}}"
        str2="${str2:0:1}"
        c="$(( j==page?1:3 ))"
        printf '\e[4%d;30m%s-%1s\e[0m' "$(( j==page?1:3 ))" "${str,}" "${str2,}"
      } || echo -n $'\e[47;30m   \e[0m'
      (( j<10-1 )) && echo -n ' '
    done
    echo
    for ((j=0;j<10;j++)); do
      (( j<nrpage && j-1==page )) && echo -n '+' || echo -n ' '
      e="$(( (j+1)%10 ))"
      echo -n "${e: -1}"
      (( j+1==page )) && echo -n '-' || echo -n ' '
      (( j<10-1 )) && echo -n ' '
    done
    echo

    echo -e "current playlist : \e[31m$( mpc playlist | wc -l )\e[0m entries"
    echo -n 'load : a..z replace, A..Z append'

# read command
    read -n 1 -s -t 15 a
    case "$a" in
      @([0-9])) (( (a+10-1)%10<nrpage )) && (( page=(a+10-1)%10 )) ;;
      @([a-z]))
        [[ "$a" == "${a,}" ]] && mpc -q clear
        mpc -q load "${list[page*26+$( printf '%d' "'${a,}" )-97]}" # "
        break
      ;;
      '+') (( page<nrpage-1 )) && (( page++ )) ;;
      '-') (( page>0 )) && (( page-- )) ;;
      *) break ;;
    esac

  done

elif [[ "$1" == 'statinfo' ]]; then ### display status information dialog ###

# display information
  while IFS=':' read -r str str2; do
    [[ "$str" ]] && printf '%-15s \e[31m:\e[0m \e[33m%s\e[0m\n' "$str" "${str2##+( )}"  || echo
  done <<< "$(
    mpc version
    mpc help | sed -n '2p'
    echo "mpc.sh version: $version"
    echo
    mpc stats
  )"

# display dumb button
  echo -n $'\e[43;30mok\e[0m '

# wait for keypress
  read -n 1 -s -t 15

else ### not interactive yet ###

  xterm -geometry '34x6-5-30' +sb -bg 'black' -fg 'gray' -T 'MPC' -e "$0" 'main'

fi
