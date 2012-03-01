#!/bin/bash

# Cookie Clean   version 1.3   august 2008   written by Feherke
# cleans up the Mozilla cookie file removing unwanted items

# This script was designed to be run from cron, so it outputs its messages to
# a log file. Excepting of course unexpected and unhandled errors...


scriptname="${0##*/}"; scriptname="${scriptname%.sh}"
scriptdir="${0%/*}"

[[ -f "$scriptdir/$scriptname.ini" ]] || exit 1

while IFS='=' read key value; do
  [[ "$key" ]] || continue
  [[ "${key:0:1}" == '#' ]] && continue
  [[ "$key" == 'profile' ]] && {
    eval "$key[\${#$key[@]}]=\"$value\""
  } || {
    eval "$key=\"$value\""
  }
done < "$scriptdir/cookieclean.ini"

echo "starting cleanup on $( date +'%F %T' )" >> "${logfile:-$scriptdir/$scriptname.log}"
SECONDS=0

[[ "$logfile" ]] || {
  : "${logfile:=$scriptdir/$scriptname.log}"
  echo "WARNING : key 'logfile' undefined, defaulting to '$logfile'" >> "$logfile"
}

[[ "$okfile" ]] || {
  : "${okfile:=$scriptdir/$scriptname-ok.txt}"
  echo "WARNING : key 'okfile' undefined, defaulting to '$okfile'" >> "$logfile"
}

[[ -f "$okfile" ]] || {
  echo "ERROR : file '$okfile' to use as 'okfile' is missing" >> "$logfile"
  exit 2
}

[[ "$badfile" ]] || {
  : "${badfile:=$scriptdir/$scriptname-bad.txt}"
  echo "WARNING : key 'badfile' undefined, defaulting to '$badfile'" >> "$logfile"
}

[[ "$cachefile" ]] || {
  : "${cachefile:=$scriptdir/$scriptname-cache.txt}"
  echo "WARNING : key 'cachefile' undefined, defaulting to '$cachefile'" >> "$logfile"
}

[[ "$cachefile2" ]] || {
  : "${cachefile2:=$scriptdir/$scriptname-cache2.txt}"
  echo "WARNING : key 'cachefile2' undefined, defaulting to '$cachefile2'" >> "$logfile"
}

ok=0
[[ -f "$cachefile" ]] && {
  [[ "$okfile" -nt "$cachefile" ]] && {
    echo 'cache exists but is outdated, recreating it' >> "$logfile"
  } || {
    echo 'cache exists, reusing it' >> "$logfile"
    ok=1
  }
} || {
  echo 'cache not exists, creating it' >> "$logfile"
}

(( ok )) || sed '
/^#/d               # discard comments
/^$/d               # discard empty lines
/^-$/s/-//          # treat single dash as no host
s/\./\\./g          # escape periods
s/.*/^&\t/          # restrict the expression to first column
                    # preserve comments
$a^#
                    # preserve empty lines
$a^$
' "$okfile" > "$cachefile"

ok=0
[[ -f "$cachefile3" ]] && {
  [[ "$okfile" -nt "$cachefile3" ]] && {
    echo 'cache 3 exists but is outdated, recreating it' >> "$logfile"
  } || {
    echo 'cache 3 exists, reusing it' >> "$logfile"
    ok=1
  }
} || {
  echo 'cache 3 not exists, creating it' >> "$logfile"
}

(( ok )) || sed -n '
/^#/d               # discard comments
/^$/d               # discard empty lines
/^-$/s/-//          # treat single dash as no host
s/.*/'"'"'&'"'"'/   # restrict the expression to first column
H                   # stack them up in the hold space
$ {                 # at the end
  g                 # get back fron the hold space
  s/\n//            # discard the first new line
  s/\n/,/g          # replace new lines with comma
  p                 # print it
}
' "$okfile" > "$cachefile3"

[[ "$mozilla" ]] && {
  echo "WARNING : key 'mozilla' is deprecated, use 'profile' instead" >> "$logfile"
}

(( ${#profile[@]} )) || {
  [[ "$mozilla" ]] || {
    echo "ERROR : no key 'profile' is defined, it is mandatory" >> "$logfile"
    exit 3
  }
  echo "WARNING : no key 'profile' is defined, using key 'mozilla'" >> "$logfile"
  profile=( "$mozilla" )
}

for dir in "${profile[@]}"; do
  echo "processing $dir" >> "$logfile"
  dir="${dir%/}"
  if [[ -f "$dir/cookies.txt" ]]; then
    echo 'found old style cookies.txt' >> "$logfile"
    [[ "$tempfile" ]] || {
      echo 'creating temporary file' >> "$logfile"
      tempfile="$( mktemp -t "$scriptname-temp-XXXXXX" )"
    }
    grep -v -f "$cachefile" "$dir/cookies.txt" >> "$badfile" && {
      grep -f "$cachefile" "$dir/cookies.txt" > "$tempfile"
      cat "$tempfile" > "$dir/cookies.txt"
    }
  elif [[ -f "$dir/cookies.sqlite" ]]; then
    echo 'found new style cookies.sqlite' >> "$logfile"
    [[ "$condition" ]] || {
      echo 'loading condition expression' >> "$logfile"
      condition="$( < "$cachefile3" )"
    }
    sqlite3 -separator $'\t' "$dir/cookies.sqlite" "select host,case when isHttpOnly then 'TRUE' else 'FALSE' end,path,case when isSecure then 'TRUE' else 'FALSE' end,expiry,name,value from moz_cookies where host not in ($condition)" >> "$badfile"
    sqlite3 "$dir/cookies.sqlite" "delete from moz_cookies where host not in ($condition)"
  else
    echo "ERROR : cookie file '$dir/cookies.txt' not found" >> "$logfile"
    continue
  fi
done

[[ "$tempfile" ]] && {
  echo 'removing temporary file' >> "$logfile"
  rm "$tempfile"
}

echo "finishing clean up in $SECONDS seconds" >> "$logfile"
