#!/bin/bash

echo 'Symlink back from NTFS   version 1.0   may 2011   written by Feherke'
echo 'corrects symlinks copied back from NTFS'

shopt -s extglob

defaultsuffix='.back_from_ntfs'
searchin=()
maxsize='1024'
recursive=''
cautious=''
simulate=''
while (( $# )); do
  case "$1" in
    '-m') shift; maxsize="$1" ;;
    '--max-size='*) maxsize="${1#*=}" ;;
    '-r'|'--recursive') recursive='1' ;;
    '-c') shift; cautious="${1:-$defaultsuffix}" ;;
    '--cautious') cautious="$defaultsuffix" ;;
    '--cautious='*) cautious="${1#*=}" ;;
    '-s'|'--simulate') simulate='1' ;;
    '-v'|'--version') exit ;;
    '-h'|'--help'|'-?')
      echo "
Syntax :
  ${0##*/} [-m size] [-r] [-c [suffix]] [-s] [path [...]]

Parameters :
  -m, --max-size=size  - maximum size of files to check ( 1024 )
  -r, --recursive  - search the directories recursively ( no )
  -c, --cautious=suffix  - renames the found files ( no, $defaultsuffix )
  -s, --simulate  - do not change anything, just list what found ( no )
  path  - file or directory to check ( . )
"
       exit
    ;;
    *) searchin[${#searchin[@]}]="$1" ;;
  esac

  shift
done

[[ "$maxsize" != +([[:digit:]]) ]] && {
  echo "ERROR : max size $maxsize is invalid, must be integer"
  exit 1
}
(( maxsize<=10 )) && {
  echo "ERROR : max size $maxsize is too small, must be greater that 10"
  exit 1
}

[[ "${searchin[@]}" ]] || searchin=( '.' )

find ${searchin[@]} ${recursive:+-maxdepth 1} -xdev -type f -size +9c -size -"${maxsize}c" ! -name "*${cautious:-$defaultsuffix}" | \
while IFS='' read -r file; do
  (( $( wc -l < "$file" ) )) && continue
  read -n 8 str < "$file"
  [[ "$str" != $'IntxLNK\x01' ]] && continue
  target="$( sed -r 's/^IntxLNK\x01/\x00/' "$file" | recode -q utf16.. )"
  (( $? )) || continue
  [[ "$target" ]] || continue
  echo -n "$file -> $target... "
  dir="${file%/*}"
  (
    cd "$dir"
    [[ -e "$target" ]] || {
      echo 'ERROR : target not found'
      continue
    }
    [[ -w "$file" ]] || {
      echo 'ERROR : file not writable'
      continue
    }
    [[ "$simulate" ]] && {
      echo 'maybe'
      continue
    }
    if [[ "$cautious" ]]; then
      mv "$file" "$file$cautious"
    else
      rm "$file"
    fi && ln -s "$target" "$file" && echo 'ok' || echo 'ERROR'
  )
done
