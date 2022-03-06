#!/usr/bin/env zsh

script=`basename "$0"`
pathname=`dirname "$0"`
help="$script [-h/--help] -- script to connect to wlan with iwd
  Usage:
    depending on how the script is named,
    it will be executed either with dmenu, with rofi
    or wofi.
  Examples:
    dmenu_iwd.sh
    rofi_iwd.sh
    fuzzel_iwd.sh
    wofi_iwd.sh"

if [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
    printf "%s\n" "$help"
    exit 0
fi

function wofi() {
    command wofi -d -I "$@"
}
function rofi() {
    command rofi -m -1 -dmenu -i "$@"
}
function dmenu() {
    command dmenu "$@"
}
function fuzzel() {
    command fuzzel -f Iosevka:size=8 -w 80 -d "$@"
}

function ssid-scan(){
    eval "$pathname/iwd-scan.py $@"
}

case $script in
    dmenu_*)
        label_interface="interface »"
        menu_interface="dmenu -l 3 -c -bw 2 -r -i -p $label_interface"
        label_ssid="ssid »"
        menu_ssid="dmenu -l 10 -c -bw 2 -r -i -p $label_ssid"
        label_psk="passphrase »"
        menu_psk="dmenu -l 1 -c -bw 2 -i -p $label_psk"
        ;;
    rofi_*)
        label_interface=""
        menu_interface="rofi -l 3 -p $label_interface"
        label_ssid=""
        menu_ssid="rofi -p $label_ssid"
        label_psk=""
        menu_psk="rofi -I -p $label_psk"
        ;;
    wofi_*)
        label_interface=""
        menu_interface="wofi -l 3 -p $label_interface"
        label_ssid=""
        menu_ssid="wofi -p $label_ssid"
        label_psk=""
        menu_psk="wofi -I -p $label_psk"
        ;;
    fuzzel_*)
        label_interface=""
        menu_interface="fuzzel -P $label_interface"
        label_ssid=""
        menu_ssid="fuzzel -P $label_ssid"
        label_psk=""
        menu_psk="fuzzel -I -P $label_psk"
        ;;
    *)
        printf "%s\n" "$help"
        exit 1
        ;;
esac

remove_escape_sequences() {
    tail -n +5 \
        | sed -r "s/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]//g;/^\s*$/d"
}

get_interface() {
    interface=$(iwctl device list \
        | remove_escape_sequences \
        | awk '{printf("%-12s %-9s %s\n", $1, $2, $3)}' \
        | eval $menu_interface \
        | awk '{print $1}'
    )
    [ -n "$interface" ] \
        || exit 1
}

scan_ssid() {
    scan_result=$(ssid-scan | gawk 'NR%3{printf("%-32ls",$0) ;next;}1')
}

get_ssid() {

    select=$(printf "🔁[RESCAN]\n%s" "$scan_result" \
        | eval $menu_ssid \
    )


    if [[ "$select" =~ '^>' ]]
    then
        notify-send.sh "iNet wireless daemon" "Already connected to this network."
        exit 0
    elif [[ "$select" =~ 'open *$' ]]
    then
        open=1
    elif [[ "$select" = "🔁[RESCAN]" ]]
    then
        scan_ssid
        get_ssid
        return
    elif ! [[ -v select ]] || [[ "$select" = "" ]]
    then
        exit 1
    fi

    # Get just list of SSIDsin raw
    ssids=$(ssid-scan ssid)

    # iterate through raw SSID list to determine which one to connect to
    while IFS= read -r ssid_list
    do
        if [[ $select =~ $ssid_list ]] then
            ssid=$ssid_list
            return
        fi
    done <<< "$ssids"
}

get_psk() {
    psk=$(printf 'press esc or enter if you had already insert a passphrase before!\n' \
        | eval $menu_psk \
    )
}

connect_iwd() {
    if [[ "$open" = 1 ]]
    then
        iwctl station "$interface" connect ''$ssid''
    else
        get_psk
        iwctl station "$interface" connect "$ssid" -P "$psk"
    fi
    notify-send "iNet wireless daemon" "connected to \"$ssid\""
}

get_interface \
    && scan_ssid \
    && get_ssid \
    && connect_iwd
