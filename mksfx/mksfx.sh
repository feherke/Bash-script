#!/bin/bash

# mksfx.sh   version 1.1   august 2008   written by Feherke
# create compressed archive of a directory and add an autoextract header

selfextract=''
directory='.'
compress='gzip'
autorun='run.sh'

self="${0##*/}"
exclude=''

while (( $# )); do
  case "$1" in
    '-x') shift; selfextract="$1" ;;
    '--sfx='*) shift; selfextract="${1#*=}" ;;
    '-c') shift; compress="$1" ;;
    '--compress='*) shift; compress="${1#*=}" ;;
    '-r') shift; autorun="$1" ;;
    '--run='*) shift; autorun="${1#*=}" ;;
    '-h'|'--help'|'-?')
      cat <<ENDOFSYNTAX
Make SelFeXtracting archive   version 1.1   august 2008   written by Feherke
create compressed tar of a directory and add an autoextract header
Syntax :
  $self [-x sfxname] [-c compression] [-r runname] [directory]
Parameters :
  directory  - name of the directory to compress ( . )
  -x sfxname | --sfx=sfxname  - file name to create ( same as directory )
  -c compression | --compress=compression  - method : gzip, bzip2 ( gzip )
  -r runname | --run=runname  - file to run after uncompressing ( run.sh )
( The values between paranthesis are the default values. )
ENDOFSYNTAX
      exit
    ;;
    *) directory="$1" ;;
  esac
  shift
done

[[ "$directory" ]] || { echo "$self: no directory name specified"; exit 1; }
[[ -d "$directory" ]] || { echo "$self: directory '$directory' does not exist"; exit 1; }

[[ "$selfextract" ]] || {
  selfextract="${directory%/}"
  selfextract="${selfextract##*/}"
}
[[ "$selfextract" == '.' ]] && selfextract="${PWD##*/}"
selfextract="${selfextract%.*}.sh"

[[ "$directory" != '.' ]] || exclude="--exclude $self"
directory="${directory%/}/"

[[ "$compress" == 'gzip' || "$compress" == 'bzip2' ]] || { echo "$self: wrong compressinion method '$compress'"; exit 1; }

[[ "$compress" == 'gzip' ]] && complett='z'
[[ "$compress" == 'bzip2' ]] && complett='j'

echo -n "SFX $directory -> $selfextract : "

echo -n "$compress... "
tar "cf$complett" "/tmp/sfx-$$" $exclude "$directory"
(( $? )) && { echo 'Error'; exit 1; }

echo -n 'sfx... '
cat <<ENDOFTEXT > "$selfextract"
#!/bin/bash

temporary="\$( mktemp -d '/tmp/sfx-XXXXXX' )"
sed '1,/^_BEGIN_OF_ARCHIVED_DATA_$/d' "\$0" | tar 'x$complett' -C "\$temporary"
$( [[ "$autorun" && -x "$directory/$autorun" ]] && echo "[ -x \"\$temporary/$directory$autorun\" ] && { cd \"\$temporary\"; \"$directory$autorun\"; }" )

exit 0

_BEGIN_OF_ARCHIVED_DATA_
ENDOFTEXT
(( $? )) && { echo 'Error'; exit 1; }

echo -n 'add... '
cat "/tmp/sfx-$$" >> "$selfextract"
(( $? )) && { echo 'Error'; exit 1; }
chmod +x "$selfextract"
rm "/tmp/sfx-$$"

echo 'Ok'
