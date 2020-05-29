#!/bin/bash

# Mine Sweeper   version 1.1   august 2008   written by Feherke
# the classic game in text mode


shopt -s extglob
IFS=''

piece=( $'\e[1;30m.' $'\e[1;34m1' $'\e[1;32m2' $'\e[1;35m3' $'\e[1;36m4' $'\e[1;31m5' $'\e[33m6' $'\e[1;37m7' $'\e[0;40;37m8' $'\e[0;40;37m#' $'\e[0;40;31mF' $'\e[0;40;33m?' $'\e[1;31m*' $'\e[0;40;31mx' )
size=( 'S ' 10 10 15   'M ' 15 15 33   'L ' 20 20 60   'XL' 30 20 90 )

function drawboard()
{

  [[ "$dxt" ]] || { dxt=$mx; dyf=0; dyt=$my; }

  tput 'cup' $(( dyf+2 )) 0
  echo -n $'\e[40m'
  for ((j=dyf;j<dyt;j++)); do for ((i=0;i<dxt;i++)); do echo -n " ${piece[board[j*mx+i]]}"; done; echo ' '; done
  echo -n $'\e[0m'

  dxt=''

}

function newgame()
{

#  n="$( expr index 'nNmM' "$1" )" # line kept as human readable version :(
  n='nNmM'; n="${n%$1*}"; n=${#n}

  mx=${size[n*4+1]}; my=${size[n*4+2]}; mb=${size[n*4+3]}; mf=0

  echo -n $'\e[0m'
  clear
  echo 'Mine Sweeper   version 1.1   august 2008   written by Feherke'
  echo "board : ${size[n*4]}   size : $mx*$my   mine : $mb   flag : $mf    "$'\e[43;30m:)\e[0m'

  for ((i=0;i<mx*my;i++)); do bomb[i]=0; board[i]=9; done
  for ((i=0;i<mb;i++)); do while :; do r=$(( RANDOM%(mx*my) )); (( bomb[r] )) || break; done; bomb[r]=1; done

  drawboard
  echo $'<\e[1mh\e[0m/\e[1mj\e[0m/\e[1mk\e[0m/\e[1ml\e[0m> Move <\e[1mg\e[0m> Step <\e[1mf\e[0m> Flag <\e[1mn\e[0m/\e[1mN\e[0m/\e[1mm\e[0m/\e[1mM\e[0m> New <\e[1mq\e[0m> Quit'

  cx=0; cy=0
  status=1

}

function gameover()
{

  for ((i=0;i<mx;i++)); do for ((j=0;j<my;j++)); do
    (( bomb[j*mx+i]==1 && board[j*mx+i]==9 )) && board[j*mx+i]=12
    (( bomb[j*mx+i]==0 && board[j*mx+i]==10 )) && board[j*mx+i]=13
  done; done

  drawboard
  tput 'cup' 1 52
  echo -n $'\e[43;30m:(\e[0m'

  status=0

}

function makestep()
{
  local i j
  local sx=${1:-$cx} sy=${2:-$cy}

  [[ "${board[sy*mx+sx]}" != @(9|10|11) ]] && return
  (( bomb[cy*mx+cx]==1 )) && { gameover; return; }

  [[ "$1" ]] || {
    dxt=$sx; dyf=$sy; dyt=$sy
    tput 'cup' 1 52
    echo -n $'\e[43;30m:o\e[0m'
  }
  
  (( dxt=dxt>sx?dxt:sx+1 )); (( dyf=dyf<sy?dyf:sy )); (( dyt=dyt>sy?dyt:sy+1 ))
  
  n=0
  for ((i=-1;i<=1;i++)); do for ((j=-1;j<=1;j++)); do
    (( (i!=0 || j!=0) && sx+i>=0 && sx+i<mx && sy+j>=0 && sy+j<my )) && (( bomb[(sy+j)*mx+(sx+i)]==1 )) && (( n++ ))
  done; done
  board[sy*mx+sx]=$n

  (( n )) || {
    for ((i=-1;i<=1;i++)); do for ((j=-1;j<=1;j++)); do
      (( (i!=0 || j!=0) && sx+i>=0 && sx+i<mx && sy+j>=0 && sy+j<my )) && makestep $(( sx+i )) $(( sy+j ))
    done; done
  }

  [[ "$1" ]] || {
    drawboard
    tput 'cup' 1 52
    echo -n $'\e[43;30m:)\e[0m'
  }

}

function putflag()
{

  [[ ${board[cy*mx+cx]} != @(9|10|11) ]] && return
  
  board[cy*mx+cx]=$(( (board[cy*mx+cx]-9+1)%3+9 ))

  (( board[cy*mx+cx]==10 )) && (( mf++ ))
  (( board[cy*mx+cx]==11 )) && (( mf-- ))

  (( mf>=mb )) && {
    if (( board[cy*mx+cx]==10 )); then
      board[cy*mx+cx]=11
    else
      board[cy*mx+cx]=9
      (( mf-- ))
    fi

    n=0
    for ((i=0;i<mx;i++)); do for ((j=0;j<my;j++)); do
      (( bomb[j*mx+i]==1 && board[j*mx+i]==10 )) && (( n++ ))
    done; done
  
    tput 'cup' 1 52
    echo -n $'\e[43;30mB)\e[0m'
  }

  tput 'cup' 1 47
  echo -en "\e[0m$mf  "

}



# |\/| /\ | |\|

newgame 'n'

while :; do

  tput 'cup' $(( cy+2 )) $(( cx*2 ))
  echo -en "\e[1;40;37m[${piece[board[cy*mx+cx]]}\e[1;37m]\b\b"

  read -s -n 1 a
  [[ "$a" == '' ]] && { read -s -n 1 a; [[ "$a" == '[' ]] && read -s -n 1 a; }
  
  echo -en "\b ${piece[board[cy*mx+cx]]} \b\b"

  (( status!=1 )) && [[ "$a" != [nNmMrq] ]] && continue

  case "$a" in
    'h'|'a'|'D'|'4') (( cx>0?cx--:0 )) ;;
    'j'|'s'|'B'|'2') (( cy<my-1?cy++:0 )) ;;
    'k'|'w'|'A'|'8') (( cy>0?cy--:0 )) ;;
    'l'|'d'|'C'|'6') (( cx<mx-1?cx++:0 )) ;;
    'g'|' '|'') makestep ;;
    'f'|'0') putflag ;;
    'n'|'N'|'m'|'M') newgame "$a" ;;
    'r') drawboard ;;
    'q') break ;;
  esac

done

echo -n $'\e[0m'
clear
