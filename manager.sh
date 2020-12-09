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


readonly TMP_LOCATION='/var/tmp'
readonly OPT_LOCATION='/opt'

#
# TEAMSPEAK 3 PATHS
#
readonly TEAMSPEAK_URL='https://files.teamspeak-services.com/releases/server/3.13.2/teamspeak3-server_linux_amd64-3.13.2.tar.bz2'
readonly TEAMSPEAK_STATE='/var/local/teamspeak3/'
readonly TEAMSPEAK_FOLDER_NAME='/teamspeak3-server_linux_amd64/'


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
selinuxenabled
if [ "${?}" -eq 0 ]
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
    "${CURL}" -s "${1}" -o "${TMP_LOCATION}/${2}"
    if [[ "${?}" -ne 0 ]]
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
    "$TAR" -xf "$1" -C "$2"
    if [[ "${?}" -ne 0 ]]
        then
        log "[!!!] Error occured unzipping ${1} to ${2},aborting..." 'r'
        exit 1
    fi
}


# Explain usage.
function usage {
    echo 'No valid option was provided, please provide one of the following functions.'
    echo "${0} fail2ban              --- Installs fail2ban hunter on the server."
    echo "${0} harden                --- Does some common sense hardening on the server."
    echo "${0} nagios                --- Register the server to nagios server."
    echo "${0} postfix               --- Installs and configures a SMTP relay on the server."
    echo "${0} rootkit               --- Installs rootkit hunter on the server."
    echo "${0} teamspeak3            --- Installs Teamspeak3 on the server."

}


# Intall Function.
function install_teamspeak {
    # Make sure all the directories are accessible.
    directory_check "${TMP_LOCATION}" 'force_failure'
    directory_check "${OPT_LOCATION}" 'force_failure'

    # Check if Teamspeak is running.
    systemctl is-active --quiet  teamspeak
    if [[ "${?}" -eq 0 ]]
        then
        log '[w] A teamspeak version is currently running, stopping.' 'w'
        systemctl stop teamspeak
    fi

    # Get a copy of Teamspeak.
    fetch "${TEAMSPEAK_URL}" 'teamspeak.tar'

    # Check if Teamspeak is installed in the default location
    directory_check "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"

    if [[ "${?}" -eq 0 ]]
        then
        log '[w] Previous version of teamspeak found, removing.' 'w'
        rm -rf "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
    fi

    unzip_move "${TMP_LOCATION}/teamspeak.tar" "${OPT_LOCATION}"

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

    # Check if Firewalld restart was successful.
    if [[ "${?}" -ne 0 ]]
        then
        log '[!!!] Failed to bring firewalld up, please manually check firewalld and restart the script.' 'r'
        exit 1
    fi
   


    # Check if a previos version of Teamspeak was installed
    if [[ -f '/var/local/teamspeak3/ts3server.sqlitedb' ]]
        then
        log '[w] A previous version of Teamspeak was found, not overwriting the database.' 'w'
        ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.ini
        ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.sqlitedb

        log "[i] Setting permissions on ${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}" 'g'
        chown -R teamspeak:teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
        chmod 700 "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh

        log "[i] Setting permissions on ${TEAMSPEAK_STATE}" 'g'
        chown -R teamspeak:teamspeak "${TEAMSPEAK_STATE}"
        chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.ini
        chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.sqlitedb    

        else
        log '[i] Starting Teampseak to create configuration and database.' 'g'
        chown -R teamspeak:teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
        chmod 700 "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh
        sudo -u teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh start createinifile=1 license_accepted=1 > /dev/null
        sleep 10
        log '[i] Stopping server.' 'g'
        sudo -u teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh stop > /dev/null

        # Check if /var/local/teamspeak3 exsists. 
        directory_check "${TEAMSPEAK_STATE}" 

        if [[ "${?}" -ne 0  ]] 
            then
            log "[i] Creating ${TEAMSPEAK_STATE}." 'g'
            mkdir -p "${TEAMSPEAK_STATE}"
        fi

        log "[i] Moving State tiles to ${TEAMSPEAK_STATE}" 'g'
        mv "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.ini "${TEAMSPEAK_STATE}"
        mv "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.sqlitedb  "${TEAMSPEAK_STATE}"

        log "[i] Setting permissions on ${TEAMSPEAK_STATE}" 'g'
        chown -R teamspeak:teamspeak "${TEAMSPEAK_STATE}"
        chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.ini
        chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.sqlitedb  

        log "[i] Creatings soft-links to  ${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}" 'g'
        ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.ini
        ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.sqlitedb
        chown -R teamspeak:teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
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
User=teamspeak
Group=teamspeak
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=teamspeak

[Install]
WantedBy=multi-user.target
EOF

        else
            log '[w] A service file for Teamspeak already exsists, not creating again.' 'w'
        fi

    # Fix for the bug reported here. https://forum.teamspeak.com/threads/93623-Instance-check-error-failed-to-register-local-accounting-service-on-Linux/page8
    
    if [[ -f '/dev/shm/7gbhujb54g8z9hu43jre8' ]]
    then
        rm -f /dev/shm/7gbhujb54g8z9hu43jre8
    fi
    
    # Starting teamspeak
    log '[i] Starting Teamspeak' 'g'
    systemctl daemon-reload
    systemctl enable teamspeak /dev/null
    systemctl start teamspeak

    # Sleep 10 seconds to see it started successfully.
    sleep 10

    systemctl is-active --quiet  teamspeak
    if [[ "${?}" -eq 0 ]]
        then
        log '[i] Teamspeak was successfully started.' 'g'
        else
        log '[!!!] Teamspeak could not be started, exsiting..' 'r'

    fi


    log "[i] Removing Teamspeak zip from ${TMP_LOCATION}." 'g'
    rm -r "${TMP_LOCATION}"/teamspeak.tar

}

