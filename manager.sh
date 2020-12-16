#!/usr/bin/env bash

#
# management.sh
# version 1.0 - Yagiz Gulseven
# This script is mostly ShellCheck compliant.
#  
#
#
#
# shellcheck source=/dev/null

#
# Location of folders
#
export readonly TMP_LOCATION='/var/tmp'
export readonly OPT_LOCATION='/opt'
readonly SCRIPT_LOCATION="$(pwd)"
#
# TEAMSPEAK 3 PATHS
#
export readonly TEAMSPEAK_URL='https://files.teamspeak-services.com/releases/server/3.13.2/teamspeak3-server_linux_amd64-3.13.2.tar.bz2'
export readonly TEAMSPEAK_STATE='/var/local/teamspeak3/'
export readonly TEAMSPEAK_FOLDER_NAME='/teamspeak3-server_linux_amd64/'
#
# POSTFIX Settings folder
#
export readonly POSTFIX_SETTINGS='/etc/postfix/'
#
# Fail2ban Settings folder
#
export readonly FAIL2BAN_SETTINGS='/etc/fail2ban/'
#
# Fail2ban Settings folder
#
export readonly LOGWATCH_SETTINGS='/etc/logwatch/'

export readonly LYNIS_LOG='/var/log/lynis/'
#
# VERIFY ALL BINARIES USED
#

readonly CURL="$(command -v curl)"
if [[ -z "${CURL}" ]]
    then
        echo "[!!!] Error: wget  binary not found. Aborting."
        exit 1
fi

readonly TAR="$(command -v tar)"
if [[ -z "${TAR}" ]]
    then
        echo "[!!!] Error: tar  binary not found. Aborting."
        exit 1
fi

# Check if SE-LINUX is enabled
if selinuxenabled
    then 
        echo "I see that SE-Linux is enabled. This is not(yet) supported. Please deactiavate SE-Linux and run the script again."
        exit 1
fi

# Set up the log function. 
function log {
    case "${2}" in
        g)
        COLOR='\033[0;32m'
        ;;
        w)
        COLOR='\033[0;33m'
        ;;
        r)
        COLOR='\033[0;31m'
        ;;
        *)
        COLOR='\033[0m'
        ;;
    esac

    echo -e "${COLOR}" "${1}"
    logger -t "${0}" "${1}"
    printf "\e[0m"
}

function fetch {
    log "[i] Downloading ${1} to ${TMP_LOCATION}/${2}." 'g'
    if ! "${CURL}" -s "${1}" -o "${TMP_LOCATION}/${2}"
        then
            log "[!!!] Error occured while downlading ${1} to ${TMP_LOCATION}/${2}, aborting..." 'r'
            exit 1
    fi
}

function directory_check {
    log "[i] Checking access to ${1}." 'g'
    if [[ ! -d "${1}" ]]
        then
        if [[ "${2}" = 'force_failure' ]]
            then
            log "[!!!] Cannot access ${1}, this is an unsuported state. Please ensure ${1} is readable/writable. Aborting..." 'r'
            exit 1
        fi
        log "[w] Cannot access ${1}" 'w'
        return 1
    fi
}

function unzip_move {
    log "[i] Unzipping file ${1} and moving it to ${2}." 'g'
    if ! "$TAR" -xf "$1" -C "$2"
        then
            log "[!!!] Error occured unzipping ${1} to ${2},aborting..." 'r'
            exit 1
    fi
}

# Explain usage.
function usage {
    echo  'No valid option was provided, please provide one of the following functions.'
    echo  "${0} fail2ban              --- Installs Fail2ban on the server."
    echo  "${0} harden                --- Does some common sense hardening on the server."
    echo  "${0} lynis                 --- Installs Lynis on the server. Requires Postfix."
    echo  "${0} logwatch              --- Installs Logwatch on the server. Requires Postfix."
    echo  "${0} nagios                --- Register the server to Nagios server."
    echo  "${0} postfix               --- Installs and configures a SMTP relay on the server."
    echo  "${0} rkhunter              --- Installs RKhunter hunter on the server."
    echo  "${0} teamspeak             --- Installs Teamspeak3 on the server."

}

# Make the arguments compatible with getopts. Usage of getopt is not recommended.
for arg in "${@}"
do
    shift
    case "${arg}" in
        "teamspeak3")         set -- "$@" "-t"
            ;;
        "nagios")             set -- "$@" "-n" 
            ;;
        "harden")             set -- "$@" "-h" 
            ;;
        "rootkit-hunter")     set -- "$@" "-r" 
            ;;
        "lynis")              set -- "$@" "-c" 
            ;;
        "logwatch")           set -- "$@" "-l" 
            ;;
        "fail2ban")           set -- "$@" "-f" 
            ;;
        "postfix")            set -- "$@" "-p"
            ;;
        *)                    set -- "$@" "$arg"
        usage
            ;;

    esac
done

while getopts tnhrfplc OPTIONS
do
    case "${OPTIONS}" in
    t)
        source "${SCRIPT_LOCATION}"/teamspeak.sh
        install_teamspeak
        ;;
    l)
        source "${SCRIPT_LOCATION}"/logwatch.sh
        install_logwatch
        ;;

    c)
        source "${SCRIPT_LOCATION}"/lynis.sh
        install_lynis
        ;;
    n)
        install_nagios
        ;;
    h)
        harden
        ;;
    r)
        install_rootkit
        ;;
    f)
        source "${SCRIPT_LOCATION}"/fail2ban.sh
        install_fail2_ban
        ;;
    p)
        source "${SCRIPT_LOCATION}"/postfix.sh
        install_postfix
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

