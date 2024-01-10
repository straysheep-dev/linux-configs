#!/bin/bash

# GPL-3.0-or-later

# SYNOPSIS
#
# Review the strings in a file or a directory of files for interesting or malicious content.
# You can pipe this out to `... | tee out.log` and run it again on the log file to get a meta summary.
# This script is designed to quickly drop in and get a sense of what to look for in files. There is likely a much better paid solution for code review like this.
# It currently does not do decoding, decrypting, or deobfuscation / reassembling obfuscated pieces such as variables or strings that are assembled during execution.
# The goal is to try and find files where this might be happening for manual review before compiling / dynamic analysis.
#
# REFERENCES
#
# Regex:
# - https://github.com/EricZimmerman/bstrings/blob/e119db5625656db7e661969f91e04517c55cea97/bstrings/Program.cs#L929
# - https://www.antisyphontraining.com/on-demand-courses/regular-expressions-your-new-lifestyle-w-joff-thyer/
#
# IPv4 representations:
# - https://isc.sans.edu/diary/Adventures%20in%20Validating%20IPv4%20Addresses/30348
#
# Thanks to the following projects for code, ideas, and guidance:
# - https://github.com/DidierStevens/DidierStevensSuite
# - https://github.com/CYB3RMX/Qu1cksc0pe
# - https://github.com/carlospolop/PEASS-ng
# - https://github.com/g0tmi1k/OS-Scripts
# - https://github.com/angristan/openvpn-install

# shellcheck disable=SC2034
# Colors and color printing code taken directly from:
# https://github.com/carlospolop/PEASS-ng/blob/master/linPEAS/builder/linpeas_parts/linpeas_base.sh
C=$(printf '\033')
RED="${C}[1;31m"
SED_RED="${C}[1;31m&${C}[0m"
GREEN="${C}[1;32m"
SED_GREEN="${C}[1;32m&${C}[0m"
YELLOW="${C}[1;33m"
SED_YELLOW="${C}[1;33m&${C}[0m"
RED_YELLOW="${C}[1;31;103m"
SED_RED_YELLOW="${C}[1;31;103m&${C}[0m"
BLUE="${C}[1;34m"
SED_BLUE="${C}[1;34m&${C}[0m"
ITALIC_BLUE="${C}[1;34m${C}[3m"
LIGHT_MAGENTA="${C}[1;95m"
SED_LIGHT_MAGENTA="${C}[1;95m&${C}[0m"
LIGHT_CYAN="${C}[1;96m"
SED_LIGHT_CYAN="${C}[1;96m&${C}[0m"
LG="${C}[1;37m" #LightGray
SED_LG="${C}[1;37m&${C}[0m"
DG="${C}[1;90m" #DarkGray
SED_DG="${C}[1;90m&${C}[0m"
NC="${C}[0m"
UNDERLINED="${C}[5m"
ITALIC="${C}[3m"
BOLD="${C}[01;01m"
SED_BOLD="${C}[01;01m&${C}[0m"

# Initialize argument variables
MIN_LENGTH='1'
INPUT=''
SUMMARIZE='0'

# This is the easiest way to do this in bash, but it won't work in other shells
# See getopt-parse under /usr/share/doc/util-linux/examples
# https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash
POSITIONAL_ARGS=()

while [[ $# -gt 0 ]]; do
	case $1 in
		-n|--minlength)
			MIN_LENGTH="$2"
			shift # past argument
			shift # past value
			;;
		-i|--input)
			INPUT="$2"
			shift # past argument
			shift # past value
			;;
		-s|--summary)
			SUMMARIZE="1"
			shift # past argument
			shift # past value
			;;
		-h|--help)
			echo "[i]Usage: $0 -i <input_file> [-n <min_string_length>] [-s]"
			echo ""
			echo "     -i, --input <file-or-directory>"
			echo "             Path to a file or a directory of files. Ingests all files recursively using find."
			echo ""
			echo "     -n, --minlength <int>"
			echo "             Minimum string length. Sends this option as the argument to 'strings -n <int>'"
			echo ""
			echo "     -s, --summary"
			echo "             Summarize the file(s) based on type (magic bytes) and characteristics"
			exit 0
			shift
			shift
			;;
		-*|--*)
			echo "Unknown option $1"
			exit 1
			;;
		*)
			POSITIONAL_ARGS+=("$1") # save positional arg
			shift # past argument
			;;
	esac
done

if [[ $INPUT == '' ]]; then
	echo "No input path found. Use ./$0 -i <path>"
	exit
fi

# Windows API's
# Currently it's a long 'this-or-this' regex, and is incomplete. There's likely a better way to do this
# https://book.hacktricks.xyz/reversing-and-exploiting/common-api-used-in-malware
# https://learn.microsoft.com/en-us/windows/win32/apiindex/windows-api-list
# https://malapi.io/
APIS_WINDOWS='(URL|VirtualAlloc|VirtualProtect|WriteProcessMemory|NtWriteVirtualMemory|CreateRemoteThread|ResumeThread|Internet|Socket|Bind|Connect|Listen|Accept|Recv|Send)'

# Linux API's
# To do
APIS_LINUX=''

# Find the file(s), put them into a variable to use
FILES=$(find "$INPUT" -type f)