function install_fail2_ban {
    log '[i] Activating epel-release' 'g'
    yum install -y epel-release > /dev/null
    log '[i] Installing fail2ban' 'g'
    yum install -y fail2ban > /dev/null

    if [[ ! -f '/etc/fail2ban/jail.local' ]]
        then
        log '[i] A settings file for fail2ban does not exsist, creating...' 'g'
        cat > //etc/fail2ban/jail.local << EOF
[DEFAULT]
# Ban IP/hosts for 24 hour ( 24h*3600s = 86400s):
bantime = 86400
 
# An ip address/host is banned if it has generated "maxretry" during the last "findtime" seconds.
findtime = 86400
maxretry = 3
 
# "ignoreip" can be a list of IP addresses, CIDR masks or DNS hosts. Fail2ban
# will not ban a host which matches an address in this list. Several addresses
# can be defined using space (and/or comma) separator. For example, add your 
# static IP address that you always use for login such as 103.1.2.3
#ignoreip = 127.0.0.1/8 ::1 103.1.2.3
 
# Call iptables to ban IP address
banaction = iptables-multiport
 
# Enable sshd protection
[sshd]
enabled = true

EOF
    fi
    log '[i] Starting Fail2ban' 'g'
    systemctl daemon-reload
    systemctl enable fail2ban > /dev/null
    systemctl start fail2ban

    systemctl is-active --quiet  fail2ban
    if [[ "${?}" -eq 0 ]]
        then
        log '[i] Fail2ban was successfully started.' 'g'
        else
        log '[!!!] Fail2ban could not be started, exsiting..' 'r'

    fi




}
   



function install_nagios {
    echo 'Hi there2'
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
        "fail2ban")           set -- "$@" "-f" 
            ;;
        "postfix")            set -- "$@" "-p"
            ;;
        *)                    set -- "$@" "$arg"
            usage
            ;;

    esac
done

