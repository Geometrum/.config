#!/bin/bash

# Detect if it's already launched. Restart i3 and itself if detected
if [ $(pgrep -cx $(basename $0)) -gt 1 ] ; then
	i3-msg restart 
	killall -g /bin/bash
fi

trap 'trap - TERM; kill 0' INT TERM QUIT EXIT

# Variables
fifo="/tmp/lemonbar"

. ~/ressources/colors
. ~/ressources/devices
. ~/ressources/separators
. ~/ressources/icons
. ~/ressources/workspaces


# Creation of the fifo file
[ -e "${fifo}" ] && rm -Rf "${fifo}"
mkfifo "${fifo}"


acpi_entry() {
	while read -r line ; do
		case $line in
			ac_adapter)
				echo 'b' > "${fifo}"
			;;
			battery)
				echo 'b' > "${fifo}"
			;;

		esac &
	done
}


# Spy window changement
xprop -spy -root _NET_ACTIVE_WINDOW | sed -un 's/.*/w/p' > "${fifo}" &
#w_ID=$(xprop -root _NET_ACTIVE_WINDOW | sed -un 's/.* //p')
acpi_listen | sed -u 's/ .*//' | acpi_entry &

# Get program title
window() {
	#w_title=$(xprop -id $w_ID WM_NAME | sed 's/.*= "//' | sed 's/"//')
	w_title=$(xdotool getactivewindow getwindowname || echo "ArchCuber")
}

# Get clock
clock() {
	c_date=$(date +'%a %d %b' | sed -e "s/\b\(.\)/\u\1/g")
	c_time=$(date +'%H:%M')
	c="F${orange}}${left}%{B${orange} F${black}} ${date_icon} ${c_date} %{F${black}}${left_light}%{B${orange} F${yellow}}${left}%{B${yellow} F${black}} ${time_icon} ${c_time}"
}

# Get battery
battery() {
	b_level=$(cat /sys/class/power_supply/BAT0/capacity)
	b_status=$(cat /sys/class/power_supply/BAT0/status)
	
	if [ $b_level -le 20 ]; then
		b_bcolor="${red}"
		b_fcolor="${white}"
	elif [ $b_level -le 40 ]; then
		b_bcolor="${maroon}"
		b_fcolor="${white}"
	elif [ $b_level -le 60 ]; then
		b_bcolor="${yellow}"
		b_fcolor="${black}"
	elif [ $b_level -le 80 ]; then
		b_bcolor="${green}"
		b_fcolor="${black}"
	elif [ $b_level -lt 100 ]; then
		b_bcolor="${blue}"
		b_fcolor="${black}"
	fi

	if [ $b_level -le 25 ]; then
		b_icon="${battery_0_icon}"
	elif [ $b_level -le 50 ]; then
		b_icon="${battery_25_icon}"
	elif [ $b_level -le 75 ]; then
		b_icon="${battery_50_icon}"
	elif [ $b_level -lt 100 ]; then
		b_icon="${battery_75_icon}"
	fi

	if [ $b_status == "Full" ]; then
		b_icon="${battery_full_icon}"
		b_bcolor="${violet}"
		b_fcolor="${white}"
	elif [ $b_status == "Charging" ]; then
		b_icon="${charging_icon}"
	elif [ $b_status == "Unknown" ]; then
		b_bcolor="${red}"
		b_fcolor="${white}"
	fi

	b="F${b_bcolor}}${left}%{F${b_fcolor} B${b_bcolor}} ${b_icon} ${b_level}% %{F${b_fcolor}}${left_light}%{B${b_bcolor}"
}