# Declare an associative array to emulate the behavior of a python dictionary
# You can make additions or changes here to expand the usage of this script
# https://github.com/denysdovhan/bash-handbook#array-declaration
# http://stackoverflow.com/questions/1494178/ddg#3467959
declare -A regex_dict
regex_dict['BASE64']='^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$'
regex_dict['PROTOCOLS']='(\S+\w+://|\\\\\\\\)((\w+\.){1,})?\w+\.\w+\S+'
regex_dict['URIS_APIS']='[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}\S+'
regex_dict['IPV4_DOTTED_DECIMAL']='\b(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\b'
regex_dict['IPV4_DECIMAL']='\b(\d){8,10}\b'
regex_dict['IPV4_HEXIDECIMAL']='(0x[0-9a-fA-F]\.){3}0x[0-9a-fA-F]'
regex_dict['IPV4_HEXIDECIMAL_INTEGER']='0x([0-9a-fA-F]){6,7}'
regex_dict['IPV4_DOTTED_OCTAL']='(\d\w?\d\d\.){3}\d\w?\d\d'
regex_dict['IPV4_OCTAL']='0o?([0-9a-fA-F]){9,11}'
regex_dict['IPV4_BINARY']='\b((\d){8,}\.){3}(\d){8,}\b'
regex_dict['IPV6']='([A-F0-9]{1,4}(:|::)){3,8}[A-F0-9]{1,4}'
regex_dict['EMAIL']='\b[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,6}\b'
regex_dict['WINDOWS_PATH']='([a-zA-Z]:\\|\\\\)[^\\\/:*?"<>|\r\n]+(\\[^\\\/:*?"<>|\r\n]+)*'
regex_dict['WINDOWS_REGISTRY']='([a-z0-9]\\)*(software\\)|(sam\\)|(system\\)|(security\\)[a-z0-9\\]+'
regex_dict['VS_BUILD_SCRIPTING']='(exec|call|command=|powershell|\.ps1|\.bat)'
regex_dict['SHELLCODE_HEX']='(?:\\x|0x)?(?:[a-fA-F0-9]){2}(?:,?\s?(?:\\x|0x)?(?:[a-fA-F0-9]){2}){1,}'
regex_dict['WINDOWS_APIS']="$APIS_WINDOWS"
regex_dict['LINUX_APIS']="$APIS_LINUX"
regex_dict['BITCOIN_ADDRESS']='\b[13][a-km-zA-HJ-NP-Z1-9]{25,34}\b'

# Function to get information about the file itself
FileInfo () {
	echo -e "${BLUE}╔═══════════════════════════════════════════════════════${NC}"
	echo -e "${BLUE}╚[◢]${NC}${LIGHT_CYAN}$file${NC}"
	echo ""
	basename "$file" | sed "s/.*/ ${SED_LIGHT_CYAN}/g"
	file "$file" | cut -d ':' -f 2 | sed -E "s/.*$/${SED_YELLOW}/g" | sed -E "s/executable/${SED_RED_YELLOW}/g"
}

# Function to parse strings
StringInfo () {
	# Iterate over the file(s)
	for file in $FILES; do
		# Print the file information banner once per file
		FileInfo
		# Iterate over the associative array
		for key in "${!regex_dict[@]}"; do
			echo ""
			echo -e "${BLUE}      ╔═════════════════════════════════════════════════${NC}"
			echo -e "${BLUE}      ╚[◢]${NC}${BOLD} $key${NC}"
			strings -n "$MIN_LENGTH" "$file" | grep -ioP --color "${regex_dict[$key]}" | sort | uniq -c | sort -n -r | sed -E "s/.*/${SED_GREEN}/g"
		done
	done
}

# Filetype summary
SummarizeFiles () {
	echo ""
	echo -e "${BLUE}╔═══════════════════════════════════════════════════════${NC}"
	# Sort and count all discovered filetypes
	echo -e "  ${BOLD}FILETYPE_SUMMARY${NC}"
	find "$INPUT" -type f -print0 | xargs -0 file > filetypes.tmp # Find is run again here since it's outside of the loop, maybe there's a way to only run it once
	awk -F: '{print $2}' filetypes.tmp| sed -E 's/^\s+//g' | sort | uniq -c | sort -nr | sed -E "s/(executable|binary)/${SED_RED_YELLOW}/g"
	echo ""
	# Highlight possible Visual Studio project files
	echo -e "  ${BOLD}PROJECT FILES${NC}"
	grep -iP "(\.sln|\.csproj)" filetypes.tmp | sed -E 's/^/      /g' | sed -E "s/^.*:/${SED_LIGHT_CYAN}/g"
	echo ""
	echo -e "  ${BOLD}BUILD SCRIPTS${NC}"
	# Highlight possible build scripts
	grep -iP "(\.bat|\.ps1|\.sh|\.vbs)" filetypes.tmp | sed -E 's/^/      /g' | sed -E "s/^.*:/${SED_LIGHT_CYAN}/g"
	echo ""
	# Highlight executable files
	echo -e "  ${BOLD}EXECUTABLE OR BINARY DATA${NC}"
	grep -iP "(executable|binary)" filetypes.tmp | sed -E 's/^/      /g' | sed -E "s/^.*:/${SED_LIGHT_MAGENTA}/g"
	rm filetypes.tmp
	echo -e "${BLUE}╚═══════════════════════════════════════════════════════${NC}"
}

# If using -s, only summarize the filetypes and don't parse their strings
if [[ $SUMMARIZE == '1' ]]; then
	SummarizeFiles
else
	StringInfo
	SummarizeFiles
fi

exit 0
