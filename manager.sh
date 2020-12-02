#!/usr/bin/env bash

#
# management.sh
# version 1.0 - Yagiz Gulseven
# This script is ShellCheck compliant.
#



#
# VERIFY ALL BINARIES USED
#

TMP_LOCATION='/var/tmp/'
TEAMSPEAK_URL='https://files.teamspeak-services.com/releases/server/3.13.2/teamspeak3-server_linux_amd64-3.13.2.tar.bz2'

readonly CURL="$(command -v curl)"
if [[ -z "${CURL}" ]]
then
   echo "[!] Error: wget  binary not found. Aborting."
   exit 1
fi

readonly TAR="$(command -v tar)"
if [[ -z "${TAR}" ]]
then
   echo "[!] Error: tar  binary not found. Aborting."
   exit 1
fi



# Set up the log function. 
function log {
    echo "${1}"
    logger -t "${0}" "${1}"
}
function fetch {
    log "Downloading ${1} to ${TMP_LOCATION}$2 "
    "${CURL}" -s "${1}" -o "${TMP_LOCATION}${2}" 
}
function temp_folder {
    if [[ ! -d "${TMP_LOCATION}" ]]
    then
        log "Cannot access tmp location, this is an unsuported state. Please ensure ${TMP_LOCATION} is readable/writable."
        exit 1
    fi
}
# Explain usage.
function usage {
    echo 'No valid option was provided,please provide one of the following functions.'
    echo "Usage: ${0} [-v] enables verbosity "
    echo ""${0}" teamspeak3    --- Installs Teamspeak3 on the server."
    echo ""${0}" nagios        --- Register the server to nagios server."
    echo ""${0}" harden        --- Does some common sense hardening on the server."
}

# Intall Function.
function install_teamspeak {
   log "Checking access to ${TMP_LOCATION}"
   temp_folder

   fetch "${TEAMSPEAK_URL}" 'teamspeak.tar'
}
function install_nagios {
    echo 'Hi there2'
}
# Make the arguments compatible with getopts. Usage of getopt is not recommended.
for arg in "${@}"; do
  shift
  case "${arg}" in
    "teamspeak") set -- "$@" "-t" ;;
    "nagios") set -- "$@" "-n" ;;
    "harden")   set -- "$@" "-h" ;;
    *)        set -- "$@" "$arg"
  esac
done


while getopts tnh OPTIONS
do
    case "${OPTIONS}" in
    t)
        install_teamspeak
        ;;
    n)
        install_nagios
        ;;
    h)
        install_teamspeak
        ;;
    *)
        usage
        ;;
    esac
done


if [[ "${#}" -lt 1 ]]
then
  usage
  exit 1
fi



