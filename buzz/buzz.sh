#!/bin/bash

# Buzz !   version 1.3   february 2013   written by Feherke
# displays a predefined message at a given time


# order of preferred commands
commandlist=( gnome-terminal 'xmessage' 'Xdialog' 'kdialog' 'gdialog' 'zenity' 'yad' 'gxmessage' 'gtkdialog' 'xterm' 'eterm' 'aterm' 'terminal' 'konsole' 'vte' 'rxvt' )

# predefined message
title='Buzz !'
button='Yes, thank You'
message=" Excuse me Sir, this is Your
|~|_    _  _   ___   ___  |~|
| / \  | || | |__ | |__ | | |
|  O ) | || |  / /   / /  |_|
|_\_/  \__/_| |___| |___| (_)

 *   --=[ \$( date +%H:%M:%S ) ]=--   *

( Buzz was set at $( date +%H:%M:%S ). )"


column=0
line=1
while read -r str; do
  (( line++ ))
  (( column=column>${#str}?column:${#str} ))
done <<< "$( eval "echo \"$message\"" )"


echo 'Buzz !   version 1.3   february 2013   written by Feherke'

if [[ "$1" =~ ^-{1,2}(h(elp)?|\?)$ ]]; then
  echo \
'displays a predefined message at a given time

Syntax :
  buzz time

Parameters :
  time  - absolute or relative time, as required by at :
    H day-part
    HH:MM [month-name DD [YY[YY]]]
    HH:MM DD.MM.YY
    now + count time-unit
'
  exit
fi

time="$@"

[[ "$time" ]] || {
  echo 'Error : required parameter missing'
  exit
}


for str in "${commandlist[@]}"; do
  type "$str" > /dev/null 2>&1 && { command="$str"; break; }
done

[[ "$command" ]] && {
  echo "The message will be displayed using $command"
  [[ "$DISPLAY" ]] && display="DISPLAY=$DISPLAY " || echo 'Warning : DISPLAY not set, the command may fail'
} || echo 'The message will be sent to your local mailbox'

case "$command" in
  'xmessage') echo "$display xmessage -center -title '$title' -buttons '${button/,/\,}' -file - <<< \"$message\"" ;;
  'Xdialog') echo "$display Xdialog --fixed-font --left --title '$title' --ok-label '$button' --no-cancel --textbox - 0 0 <<< \"$message\"" ;;
  'kdialog') echo "$display kdialog --title '$title' --msgbox \"$message\" 2> /dev/null" ;;
  'gdialog') echo "$display gdialog --title '$title' --msgbox \"$message\"" ;;
  'zenity') echo "$display zenity --title='$title' --ok-label='$button' --info --text \"$message\"" ;;
  'yad') echo "$display yad --title='$title' --button='$button' --text \"$message\"" ;;
  'gxmessage') echo "$display gxmessage -fn fixed -bg gray -fg black -center -title '$title' -buttons '${button/,/\,}' \"$message\"" ;;
  'gtkdialog')
    IFS='*' message=( $message )
    message1="${message[1]}"
    message=( "${message[@]/#/<text use-markup=\"true\"><label>\"<tt>}" )
    message=( "${message[@]/%/</tt>\"</label></text>}" )
    message[1]="<text><input>eval echo \"$message1\"</input></text>"
    echo "$display dialog='<window title=\"$title\"><vbox>${message[@]//\\/\`}<button label=\"$button\"></button></vbox></window>' gtkdialog -c -p dialog"
  ;;
  'xterm') echo "$display xterm -bg gray -fg black +sb -geometry '${column}x$line' -T '$title' -e \"echo '$message';read -p $'\e[42m $button \e[0m'\"" ;;
  'eterm') echo "$display eterm -b gray -f black -P '' --no-cursor -s 0 --buttonbar 0 -g '${column}x$line' -T '$title' -e bash -c \"echo '$message';read -p $'\e[42m $button \e[0m'\"" ;;
  'aterm') echo "$display aterm -bg gray -fg black -cr gray -sb -geometry '${column}x$line' -title '$title' -e bash -c \"echo '$message';read -p $'\e[42m $button \e[0m'\"" ;;
  'terminal') echo "$display terminal --hide-toolbars --hide-menubar --geometry '${column}x$line' -T '$title' -x bash -c \"echo '$message';read -p $'\e[42m $button \e[0m'\"" ;;
  'konsole') echo "$display konsole --vt_sz '${column}x$line' --noscrollbar --nomenubar --notoolbar --notabbar -T '$title !' -e bash -c \"echo '$message';read -p $'\e[42m $button \e[0m'\" 2> /dev/null" ;;
  'rxvt') echo "$display rxvt -bg gray -fg black -cr gray -geometry '${column}x$line' -title '$title' -e bash -c \"echo '$message';read -p $'\e[42m $button \e[0m'\"" ;;
  'gnome-terminal') echo "$display gnome-terminal --hide-menubar --geometry '${column}x$line' -t '$title' -e \"bash -c \\\"echo '$message';read -p $'\e[42m $button \e[0m'\\\"\"" ;;
  *) echo "echo \"$message\"" ;;
esac | at $time