# Get network
network() {
	ethernet_icon_status=$(nmcli d | grep "ethernet" | awk '{ print $3 }')
	wifi_icon_status=$(nmcli d | grep "wifi" | awk '{ print $3 }')
	wifi_icon_ESSID=$(nmcli d | grep "wifi" | awk '{ print $NF }')
	wifi_icon_quality=0
	ethernet_icon_disconnected="0"
	n_bcolor="${red}"
	n_fcolor="${black}"
	n_icon=""
	n_ping=""

	if [ $wifi_icon_status == "indisponible" ]; then
		n_bcolor="${white}"
		n_icon="${airplane_icon}"
		if [ $ethernet_icon_status == "déconnecté" ]; then
			nmcli dev connect "${ethernet}" &
		fi
	
	elif [ $wifi_icon_status == "déconnecté" ]; then
		n_bcolor="${black}"
		n_fcolor="${white}"
		n_icon="${disconnected_icon}"
		if [ $ethernet_icon_status == "déconnecté" ]; then
			nmcli dev connect "${ethernet}" &
		fi

	elif [ $wifi_icon_status == "connexion" ]; then
		n_bcolor="${orange}"
		n_icon="${wifi_icon}"
		if [ $ethernet_icon_status == "connecté" ]; then
			nmcli dev disconnect "${ethernet}" &
		fi
		ethernet_icon_disconnected="1"	

	elif [ $wifi_icon_status == "connecté" ]; then
		n_ping=$(ping www.google.com -c 1 | grep "time=" | sed "s/.*time=/ /")
		n_icon="${wifi_icon}"
		wifi_icon_quality=$((100*$(iwconfig "${wifi}" | grep "Link Quality" | sed "s/.*Link Quality=//" | sed "s/ .*//")))
		if [ $wifi_icon_quality -ge 65 ]; then
			n_bcolor="${blue}"
		elif [ $wifi_icon_quality -ge 35 ]; then
			n_bcolor="${green}"
		else
			n_bcolor="${yellow}"
		fi
	fi

	if [ $ethernet_icon_status == "indisponible" ]; then
		if [ $wifi_icon_status == "déconnecté" ]; then
			nmcli dev connect "${wifi}" &
		fi

		if [ $ethernet_icon_disconnected == "1" ]; then
			ethernet_icon_disconnected="2"
		fi

	elif [ $ethernet_icon_status == "déconnecté" ]; then
		n_icon="${n_icon}${disconnected_icon}"
		if [ $wifi_icon_status == "déconnecté" ]; then
			nmcli dev connect "${wifi}" &
		fi

		if [ $ethernet_icon_disconnected == "2" ]; then
			nmcli dev connect "${ethernet}" &
			ethernet_icon_disconnected="0"
		fi
	elif [ $ethernet_icon_status == "connexion" ]; then
		n_bcolor="${orange}"
		n_icon="${n_icon}${ethernet_icon}"
	
	elif [ $ethernet_icon_status == "connecté" ]; then
		n_ping=$(ping www.google.com -c 1 | grep "time=" | sed "s/.*time=/ /")
		n_bcolor="${blue}"
		n_icon="${n_icon}${ethernet_icon}"
		if [ $wifi_icon_status == "connecté" ]; then
			nmcli dev disconnect "${wifi}" &
		fi

	else
		n_bcolor="${red}"
	fi

	n="F${n_bcolor}}${left}%{F${n_fcolor} B${n_bcolor}} ${n_icon}${n_ping} %{F${n_fcolor}}${left_light}%{B${n_bcolor}"
}


# Get Bluetooth info
bluetooth() {
	bl_name=$(hcitool dev | grep "${bluetooth}")

	if [ -z $bl_name ]; then
		bl_color="${red}"
		blight_icon="${bluetooth_off_icon}"
	else
		bl_color="${blue}"
		blight_icon="${bluetooth_on_icon}"
	fi

	bl="F${bl_color}}${left}%{F${black} B${bl_color}} ${blight_icon} %{F${black}}${left_light}%{B${bl_color}"
}


# Get brightness
light() {
	l_maxlevel=$(cat /sys/class/backlight/intel_backlight/max_brightness)
	l_curlevel=$(cat /sys/class/backlight/intel_backlight/brightness)
	l_level=$((100*$l_curlevel/$l_maxlevel))

	if [ $l_level -le 10 ]; then
		l_bcolor="${maroon}"
		l_fcolor="${white}"
	elif [ $l_level -ge 90 ]; then
		l_bcolor="${violet}"
		l_fcolor="${white}"
	else
		l_bcolor="${white}"
		l_fcolor="${black}"
	fi

	l="F${l_bcolor}}%{A:sudo ~/backlight.sh + && echo 'l' > ${fifo}:}%{A3:sudo ~/backlight.sh - && echo 'l' > ${fifo}:}${left}%{F${l_fcolor} B${l_bcolor}} ${light_icon} ${l_level}% %{F${l_fcolor}}${left_light}%{A}%{A}%{B${l_bcolor}"
}


# Get Master Volume
volume() {
	v_level=$(pulsemixer --get-volume | awk '{ print $1 }')
	v_mute=$(pulsemixer --get-mute)

	if [ $v_mute == "1" ]; then
		v_bcolor="${red}"
		v_fcolor="${white}"
		v_icon="${volume_muted_icon}"
	elif [ $v_level -eq 150 ]; then
		v_bcolor="${violet}"
		v_fcolor="${white}"
		v_icon="${volume_high_icon}"
	elif [ $v_level -ge 100 ]; then
		v_bcolor="${white}"
		v_fcolor="${black}"
		v_icon="${volume_high_icon}"
	elif [ $v_level -ge 50 ]; then
		v_bcolor="${white}"
		v_fcolor="${black}"
		v_icon="${volume_normal_icon}"
	elif [ $v_level -gt 0 ]; then
		v_bcolor="${white}"
		v_fcolor="${black}"
		v_icon="${volume_low_icon}"
	else
		v_bcolor="${maroon}"
		v_fcolor="${white}"
		v_icon="${volume_muted_icon}"
	fi

	v="F${v_bcolor}}%{A:pulsemixer --change-volume +5 && echo 'v' > ${fifo}:}%{A3:pulsemixer --change-volume -5 && echo 'v' > ${fifo}:}${left}%{F${v_fcolor} B${v_bcolor}} ${v_icon} ${v_level}% %{F${v_fcolor}}${left_light}%{A}%{A}%{B${v_bcolor}"
}

