#!/bin/bash
# Lyndex   version 1.0b   october 2005   written by Feherke
# create a word index from the Lynx traversal crawl files

# >>> hammered-in variables >>>
filelist="filelist.txt"
wordlist="wordlist.txt"
leftlist="leftoutlist.txt"
tocfile="contents.txt"
general="general.txt"

filelist="fl"
wordlist="wl"
leftlist="ll"
tocfile="tl"
general="gl"
spellbug="sc"
# <<<

time=$SECONDS
echo "Lyndex   version 1.0b   october 2005   written by Feherke"

for str; do
  case "$str" in
    -?|-h|--help)
      cat <<ENDOFTEXT
create a word index from the Lynx traversal crawl files

Syntax :
  lyndex.sh [inifile]

Parameter :
  inifile  - crawling settings file ( lyndex.ini )
ENDOFTEXT
      exit
    ;;
    *) ini="$str" ;;
  esac
done

echo -n "Reading settings... "
test -z "$ini" && ini="${0%.sh}.ini"
test ! -f "$ini" && { echo "Error : missing settings file '$ini'"; exit; }
source "$ini"
test $? -ne 0 && { echo "Error : invalid settings file '$ini'"; exit; }
echo "Ok ( $ini )"

echo -n "Creating work directory... " 
temp=`mktemp -d "lnkXXXXXX"`
#temp=rigi # TEST TEST TEST
echo "Ok ( $temp )"

echo -n "Setting up restrictions... " 
for str in "${nocrawl[@]}"; do
  echo "$str"
done > "$temp/reject.dat"
echo "Ok ( ${#nocrawl[*]} )"

echo -n "Composing user-agent... "
agent="Lyndex/1.0 Lynx/`lynx -version | sed 's/^.*[[:space:]]\([[:digit:]]\+\.[[:digit:]]\+[[:alnum:]._/]*\)[[:space:]].*/\1/;q'` (`uname -mrs`; console)"
echo "Ok ( $agent )"

echo -n "Crawling $starturl ... "
cd "$temp"
lynx -traversal -realm -crawl -accept_all_cookies -dont_wrap_pre -useragent="$agent" "$starturl" > /dev/null
#cp ../hohoho/* . # TEST TEST TEST
cd "$OLDPWD"
t=`du -h "$temp" | cut -f1`
echo "Ok ( $t )"

echo -n "Removing old data... "
rm -f "$filelist" "$wordlist" "$leftlist" "$tocfile" "$general"
echo "Ok ( 5 files )"

echo -n "Generating checksums... "
find "$temp" -name "lnk*.dat" -printf "%f\t" -exec bash -c "tail +2 '{}' | $checksum" \; > "$temp/temp0.txt"
entry=`wc -l < "$temp/temp0.txt" | tr -d ' '`
echo "Ok ( $entry entries )"

echo -n "Excluding duplicates... "
sort -k2 "$temp/temp0.txt" | uniq -f1 -d | \
while read str sum; do
  grep -w "$sum" "$temp/temp0.txt" | grep -v -w "$str" | \
  while read str sum; do
    mv "$temp/$str" "$temp/$str.dup"
  done
done
t=`ls -1 "$temp/lnk"*".dat.dup" | wc -l | tr -d ' '`
echo "Ok ( $t pieces )"

echo -n "Creating file list... "
nrpage=0
while read str; do
  lnk=`printf "$temp/lnk%08d.dat" "$nrpage"`
  if [ -e "$lnk" ]; then
#    echo -en "$nrpage\t"`du -h "$lnk" | cut -f1`"\t"
#    ( grep -m 1 "^$str"$'\t' "$temp/traverse2.dat" || echo -e "$str\t" ) | sed 's!'"$starturl"'!!' | tr '\n' '\t'
#    tail +4 "$lnk" | sed -n 's/^ \{4,\}//;/^[^ ]/,$H;${g;s/[[:space:]]\+/ /g;s/^ *//;s/\(.\{'"$sample"'\}\).*/\1/;s/ [^ ]*$//;p}'
    echo -en "$nrpage\t"
    ( grep -m 1 "^$str"$'\t' "$temp/traverse2.dat" || echo -e "$str\t" ) | sed 's!'"$starturl"'!!'
  fi
  let nrpage=nrpage+1
