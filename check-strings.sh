#!/bin/bash

# MIT License

# This script helps in reviewing files for URI's, domains, encoding, shellcode, protocols, and various other strings worth looking at.
# This is not exhaustive and should not be completely relied on, but used to get a quick overview of a file.

# Regular expressions are used from bstrings by Eric Zimmerman:
# https://github.com/EricZimmerman/bstrings/blob/master/LICENSE.md

INPUT_FILE="$1"

if [ "$1" == '' ]; then
	echo "[i]Usage: ./check-strings.sh <input_file> -v[v]"
	exit
fi

if ! [[ -e "$INPUT_FILE" ]]; then
	echo "Error, $INPUT_FILE not found. Quitting."
fi

if [[ "$2" == '-vv' ]]; then
	echo "[>]Checking $INPUT_FILE..."
	echo ""
	echo '=================================================='
	echo '[v] base64 strings'
	strings "$INPUT_FILE" | grep -P --color "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$"

	echo ""
	echo '=================================================='
	echo '[v] protocols / urls'
	strings "$INPUT_FILE" | grep -iP --color "\b\w+://((\w+\.){1,})?\w+\.\w+\b"

	echo ""
	echo '=================================================='
	echo '[v] uris / domains'
	strings "$INPUT_FILE" | grep -iP --color "[A-Z0-9.-]+\.[A-Z]{2,6}\b"
	
	echo ""
	echo '=================================================='
	echo '[v] IPv4'
	strings "$INPUT_FILE" | grep -P --color "\b(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\b"
	
	echo ""
	echo '=================================================='
	echo '[v] IPv6'
	strings "$INPUT_FILE" | grep -iP --color "([A-F0-9]{1,4}(:|::)){3,8}[A-F0-9]{1,4}"
	
	echo ""
	echo '=================================================='
	echo '[v] shellcode / hex'
	strings "$INPUT_FILE" | grep -iP --color "(\\\\x|0x)([a-f0-9]){2}"
elif [[ "$2" == '-v' ]]; then
	echo "[>]Checking $INPUT_FILE..."
	echo ""
	echo '=================================================='
	echo '[v] base64 strings'
	strings "$INPUT_FILE" | grep -oP --color "^(?:[A-Za-z0-9+/]{4})*(?:[A-Za-z0-9+/]{2}==|[A-Za-z0-9+/]{3}=|[A-Za-z0-9+/]{4})$" | sort | uniq -c | sort -n -r

	echo ""
	echo '=================================================='
	echo '[v] protocols / urls'
	strings "$INPUT_FILE" | grep -ioP --color "\b\w+://((\w+\.){1,})?\w+\.\w+\b" | sort | uniq -c | sort -n -r

	echo ""
	echo '=================================================='
	echo '[v] uris / domains'
	strings "$INPUT_FILE" | grep -ioP --color "[A-Z0-9.-]+\.[A-Z]{2,6}\b" | sort | uniq -c | sort -n -r
	
	echo ""
	echo '=================================================='
	echo '[v] IPv4'
	strings "$INPUT_FILE" | grep -oP --color "\b(?:(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\.){3}(?:25[0-5]|2[0-4][0-9]|1[0-9][0-9]|[1-9]?[0-9])\b" | sort | uniq -c | sort -n -r
	
	echo ""
	echo '=================================================='
	echo '[v] IPv6'
	strings "$INPUT_FILE" | grep -ioP --color "([A-F0-9]{1,4}(:|::)){3,8}[A-F0-9]{1,4}" | sort | uniq -c | sort -n -r
	
	echo ""
	echo '=================================================='
	echo '[v] shellcode / hex'
	strings "$INPUT_FILE" | grep -ioP --color "(\\\\x|0x)([a-f0-9]){2}" | sort | uniq -c | sort -n -r
else
	echo "[i]Usage: ./check-strings.sh <input_file> -v[v]"
	echo ""
	echo "    -v"
	echo "        Match only on results and sort them by frequency of occurance"
	echo "    -vv"
	echo "        More verbose results, showing the entire line, unsorted"
fi

