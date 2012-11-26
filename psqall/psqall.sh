#!/bin/bash

# PSQalL   version 1.1   november 2012   written by Feherke
# execute SQL commands on more databases

echo 'PSQalL   version 1.1   november 2012   written by Feherke'
echo 'execute SQL commands on more databases'

shopt -s extglob

psql=( 'psql' )
param=()
include=()
exclude=()
linepre=''
inifile="${0%.sh}.ini"

function makecondition()
{
  local field="$1" operation="$2" list=( "${@:3}" )
  local value boolean comparation result=()

  [[ "$operation" == '!' ]] && boolean='and' || boolean='or'

  for value in "${list[@]}"; do
    [[ "$value" == *[.?\*+()\[\]{}]* ]] && comparation="$operation~*" || comparation="$operation="
    value="${value//\\/\\\\}"

    [[ "$result" ]] && result+=( "$boolean" )
    result+=( "$field$comparation'${value//\'/\'}'" )
  done

  echo "${result[@]}"
}

while (( $# )); do
  case "$1" in
    '-d') shift; include+=( "$1" ) ;;
    '--dbname='?*) include+=( "${1#*=}" ) ;;
    '-D') shift; exclude+=( "$1" ) ;;
    '--exclude='?*) exclude+=( "${1#*=}" ) ;;
    '-h'|'-p'|'-U') psql+=( "$1" "$2" ); shift ;;
    '--host='?*|'--port='*|'--username='*) psql+=( "$1" ) ;;
    '-i') shift; inifile="$1" ;;
    '--inifile='*) inifile="${1#*=}" ;;
    '-L'|'--line-prefix') linepre='1' ;;
    '-?'|'--help')
      cat <<'EOT'

Syntax :
  psqall.sh [-d|-D database [...]] [-L] [-i inifile] psql-param [...]

Parameters :
  -d database, --dbname=database  - execute the commands on this database
  -D database, --exclude=database  - skip this database
  -L, --line-prefix  - display the database name as prefix in each result line
  -i file, --inifile=file  - configuration file

Both -d and -D can be repeated, -d takes precedence over -D.

The default configuration file called psqall.ini is always processed, unless
empty string is specified as inifile name.
EOT
      exit
    ;;
    ?*) param+=( "$1" ) ;;
  esac
  shift
done

[[ -t 0 ]] || input="$( cat )"

[[ "$inifile" && -f "$inifile" ]] && \
while IFS='=: ' read -r key value; do
  [[ ! "$key" || ! "$value" || "${key:0:1}" == [#\;[] ]] && continue

  case "$key" in
    'include') include+=( "$value" ) ;;
    'exclude') exclude+=( "$value" ) ;;
    'lineprefix') [[ "$linepre" ]] || linepre="$value" ;;
  esac
done < "$inifile"

[[ "${include[*]}" ]] && cond="$( makecondition 'datname' '' "${include[@]}" )" || { [[ "${exclude[*]}" ]] && cond="$( makecondition 'datname' '!' "${exclude[@]}" )"; }

mapfile -t database <<< "$( "${psql[@]}" -d 'template1' -t -A -c "select datname from pg_database where datallowconn ${cond:+and ( $cond )}" )" # "

[[ "${linepre:=0}" != '0' ]] && {
  linepre=0
  for name in "${database[@]}"; do (( linepre<${#name} )) && linepre="${#name}"; done
}

for name in "${database[@]}"; do
  if [[ "$linepre" != '0' ]]; then
    "${psql[@]}" -d "$name" "${param[@]}" <<< "$input" | while IFS='' read -r str; do printf '%-*s === %s\n' "$linepre" "$name" "$str"; done
  else
    echo "=== $name ==="
    "${psql[@]}" -d "$name" "${param[@]}" <<< "$input"
  fi
done
