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
    directory_check "${TMP_LOCATION}" 'force_failure'
    directory_check "${OPT_LOCATION}" 'force_failure'

    fetch "${TEAMSPEAK_URL}" 'teamspeak.tar'

    directory_check "${OPT_LOCATION}teamspeak3-server_linux_amd64"

    if [[ "${?}" -eq 0 ]]
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

    log '[i] Adding necessary ports to firewalld.' 'g'


    firewall-cmd --permanent --zone=public --add-port=9987/udp >/dev/null 2>&1
    firewall-cmd --permanent --zone=public --add-port=30033/tcp >/dev/null 2>&1
    systemctl restart firewalld

    # Check if Firewalld restat was successfull.
    if [[ "${?}" -ne 0 ]]
    then
        log '[!!!] Failed to bring firewalld up, please manually check firewalld and restart the script.' 'r'
        exit 1
    fi
   


   # Check if a previos version of Teamspeak was installed
    if [[ -f '/var/local/teamspeak3/ts3server.sqlitedb' ]]
    then
        log '[w] A previous version of Teamspeak was found, not overwriting the database.' 'w'
        ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.ini
        ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.sqlitedb
        #ln -s "${TEAMSPEAK_STATE}"ts3server.pid     "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.pid
        log "[i] Setting permissions on ${OPT_LOCATION}teamspeak3-server_linux_amd64 " 'g'
        chown -R teamspeak:teamspeak "${OPT_LOCATION}"teamspeak3-server_linux_amd64
        chmod -R 700 "${OPT_LOCATION}"teamspeak3-server_linux_amd64
        log "[i] Setting permissions on ${TEAMSPEAK_STATE}" 'g'
        chown -R teamspeak:teamspeak "${TEAMSPEAK_STATE}"
        chmod -R 777 "${TEAMSPEAK_STATE}"


    
    else
        log '[i] Starting Teampseak to create configuration and database.' 'g'
        chown -R teamspeak:teamspeak "${OPT_LOCATION}"teamspeak3-server_linux_amd64/
        sudo -u teamspeak "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server_startscript.sh start createinifile=1 license_accepted=1 > /dev/null
        sleep 60
        log '[i] Stopping server.' 'g'
        sudo -u teamspeak "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server_startscript.sh stop > /dev/null
       
        directory_check "${TEAMSPEAK_STATE}"
         
        if [ "${?}" -ne 0  ] 
        then
            log "[w] Creating ${TEAMSPEAK_STATE}." 'w'
            mkdir -p "${TEAMSPEAK_STATE}"
        fi
        log "[i] Moving State tiles to ${TEAMSPEAK_STATE}" 'g'
        mv "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.ini "${TEAMSPEAK_STATE}"
        mv "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.sqlitedb  "${TEAMSPEAK_STATE}"

        log "[i] Setting permissions on ${TEAMSPEAK_STATE}" 'g'
        chown -R teamspeak:teamspeak "${TEAMSPEAK_STATE}"
        chmod -R 777 "${TEAMSPEAK_STATE}"

        log "[i] Creatings soft-links to  ${OPT_LOCATION}\teamspeak3-server_linux_amd64" 'g'
        ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.ini
        ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}"teamspeak3-server_linux_amd64/ts3server.sqlitedb
    fi

        if [[ ! -f '/etc/systemd/system/teamspeak.service' ]]
        then
            log '[i] A service file for Teamspeak does not exsist, creating...' 'g'

            cat > /etc/systemd/system/teamspeak.service << EOF
[Unit]
Description=TeamSpeak Server Service
After=network.target

[Service]
Type=forking
WorkingDirectory=/opt/teamspeak3-server_linux_amd64/
ExecStart=/opt/teamspeak3-server_linux_amd64/ts3server_startscript.sh start inifile=ts3server.ini
ExecStop=/opt/teamspeak3-server_linux_amd64/ts3server_startscript.sh stop
User=root
Group=root
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=teamspeak

[Install]
WantedBy=multi-user.target
EOF

        else
            log '[w] A service file for Teamspeak already exsists, not creating again.' 'w'
        fi

systemctl start teamspeak



   


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



