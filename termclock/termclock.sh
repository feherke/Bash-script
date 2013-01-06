#!/bin/bash

# terminal clock   version 1.3   september 2008   written by Feherke
# draws an analog clock from letters

angle=( '10000' '9945' '9781' '9510' '9135' '8660' '8090' '7431' '6691' '5877' '5000' '4067' '3090' '2079' '1045' '0' )
mark=( 's' 'm' 'h' )
size=( 9 7 5 )

function init()
{
  dimx=$( tput 'cols' ); dimy=$( tput 'lines' )
  centx=$(( (dimx-1)/2 )); centy=$(( (dimy-1)/2 ))
  last=( 0 0 0 )

  for ((i=0;i<60;i++)); do
    for ((j=0;j<10;j++)); do
      posx[i*10+j]="$(( sin[i]*(centx/10*(j+1))/10000+centx ))"
      posy[i*10+j]="$(( -cos[i]*(centy/10*(j+1))/10000+centy ))"
    done
  done

  out="$(
    for ((i=1;i<=12;i++)); do
      tput 'cup' "$(( -cos[(i*5)%60]*centy/10000+centy ))" "$(( sin[(i*5)%60]*centx/10000+centx ))"; echo -n "$i"
    done
  )"

  tput 'clear'
  echo -n "$out"
}

if type usleep > /dev/null 2>&1; then
  sleep='usleep 250000'
elif type sleep > /dev/null 2>&1; then
  sleep .01 > /dev/null 2>&1 && sleep='sleep .25' || sleep='sleep 1'
else
  sleep='read -t 1'
fi

for ((i=0;i<15;i++)); do
  cos[i]="${angle[i]}"; sin[i]="${angle[15-i]}"
  cos[i+15]="-${angle[15-i]}"; sin[i+15]="${angle[i]}"
  cos[i+30]="-${angle[i]}"; sin[i+30]="-${angle[15-i]}"
  cos[i+45]="${angle[15-i]}"; sin[i+45]="-${angle[i]}"
done

trap init SIGWINCH
trap 'tput clear' EXIT

init

while :; do

  read -a curr <<< "$( date +'%-S %-M %l' )"
  curr[2]=$(( (curr[2]%12*60+curr[1])/12 ))

  [[ "${last[*]}" == "${curr[*]}" ]] && { $sleep; continue; }

  out="$(
    for ((j=0;j<3;j++)); do
      for ((i=0;i<size[j];i++)); do
        tput 'cup' "${posy[last[j]*10+i]}" "${posx[last[j]*10+i]}"; echo -n ' '
        tput 'cup' "${posy[curr[j]*10+i]}" "${posx[curr[j]*10+i]}"; echo -n "${mark[j]}"
      done
    done
    tput 'cup' "$centy" "$centx"; echo -n $'o\b'
  )"
  echo -n "$out"

  last=( "${curr[@]}" )

done
