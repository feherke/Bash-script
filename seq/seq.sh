#!/bin/bash

# seq.sh   version 1.2   april 2008   written by Feherke
# kind of embeded seq with reqursive call

function repseq()
{
  local i seq pat
  seq="$( sed -r '/\{(-w)?[[:digit:][:space:]]+\}/!d;s/(\{(-w)?[[:digit:][:space:]]+\}).*/\1/;s/.*\{((-w)?[[:digit:][:space:]]+)\}.*/\1/' <<< "$1" )"

  if [[ ! "$seq" ]]; then
    echo "$1"
    return
  fi
  pat="$( sed -r 's/\{'"$seq"'\}/\{###\}/' <<< "$1" )"
  for i in $( seq $seq ); do
    repseq "$( sed -r 's/\{###\}/'"$i"'/;s/\{#'"$2"'\}/'"$i"'/g' <<< "$pat" )" $(( $2+1 ))
  done
}



# |\/| /\ | |\|

for par; do

  [[ "$par" == '-?' || "$par" == '-h' || "$par" == '--help' ]] && {
    cat << 'ENDOFTEXT'
seq.sh   version 1.2   april 2008   written by Feherke
kind of embeded seq with reqursive call

Syntax :
  seq.sh

Parameters :
  [none]

read the standard input, parse each line of text and extend the embeded seq
parameters delimited with braces, also replacing the diez level marks too
ENDOFTEXT
    exit
  }

done


while IFS='' read -r str; do
  repseq "$str" 1
done
