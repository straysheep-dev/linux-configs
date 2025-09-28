#!/bin/bash

# GPL-3.0-or-later

# shellcheck disable=SC2034
# shellcheck disable=SC2116
# shellcheck disable=SC2086

# References:
# - [GNU Bash Manual: Shell Variables](https://www.gnu.org/software/bash/manual/bash.html#Shell-Variables-1)
# - [GNU Bash Manual: Controlling the Prompt String](https://www.gnu.org/software/bash/manual/bash.html#Controlling-the-Prompt-1)
# - [Kali Linux Blog: Shell Prompt Change](https://www.kali.org/blog/kali-linux-2022-1-release/#shell-prompt-changes)
# - [TrustedSec: Shell Improvements for Pentesters](https://www.trustedsec.com/blog/workflow-improvements-for-pentesters/)
# - [ohmyzsh: Themes](https://github.com/ohmyzsh/ohmyzsh/wiki/Themes)
# - [github.com/carlospolop: Shell Prompt Gist](https://gist.github.com/carlospolop/43f7cd50f3deea972439af3222b68808)
# - [Stack Overflow: Shell Prompt with Datetime](https://stackoverflow.com/questions/61335641/bash-or-z-shell-terminal-prompt-with-time-and-date)
# - [Super User: Display IP in Shell Prompt](https://superuser.com/questions/668174/how-can-you-display-host-ip-address-in-bash-prompt)
# - [Stack Exchange: Print Last Element of Each Row](https://unix.stackexchange.com/questions/145672/print-last-element-of-each-row)
# - [Arch Linux Wiki: GNOME Configuration](https://wiki.archlinux.org/title/GNOME#Configuration)
# - [Arch Linux Wiki: Prompt Customization](https://wiki.archlinux.org/title/Bash/Prompt_customization#Embedding_commands)
# - [Ask Ubuntu: Backup GNOME Terminal Settings](https://askubuntu.com/questions/967517/how-to-backup-gnome-terminal-emulator-settings)
# - [Stack Exchange: How the Escape `\` Character Works in Bash](https://unix.stackexchange.com/questions/611419/how-does-the-escape-character-work-in-bash-prompt)
# - [Stack Overflow: How Do I Change the `virtualenv` Prompt?](https://stackoverflow.com/questions/10406926/how-do-i-change-the-default-virtualenv-prompt)
# - [TCM-SEC Academy: Linux 101](https://academy.tcm-sec.com/p/linux-101)
# - [Antisyphon Training: Regular Expressions with Joff Thyer](https://www.antisyphontraining.com/regular-expressions-your-new-lifestyle-w-joff-thyer/)

# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
GREEN="${C}[1;32m"
YELLOW="${C}[1;33m"
RED_YELLOW="${C}[1;31;103m"
BLUE="${C}[1;34m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
LIGHT_CYAN="${C}[1;96m"
LG="${C}[1;37m" #LightGray
DG="${C}[1;90m" #DarkGray
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"

# Shell variables
export PROMPT_DIRTRIM=1
export VIRTUAL_ENV_DISABLE_PROMPT=1
export EDITOR=nano

interface_list=$(ip link show | awk -F ': ' '{
    if ($0 !~ /state DOWN/ && $2 ~ /[a-z]+[0-9]/) {
        interfaces[NR] = $2
    }
}
END{
    for(i in interfaces){
        if (interfaces[i] ~ /^tun|^tap/) {
            printf interfaces[i] " "
        } else if (interfaces[i] ~ /^wg[0-9]/) {
            printf interfaces[i] " "
        } else if (interfaces[i] ~ /^en/) {
            printf interfaces[i] " "
        } else if (interfaces[i] ~ /^eth/) {
            printf interfaces[i] " "
        } else if (interfaces[i] ~ /^wl[a-z0-9]+$|^ath[0-9]/) {
            printf interfaces[i] " "
        }
    }
}')

get_net_info() {
    # Replace `$(echo $interface_list)` with a specific interface name or list of names if needed (e.g. `tun0 eth0`)
    #for interface in eth0; do
    for interface in $(echo $interface_list); do
        # The `NR==1{<SNIP>; exit}` in awk at the end of the next line only prints the first IP, for interfaces with multipe IPs
        # http://stackoverflow.com/questions/22190902/ddg#22190928
        IFACE_NAME=$(ip addr show dev "$interface" 2>/dev/null | grep -P "inet\s.+$interface$" | awk 'NR==1{print $NF; exit}')
        IFACE_ADDR=$(ip addr show dev "$interface" 2>/dev/null | grep -P "inet\s.+$interface$" | awk 'NR==1{print $2; exit}')
        if [[ -n "${IFACE_NAME}" ]] && [[ -n "${IFACE_ADDR}" ]]; then
            # The "${NC}:${YELLOW}" is being passed to and interpretted by this script in your shell, it resets the color of the `:` symbol
            # using the ANSI colors defined above.
            echo "${IFACE_NAME}${NC}:${YELLOW}${IFACE_ADDR}"
            return
        fi
    done
}

get_timezone() {
    # This will get the timezone (such as "UTC") for use in the PS1 string
    date | awk '{print $6}'
}

venv_prompt() {
    # This is for modifying python virtual environment strings in the shell prompt
    if [[ -n "${VIRTUAL_ENV}" ]]; then
        echo "(venv) "
    fi
}

# Plain text prompt string
#if [ "$PS1" ]; then
#    PS1="┌──[\u@\h:\l]-[\D{%Y-%m-%d}•\t]-[\$(get_net_info)]-[ \W]\n└─\\$ "
#fi

# Color prompt string using brackets
#if [ "$PS1" ]; then
#    PS1="┌──[${GREEN}\u${NC}@${GREEN}\h${NC}:${LIGHT_MAGENTA}\l${NC}]-[${LIGHT_CYAN}\D{%Y-%m-%d}${NC}•${LIGHT_CYAN}\t${NC}]-[${YELLOW}\$(get_net_info)${NC}]-[${GREEN}\w${NC}]\n└─\\$ "
#fi

# Color prompt string without brackets
if [ "$PS1" ]; then
    PS1="┌──/${GREEN}\u${NC}@${GREEN}\h${NC}:${LIGHT_MAGENTA}\l${NC}/ ${LIGHT_CYAN}\D{%Y%m%d%H%M%S}${NC}\$(get_timezone) ${YELLOW}\$(get_net_info)${NC} (${GREEN}\w${NC})\n└─\\$ \$(venv_prompt)"
fi