function install_postfix {
    # Check if postfix is runnig
    systemctl is-active --quiet  postfix
    if [[ "${?}" -eq 0 ]]
        then
        log '[w] A postfix version is currently running, stopping.' 'w'
        systemctl stop postfix
    fi

    # Check if postfix is already installed.
    yum list --installed | grep postfix > /dev/null

    if [[ "${?}" -ne 0 ]]
        then
        log '[i] Postfix is not installed, installing.' 'g'
        yum install -y postfix > /dev/null 

        # Fix interface.
        log '[i] Fixing default Postfix interface settings.' 'g'
        sed -i 's/inet_interfaces = localhost/inet_interfaces = 127.0.0.1/' /etc/postfix/main.cf
        log '[i] Restarting Postfix.' 'g'
        systemctl restart postfix
        if [[ "${?}" -ne 0 ]]
            then
            log '[!!!] Postfix could not be started, something went wrong with the interface. Check systemctl logs, exiting..' 'r'
            exit 1
        fi   
    fi

    # Get credentials from the user
    read -p 'Enter the SMTP endpont. Default - smtp.gmail.com : ' SMTP
    local SMTP="${SMTP:-smtp.gmail.com}"
    read -p 'Enter the SMTP port. Default - 587 : ' SMTP_PORT
    local SMTP_PORT="${SMTP_PORT:-587}"
    read -p 'Enter the email address. Example:my_email@my_host.com : '  EMAIL
    read -p 'Enter the email token: '  TOKEN

    # Save credentials to files.
    log '[i] Saving credentials to /etc/postfix/sasl_passwd.' 'g'
    echo "[${SMTP}"]:"${SMTP_PORT}" "${EMAIL}":"${TOKEN}" > /etc/postfix/sasl_passwd
    log '[i] Creating Postfix DB file from /etc/postfix/sasl_passwd.' 'g'
    postmap /etc/postfix/sasl_passwd >/dev/null 2>&1
    log '[i] Securing sasl_passwd and sasl_passwd.db files.' 'g'
    chown root:root /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db
    chmod 600 /etc/postfix/sasl_passwd /etc/postfix/sasl_passwd.db

    cat /etc/postfix/main.cf | grep -v '^#' | grep relayhost > /dev/null

    log '[i] Setting up relay-host.' 'g'
    
    if [[ "${?}" -ne 0 ]]
        then
        echo "relayhost = [${SMTP}]:${SMTP_PORT}" >> /etc/postfix/main.cf
        else
        log '[w] Previous configuration found, overwriting.' 'w'
        local CURRENT_VAR="$(cat /etc/postfix/main.cf | grep -v '^#' | grep relayhost)"
        local FIXED_VAR=$(printf '%q\n' "$CURRENT_VAR")
        sed  -in "s|${FIXED_VAR}|relayhost = [${SMTP}]:${SMTP_PORT}|" /etc/postfix/main.cf 
    fi

    log '[i] Removing /etc/pki/tls/certs/ca-bundle.crt entry.' 'g'

    cat /etc/postfix/main.cf | grep -v '^#' | grep 'smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt' > /dev/null

    if [[ "${?}" -eq 0 ]]
    then
        sed  -i 's|smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt||' /etc/postfix/main.cf 
    fi

    local SETTINGS="$(grep -v '^#' /etc/postfix/main.cf)"

    echo ${SETTINGS} | grep 'smtp_use_tls = yes' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
        echo 'smtp_use_tls = yes' >> /etc/postfix/main.cf
        log '[i] Adding entry to /etc/postfix/main.cf' 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
        echo 'smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd' >> /etc/postfix/main.cf
                log '[i] Adding entry to /etc/postfix/main.cf' 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
        echo 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' >> /etc/postfix/main.cf 
                log '[i] Adding entry to /etc/postfix/main.cf' 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_security_options = noanonymous' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
        echo 'smtp_sasl_security_options = noanonymous' >> /etc/postfix/main.cf
                log '[i] Adding entry to /etc/postfix/main.cf' 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_tls_security_options = noanonymous' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
        echo 'smtp_sasl_tls_security_options = noanonymous' >> /etc/postfix/main.cf
                log '[i] Adding entry to /etc/postfix/main.cf' 'g'
    fi

    
    # Starting Postfix
    log '[i] Starting postfix' 'g'
    systemctl daemon-reload
    systemctl enable postfix > /dev/null
    systemctl start postfix

    # Sleep 10 seconds to see if it started successfully.
    sleep 10

    systemctl is-active --quiet  postfix
    if [[ "${?}" -eq 0 ]]
        then
        log '[i] Postfix was successfully started.' 'g'
        else
        log '[!!!] Postfix could not be started, exsiting..' 'r'
    fi



   

}


while getopts tnhrfp OPTIONS
do
    case "${OPTIONS}" in
    t)
        install_teamspeak
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
        install_fail2_ban
        ;;
    p)
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



