#!/bin/bash

# duplicated.sh   version 1.4   august 2008   written by Feherke
# search for multiple files with the same content

echo 'duplicated.sh   version 1.4   august 2008   written by Feherke'
echo 'search for multiple files with the same content'
echo

shopt -s extglob

directory=()
sizelimit='0'
algorithm='md5'

missing=''

while (( $# )); do
  case "$1" in
    '-s') shift; sizelimit="$1" ;;
    '--size='*) sizelimit="${1#*=}" ;;
    '-a') shift; algorithm="$1" ;;
    '--algo='*) algorithm="${1#*=}" ;;
    '--help'|'-h'|'-?')
      cat <<EOT
Syntax :
  duplicate.sh [-s size] [-a algorithm] [directory [...]]
  
Parameters :
  -s size | --size=size  - file size in bytes, smallers are not checked ( 0 )
  -a algorithm | --algo=algorithm  - checksum algorithm : MD5 or SHA1 ( MD5 )
  directory  - directory with path to include in the search ( . )
  
All searches are recursive.
EOT
      exit
    ;;
    *) 
      [[ -e "$1" ]] || missing="$missing '$1',"
      directory[${#directory[@]}]="$1"
    ;;
  esac
  shift
done

algorithm="$( tr '[:upper:]' '[:lower:]' <<< "$algorithm" )"
summer="${algorithm}sum"

[[ "$missing" ]] && {
  echo "error : can not find the following directories :$missing"
  exit 1
}

[[ "$sizelimit" != +(0|1|2|3|4|5|6|7|8|9) ]] && {
  echo "error : can not use invalid size limit : $sizelimit"
  exit 1
}

[[ "$algorithm" != @(md5|sha1) ]] && {
  echo "error : can not use unknown algorithm : $algorithm"
  exit 1
}

type "$summer" > /dev/null 2>&1 || {
  echo "error : can not find the tool for checksum : $summer"
  exit 2
}

echo -n 'creating temporary directory... '
work="$( mktemp -d -p '/tmp/' 'dupXXXXXX' )"
echo "Ok ( ${work##*/} )"

echo -n 'creating file list... '
find "${directory[@]}" ! -path "$work/*" -type f -printf '%s*\t%p\n' > "$work/1" 2> "$work/1e"
echo "Ok ( $( echo $( wc -l < "$work/1" ) ), error $( echo $( wc -l < "$work/1e" ) ) )"

echo -n 'discarding small files... '
dist=''
(( sizelimit )) && {
  awk -vs="$sizelimit" '$1+0<s' "$work/1" > "$work/1s"
  dist='s'
  echo "Ok ( $( echo $( wc -l < "$work/1s" ) ) )"
} || {
  echo 'not needed'
}

echo -n 'searching for duplicated file sizes... '
sort -n "$work/1$dist" | cut -d $'\t' -f 1 | uniq -d > "$work/2"
echo "Ok ( $( echo $( wc -l < "$work/2" ) ) )"

echo -n 'creating list of potential duplicated files... '
grep -w -F -f "$work/2" "$work/1" | cut -d $'\t' -f 2- > "$work/3"
echo "Ok ( $( echo $( wc -l < "$work/3" ) ) )"

echo -n 'collecting checksums... '
md5start=$SECONDS
tr '\n' '\0' < "$work/3" | xargs -0 "$summer" > "$work/4" 2> "$work/4e"
echo "Ok ( $( echo $( wc -l < "$work/4" ) ), error $( echo $( wc -l < "$work/4e" ) ) )"

echo -n 'searching for duplicated checksums... '
sort -n "$work/4" | cut -d ' ' -f 1 | uniq -d > "$work/5"
echo "Ok ( $( echo $( wc -l < "$work/5" ) ) )"

echo -n 'preparing the checksum list for fast search... '
dist=''
read line < "$work/4"
[[ "$line" == *\** ]] && {
  echo 'not needed'
} || {
  sed 's/  / */' "$work/4" > "$work/4s"
  dist='s'
  echo 'Ok'
}

echo -n 'creating list of duplicated files... '
sed 's/$/ */' "$work/5" | grep -F -f - "$work/4$dist" | sort > "$work/6"
echo "Ok ( $( echo $( wc -l < "$work/6" ) ) )"

echo -n 'creating result list... '
awk -F' \\*' -vOFS='' 'l!=$1{print""}{l=$1;$1=""}1' "$work/6" > "duplicated.txt"
echo "Ok ( duplicated.txt )"

echo -n 'cleaning up temporary data... '
size="$( du -h "$work" | cut -d $'\t' -f 1 )"
#rm -r -f "$work"
echo "Ok ( $size )"

echo -n 'all done in'
sec=$SECONDS
(( sec/60/60 )) && echo -n " $(( sec/60/60 )) hours"
(( sec/60%60 )) && echo -n " $(( sec/60%60 )) minutes"
(( sec%60 )) && echo -n " $(( sec%60 )) seconds"
(( sec )) || echo -n ' no time'
echo '.'
