#!/bin/bash

# TabOrder   version 2.0   august 2010   written by Feherke
# reorders the controls in the XFM file based on the declarations in the Pas file

echo 'TabOrder   version 2.0   august 2010   written by Feherke'
echo 'reorders the controls in the XFM file based on the declarations in the Pas file'

function die()
{
  echo "error : $@"
  exit 1
}

file=''
for par; do
  case "$par" in
    '-v'|'--version') exit ;;
    '-h'|'--help'|'-?')
      echo "
Syntax :
  ${0##*/} file
Parameter :
  file - name of the file to reorder, with or without the .xfm or .pas extension"
      exit
    ;;
  esac
done

echo -n 'identifying the form... '
file="$1"
[[ "$file" ]] || die 'form not specified'
file="${file%.pas}"
file="${file%.xfm}"
form="${file##*/}"
echo "ok, $form"

echo -n 'checking the files... '
for ext in 'pas' 'xfm'; do
  [[ -f "$file.$ext" ]] || die "file $file.$ext not found"
done
echo 'ok'

echo -n 'checking the structure... '
nr="$( grep -cwi 'class' "$file.pas" )"
(( nr==0 )) && die "file $file.pas contains no class declaration"
(( nr>1 )) && die "file $file.pas contains more than one class declarations"
echo 'ok'

echo -n 'identifying the class... '
IFS='= ' read class blah <<< "$( grep -i '\w\+\s*=\s*class\b' "$file.pas" )"
[[ "$class" ]] || die 'class name not found'
echo "ok, $class"

echo -n 'checking consistency... '
IFS=': ' read var blah <<< "$( grep ":\s*$class\b;" "$file.pas" )"
read str < "$file.xfm"
[[ "~$str~" == "~inherited $var: $class~" ]] || die 'form file does not start as expected'
echo 'ok'

echo -n 'creating temporary directory... '
temp="${TEMP:-${TMP:-${TMPDIR:-/tmp}}}"
[[ -d "$temp" ]] || die "$temp is not a directory"
temp="$( mktemp -d "$temp/taborder-XXXXXX" )"
[[ -d "$temp" ]] || die 'can not create temporary directory'
echo "ok, $temp"

echo -n 'creating control list... '

declare -A list
inside=''
nr=0
while IFS=': ' read -r prop type; do
  [[ "$prop$type" ]] || continue
  [[ "$inside" ]] || { [[ "$prop" == "$class" && "$type" =~ ^=\ *class ]] && inside='1'; continue; }
  [[ "$prop" =~ ^(procedure|function ) ]] && break
  [[ "$prop" =~ ^(private|public|end)$ ]] && break
  list["$prop"]=$(( nr++ ))
done < "$file.pas"

echo "ok, $nr"

echo -n 'splitting up... '

sub=''
path=''
part='pre'
while IFS='' read -r str; do
  piece=''
  if [[ ! "$sub" ]]; then
    if [[ "$str" =~ \<$ ]]; then
      sub='1'
    elif [[ "$str" =~ object\ ([[:alnum:]_]+): ]]; then
      path="$path/${BASH_REMATCH[1]}"
      mkdir "$temp$path"
      part='pre'
    else
      :
    fi

    [[ "$str" =~ ^\ *TabOrder ]] && str="${str%=*}= <<<TABORDER>>>"
    echo "$str" >> "$temp$path/data.$part"

    if [[ "$str" =~ end$ ]]; then
      path="${path%/*}"
      part='post'
    fi
  elif [[ "$sub" ]]; then
    if [[ "$str" =~ [^\<]\>$ ]]; then
      sub=''
    fi

    echo "$str" >> "$temp$path/data.$part"
  fi


done < "$file.xfm"

echo 'ok'

echo -n 'rebuilding & renumbering... '

function step()
{
  local dir="$1" one order=0 sublist=()

  for one in "$dir"/*; do
    [[ -d "$one" ]] || continue
    step "$one"
    one="${one##*/}"
    sublist[list["$one"]]="$one"
  done

  for one in "${!sublist[@]}"; do
    prop="${sublist[one]}"
    for part in 'pre' 'all' 'post'; do
      [[ -f "$dir/$prop/data.$part" ]] && sed "s/<<<TABORDER>>>/$order/" "$dir/$prop/data.$part" >> "$dir/data.all"
    done
    (( order++ ))
  done
}

step "$temp"

echo 'ok'

echo -n 'renaming the original... '
new=0
while [[ -f "$file.xfm.bak$new" ]]; do (( new++ )); done
mv "$file.xfm" "$file.xfm.bak$new"
echo "ok, $new"

echo -n 'recreating the file... '
for part in 'pre' 'all' 'post'; do
  cat "$temp/data.$part" >> "$file.xfm"
done
echo "ok, ${file##*/}.xfm"

echo -n 'deleting temporary files... '
rm -rf "$temp"
echo 'ok'