# Get workspace information
space() {
	s_workspaces=$(i3-msg -t get_workspaces | tr "," "\n" | grep '"name":"' | sed 's/"name":". \(.\)"/\1/g')
	s_focused=$(i3-msg -t get_workspaces | tr "," "\n" | grep '"focused":' | sed 's/"focused":\(.*\)/\1/g' | tail)
	s_urgent=$(i3-msg -t get_workspaces | tr "," "\n" | grep '"urgent":' | sed 's/"urgent":\(.*\)}.*/\1/g' | tail)
	s_status=$(xrandr | grep ${hdmi} | sed "s/${hdmi} \(\w*\).*/\1/")
	index=0
	s_bcolor="${white}"

	for workspace in ${workspaces[@]}; do
		s_bcolor_last="${s_bcolor}"
		s_fcolor="${white}"
		s_bcolor="${blue}"

		if [[ $s_workspaces == *$workspace* ]]; then
			if [[ $s_urgent == "true"* ]]; then
				s_fcolor="${black}"
				s_bcolor="${red}"
				s_urgent=$(echo ${s_urgent} | sed 's/true //')
			else
				s_fcolor="${black}"
				s_bcolor="${yellow}"
				s_urgent=$(echo ${s_urgent} | sed 's/false //')
			fi

			if [[ $s_focused == "true"* ]]; then
				s_fcolor="${white}"
				s_bcolor="${violet}"
				s_focused=$(echo ${s_focused} | sed 's/true //')
			else
				s_focused=$(echo ${s_focused} | sed 's/false //')
			fi
		fi

		if [ $index -eq 0 ]; then
			s="%{B${s_bcolor} F${s_fcolor}}%{A:i3-msg workspace '${index} ${workspace}' && echo 's' > ${fifo}:}%{F${s_bcolor_last}}${right}${right_light} %{F${s_fcolor}}${workspace} %{A}"
		elif [ $index -eq 10 ]; then
			if [ $s_status == "disconnected" ]; then
				s_fcolor="${red}"
				if [ $s_bcolor != $violet ]; then
					s_bcolor="${black}"
				fi
			fi	
			s="${s}%{B${s_bcolor} F${s_fcolor}}%{A:i3-msg workspace '+ ${workspace}' && echo 's' > ${fifo}:}%{F${s_bcolor_last}}${right} %{F${s_fcolor}}${workspace} %{A}"
		else
			s="${s}%{B${s_bcolor} F${s_fcolor}}%{A:i3-msg workspace '${index} ${workspace}' && echo 's' > ${fifo}:}%{F${s_bcolor_last}}${right} %{F${s_fcolor}}${workspace} %{A}"
		fi
		index=$((${index}+1))
	done

	s="${s}%{B${black} F${s_bcolor}}${right}%{B- F-}${right_light}"
}


while :; do
	echo "w_c_s" > "${fifo}"

	sleep 1
done &

while :; do
	echo "n_bl" > "${fifo}"

	sleep 2
done &

while :; do
	echo "l" > "${fifo}"
	echo "v" > "${fifo}"

	sleep 10
done &


window
battery
clock
network
bluetooth
light
volume
space

parser() {

	while read -r line ; do
		case $line in
			w_c_s)
				window
				clock
				space
			;;

			n_bl)
				network
				bluetooth
			;;

			w) 
				window
			;;

			b)  sleep 0.2
				battery
			;;

			c) 
				clock
			;;

			n) 
				network
			;;

			bl) 
				bluetooth
			;;

			l) 
				light
			;;

			v)
				volume
			;;

			s)
				space
			;;

			*)
				w_title="Erreur"
			;;
		esac
		echo -e "%{c}%{F${white} B${black}} ${w_title} %{l}%{B${white} F${black}}%{A:oblogout:}  %{B- F-}%{A}${s} %{r}${left_light}%{B- ${v} ${l} ${bl} ${n} ${b} ${c}  %{B- F-}"
	done
}


cat "${fifo}" | parser | lemonbar -p -F "${white}" -B "${black}" -f 'Source Code Pro-9' -f 'Source Code Pro-10' -f 'FontAwesome-11' | bash

wait
