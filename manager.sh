#!/usr/bin/env bash
##
#
# management.sh
# version 1.0 - Yagiz Gulseven
# This script is ShellCheck compliant.
#
#
#
#
#
# VERIFY ALL BINARIES USED
#

TMP_LOCATION='/var/tmp/'
OPT_LOCATION='/opt/'

TEAMSPEAK_URL='https://files.teamspeak-services.com/releases/server/3.13.2/teamspeak3-server_linux_amd64-3.13.2.tar.bz2'
TEAMSPEAK_STATE='/var/local/teamspeak3/'

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
}


function fetch {
    log "[i] Downloading ${1} to ${TMP_LOCATION}${2}." 'g'
    "${CURL}" -s "${1}" -o "${TMP_LOCATION}${2}"
    if [[ "${?}" -ne 0 ]]
    then
        log "[!!!] Error occured while downlading ${1} to ${TMP_LOCATION}${2}, aborting..." 'r'
        exit 1
    fi
}


function temp_folder {
    log "[i] Checking access to ${TMP_LOCATION}." 'g'
    if [[ ! -d "${TMP_LOCATION}" ]]
    then
        log "[!!!] Cannot access tmp location, this is an unsuported state. Please ensure ${TMP_LOCATION} is readable/writable. aborting..." 'r'
        exit 1
    fi
}


function unzip_move {
    log "[i] Unzipping file ${1} and moving it to ${2}." 'g'
    "$TAR" -xf "$1" -C "$2"
    if [[ "${?}" -ne 0 ]]
    then
        log "[!!!] Error occured unzipping ${1} to ${2},aborting..." 'r'
        exit 1
    fi
}


# Explain usage.
function usage {
    echo 'No valid option was provided,please provide one of the following functions.'
    echo "Usage: ${0} [-v] enables verbosity "
    echo "${0} teamspeak3    --- Installs Teamspeak3 on the server."
    echo "${0} nagios        --- Register the server to nagios server."
    echo "${0} harden        --- Does some common sense hardening on the server."
}


# Intall Function.
function install_teamspeak {
    temp_folder
    fetch "${TEAMSPEAK_URL}" 'teamspeak.tar'

    if [[ -d "${OPT_LOCATION}teamspeak3-server_linux_amd64" ]]
    then
        log '[w] Previous version of teamspeak found, removing.' 'w'
        rm -rf "${OPT_LOCATION}/teamspeak3-server_linux_amd64"
    fi

    unzip_move "${TMP_LOCATION}teamspeak.tar" "${OPT_LOCATION}"

    # Check if the teamspeak user exsists, if not create it.
   
    grep 'teamspeak' /etc/passwd > /dev/null

    if [[ "${?}" -eq 0 ]]
    then
        log '[w] Teamspeak user already exsists, not creating again.' 'w'
    else
        adduser teamspeak --system --no-create-home --no-log --shell /sbin/nologin
        passwd -l teamspeak > /dev/dell
    fi



   # Check if a previos version of Teamspeak was installed
   if [[ -f '/var/local/teamspeak3/ts3server.sqlitedb' ]]
   then
        log '[w] A previous version of Teamspeak was found, not overwriting the database.' 'w'
        ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.ini
        ln -s "${TEAMSPEAK_STATE}"files                  "${OPT_LOCATION}"teamspeak3-server_linux_amd64/files
        ln -s "${TEAMSPEAK_STATE}"logs                   "${OPT_LOCATION}"teamspeak3-server_linux_amd64/logs
        ln -s "${TEAMSPEAK_STATE}"query_ip_allowlist.txt "${OPT_LOCATION}"teamspeak3-server_linux_amd64/query_ip_allowlist.txt
        ln -s "${TEAMSPEAK_STATE}"query_ip_denylist.txt  "${OPT_LOCATION}"teamspeak3-server_linux_amd64/query_ip_denylist.txt
        ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.sqlitedb
        #ln -s "${TEAMSPEAK_STATE}"ts3server.pid     "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.pid
        log "[i] Setting permissions on "${OPT_LOCATION}"teamspeak3-server_linux_amd64 " 'g'
        chown -R teamspeak:teamspeak "${OPT_LOCATION}"teamspeak3-server_linux_amd64
        chmod -R 700 "${OPT_LOCATION}"teamspeak3-server_linux_amd64
        if [[ ! -f '/etc/systemd/system/teamspeak.service' ]]
        then
            log '[w] A service file for Teamspeak does not exsist, creating...' 'g'

            cat > /etc/systemd/system/teamspeak.service << EOF
[Unit]
Description=TeamSpeak Server Service
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/teamspeak3-server_linux_amd64/
ExecStart=/opt/teamspeak3-server_linux_amd64/ts3server_startscript.sh start inifile=ts3server.ini
ExecStop=/opt/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
User=teamspeak
Group=teamspeak
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=teamspeak

[Install]
WantedBy=multi-user.target
EOF

        else
            log '[i] A service file for Teamspeak already exsists, not creating again.' 'w'
        fi
        

   fi




   


}
function install_nagios {
    echo 'Hi there2'
}
# Make the arguments compatible with getopts. Usage of getopt is not recommended.
for arg in "${@}"; do
    case "${arg}" in
        "teamspeak3") set -- "$@" "-t"
            ;;
        "nagios")     set -- "$@" "-n" 
            ;;
        "harden")     set -- "$@" "-h" 
            ;;
        *)            set -- "$@" "$arg"
            ;;
    esac
    shift
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



