#!/bin/bash

# GPL-3.0-or-later

# shellcheck disable=SC2034
# shellcheck disable=SC2116
# shellcheck disable=SC2086

# Controlling the prompt: https://www.gnu.org/software/bash/manual/bash.html#Controlling-the-Prompt-1
# Shell variables: https://www.gnu.org/software/bash/manual/bash.html#Shell-Variables

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
                # The "${NC}:${YELLOW}" is being passed to and interpretted by this script in your shell, it resets the color of the `:` symbol
                net_info=$(ip addr show dev "$interface" 2>/dev/null | grep -P "inet\s.+$interface$" | awk 'NR==1{print $NF "${NC}:${YELLOW}" $2; exit}')
                if [[ "$net_info" != '' ]]; then
                        echo "$net_info" # | tr '\n' ']'  # Uncomment the ` | tr '\n' '|'` if you comment the next line
                        return                            # Comment out "return", and uncomment the | tr '\n' ']' above to print multiple interface matches in $interface_list (eth1, eth2...)
                fi
        done
}

# Plain text prompt string
#if [ "$PS1" ]; then
#    PS1="┌──[\u@\h:\l]-[\D{%Y-%m-%d}•\t]-[$(get_net_info)]-[ \W]\n└─\\$ "
#fi

# Color prompt string using brackets
#if [ "$PS1" ]; then
#    PS1="┌──[${GREEN}\u${NC}@${GREEN}\h${NC}:${LIGHT_MAGENTA}\l${NC}]-[${LIGHT_CYAN}\D{%Y-%m-%d}${NC}•${LIGHT_CYAN}\t${NC}]-[${YELLOW}$(get_net_info)${NC}]-[${GREEN}\w${NC}]\n└─\\$ "
#fi

# Color prompt string without brackets
if [ "$PS1" ]; then
    PS1="┌──/${GREEN}\u${NC}@${GREEN}\h${NC}:${LIGHT_MAGENTA}\l${NC}/ ${LIGHT_CYAN}\D{%Y%m%d%H%M%S}${NC} ${YELLOW}$(get_net_info)${NC} (${GREEN}\w${NC})\n└─\\$ "
fi