done < "$temp/traverse.dat" > "$filelist"
t=`wc -l < "$filelist" | tr -d ' '`
echo "Ok ( $t files )"

echo -n "Extracting words... "
for ((nr=0;nr<nrpage;nr++)); do
  lnk=`printf "$temp/lnk%08d.dat" "$nr"`
  test ! -e "$lnk" && continue
  tail +4 "$lnk" | tr -cs '[:alpha:]' '\n' | tr '[:upper:]' '[:lower:]' | sed 's/\(.\)\1\{13,\}//;/.\{'"$minword"'\}/!d;/\(.\)\1\{'"$maxaart"'\}/d' | sort | uniq -c | sed 's/^/'"$nr"'/'
done > "$temp/temp1.txt"
entry=`wc -l < "$temp/temp1.txt" | tr -d ' '`
echo "Ok ( $entry entries )"

echo -n "Calculating maximum relevance... "
let nrrele=maxrele*nrpage/100
echo "Ok ( $nrrele )"

echo -n "Parsing words... "
now=""
( sort -k 3 -k 2 "$temp/temp1.txt"; echo ) | \
while read number count word; do
  if [ "$now" != "$word" ]; then
    if [ -n "$now" ]; then
      if [ $nrocc -ge $nrrele ]; then
        if [ ${occc[0]} -eq ${occc[$nrocc-1]} ]; then
	  echo -e "$now\t$nrocc" >> "$leftlist"
	  unset occn
	else
          for ((i=0;i<nrocc;i++)); do
	    if [ ${occc[$i]} == ${occc[0]} ]; then
              unset occn[$i]
	    elif [ "$decirel" == "yes" ]; then
	      let occc[$i]=occc[$i]-occc[0]
	    fi
          done
	fi
      fi
      if [ ${#occn[*]} -ne 0 ]; then
        echo -n "$now"
        now1=0
        for ((i=0;i<nrocc;i++)); do
          test -z "${occn[$i]}" && continue
          if [ $now1 -ne ${occc[$i]} ]; then
	    echo -en "\t${occc[$i]}"
            now1=${occc[$i]}
          fi
	  echo -n ",${occn[$i]}"
        done
        echo
      fi
    fi
    now="$word"
    nrocc=0
    occn=()
    occc=()
  fi
  occn[$nrocc]=$number
  occc[$nrocc]=$count
  let nrocc=nrocc+1
done > "$wordlist"
word=`wc -l < "$wordlist" | tr -d ' '`
echo "Ok ( $word words )"

echo -n "Creating table of contents... "
while read -n 1 str; do
  let nr=nr+1
  test "$l" != "$str" && echo -e "$str\t$nr\t${pos:-0}"
  l="$str"
  read str
  let pos+=${#str}+2
done < "$wordlist" > "$tocfile"
letter=`wc -l < "$tocfile" | tr -d ' '`
echo "OK ( $letter letters )"

echo -n "Creating general file... "
(
  echo "base=$starturl"
  echo "min=$minword"
  echo "aart=$maxaart"
) > "$general"
echo "OK ( 2 items )"

echo -n "Checking for spelling errors... "
if [ -n "$shellcheck" ]; then
  cut -f1 "$wordlist" | $shellcheck | grep -E "^(&|\?|#)" | \
  awk -F "[:,[:digit:] ]+ " '{$1=substr($1,3); s=$1 ": "; for (i=2;i<=NF;i++) if ($1==tolower($i)) next; else s=s (i>2?", ":"") $i; print s}' > "$spellbug"
fi
t=`wc -l < "$spellbug" | tr -d ' '`
echo "OK ( $t occurences )"

echo -n "Removing temporary data... "
t=`du -h "$temp" | cut -f1`
#rm "$temp/"*
echo "Ok ( $t )"
echo -n "Removing work directory... "
#rmdir "$temp"
echo "Ok ( $temp )"

let time=SECONDS-time
echo "Done ( $time seconds )"
