#!/bin/bash

# Colors used in script
gray="\\e[37m"
blue="\\e[36m"
red="\\e[31m"
green="\\e[32m"
orange="\\e[33m"
reset="\\e[0m"

# Functions to call loggings
info()    { printf "${blue}INFO: $*${reset}\n" 1>&2; }
warning() { printf "${orange}WARN: $*${reset}\n" 1>&2; }
error()   { printf "${red}ERROR: $*${reset}\n" 1>&2; }
success() { printf "${green}✔ $*${reset}\n" 1>&2; }
fail()    { printf "${red}✖ $*${reset}\n" 1>&2; exit 1; }
debug()   { [[ "${DEBUG}" == "true" ]] && echo -e "${gray}DEBUG: $*${reset}\n"  1>&2 || true; }

# Check arguments
DNS_NAME="_8ee26f7bebed6841b15cb7f028d2d769.hermes-belgium.be."

