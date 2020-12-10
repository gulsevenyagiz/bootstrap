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
# Location of folders
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
# POSTFIX Settings folder
#
readonly POSTFIX_SETTINGS='/etc/postfix/'

#
# Fail2ban Settings folder
#
readonly FAIL2BAN_SETTINGS='/etc/fail2ban/'

#
# Fail2ban Settings folder
#
readonly LOGWATCH_SETTINGS='/etc/logwatch/'

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
    echo  'No valid option was provided, please provide one of the following functions.'
    echo  "${0} fail2ban              --- Installs fail2ban hunter on the server."
    echo  "${0} harden                --- Does some common sense hardening on the server."
    echo  "${0} logwatch              --- Installs logwatch on the server. Requires postfix."
    echo  "${0} nagios                --- Register the server to nagios server."
    echo  "${0} postfix               --- Installs and configures a SMTP relay on the server."
    echo  "${0} rootkit               --- Installs rootkit hunter on the server."
    echo  "${0} teamspeak3            --- Installs Teamspeak3 on the server."

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

    # Add ports to firewalld.
    log '[i] Adding necessary ports to firewalld.' 'g'
    firewall-cmd --permanent --zone=public --add-port=9987/udp >/dev/null 2>&1
    firewall-cmd --permanent --zone=public --add-port=30033/tcp >/dev/null 2>&1
    systemctl restart firewalld
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
            # Start teamspeak to create configuration files.
            log '[i] Starting Teampseak to create configuration and database.' 'g'
            chown -R teamspeak:teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
            chmod 700 "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh
            sudo -u teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh start createinifile=1 license_accepted=1 > /dev/null
            sleep 10
            # Stop verser
            log '[i] Stopping server.' 'g'
            sudo -u teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server_startscript.sh stop > /dev/null

            # Check if /var/local/teamspeak3 exsists. 
            directory_check "${TEAMSPEAK_STATE}" 
            if [[ "${?}" -ne 0  ]] 
                then
                log "[i] Creating ${TEAMSPEAK_STATE}." 'g'
                mkdir -p "${TEAMSPEAK_STATE}"
            fi
            # Move configuration files to state location
            log "[i] Moving State tiles to ${TEAMSPEAK_STATE}" 'g'
            mv "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.ini "${TEAMSPEAK_STATE}"
            mv "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.sqlitedb  "${TEAMSPEAK_STATE}"
            # Set permissions
            log "[i] Setting permissions on ${TEAMSPEAK_STATE}" 'g'
            chown -R teamspeak:teamspeak "${TEAMSPEAK_STATE}"
            chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.ini
            chmod -R 660 "${TEAMSPEAK_STATE}"ts3server.sqlitedb  
            # Create softlinks to teamspeak directory.
            log "[i] Creatings soft-links to  ${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}" 'g'
            ln -s "${TEAMSPEAK_STATE}"ts3server.ini          "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.ini
            ln -s "${TEAMSPEAK_STATE}"ts3server.sqlitedb     "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"ts3server.sqlitedb
            chown -R teamspeak:teamspeak "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
        fi
    # Check if service exsists.
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
    
    # Start teamspeak
    log '[i] Starting Teamspeak' 'g'
    systemctl daemon-reload
    systemctl  enable --quiet teamspeak 
    systemctl start teamspeak

    # Sleep 10 seconds to see it started successfully.
    sleep 10
    # Report status of job.
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
    # Check if fail2ban is already installed.
    yum list --installed | grep fail2ban > /dev/null
    if [[ "${?}" -eq 0 ]]
        then
            log '[!!!] Fail2ban is already installed, not installing again.' 'r'
            exit 1
    fi

    # Activate epel-release
    log '[i] Activating epel-release' 'g'
    yum install -y epel-release > /dev/null

    # Intall fail2ban.
    log '[i] Installing fail2ban' 'g'
    yum install -y fail2ban > /dev/null

    # Make sure directory is availibe
    directory_check "${FAIL2BAN_SETTINGS}" 'force_failure'

    # Check if configuration fail exsists.
    if [[ ! -f "${FAIL2BAN_SETTINGS}jail.local" ]]
        then
            log '[i] A settings file for fail2ban does not exsist, creating...' 'g'
            cat > "${FAIL2BAN_SETTINGS}jail.local" << EOF
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
        else
            log '[w] A fail2ban configuration file already exsists, not creating again.' 'w'
    fi

    # Start fail2ban.
    log '[i] Starting Fail2ban' 'g'
    systemctl daemon-reload
    systemctl enable --quiet fail2ban 
    systemctl start fail2ban
    systemctl is-active --quiet  fail2ban
    if [[ "${?}" -eq 0 ]]
        then
            log '[i] Fail2ban was successfully started.' 'g'
        else
            log '[!!!] Fail2ban could not be started, exsiting..' 'r'
    fi
}
   
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
            yum -y install postfix cyrus-sasl-plain mailx > /dev/null 
        
            # Fix interface.
            directory_check "${POSTFIX_SETTINGS}" 'force_failure'
            log '[i] Fixing default Postfix interface settings.' 'g'
            sed -i 's/inet_interfaces = localhost/inet_interfaces = 127.0.0.1/' "${POSTFIX_SETTINGS}"main.cf
            log '[i] Restarting Postfix.' 'g'
            systemctl restart postfix
        if [[ "${?}" -ne 0 ]]
            then
                log '[!!!] Postfix could not be started, something went wrong with the interface. Check systemctl logs, exiting..' 'r'
                exit 1
        fi   
    fi

    # Check access to postfix directory.
    directory_check "${POSTFIX_SETTINGS}" 'force_failure'

    # Get credentials from the user
    read -p 'Enter the SMTP endpont. Default - smtp.gmail.com : ' SMTP
    local SMTP="${SMTP:-smtp.gmail.com}"
    read -p 'Enter the SMTP port. Default - 587 : ' SMTP_PORT
    local SMTP_PORT="${SMTP_PORT:-587}"
    read -p 'Enter the email address. Example:my_email@my_host.com : '  EMAIL
    read -p 'Enter the email token: '  TOKEN

    # Save credentials to files.
    log "[i] Saving credentials to ${POSTFIX_SETTINGS}sasl_passwd." 'g'
    echo "[${SMTP}"]:"${SMTP_PORT}" "${EMAIL}":"${TOKEN}" > "${POSTFIX_SETTINGS}"sasl_passwd
    log "[i] Creating Postfix DB file from  ${POSTFIX_SETTINGS}sasl_passwd." 'g'
    postmap "${POSTFIX_SETTINGS}"sasl_passwd >/dev/null
    log '[i] Securing sasl_passwd and sasl_passwd.db files.' 'g'
    chown root:root "${POSTFIX_SETTINGS}"sasl_passwd "${POSTFIX_SETTINGS}"sasl_passwd.db
    chmod 600 "${POSTFIX_SETTINGS}"sasl_passwd "${POSTFIX_SETTINGS}"sasl_passwd.db

    log '[i] Setting up relay-host.' 'g'
    # Set up relay host.
    cat "${POSTFIX_SETTINGS}"main.cf | grep -v '^#' | grep relayhost > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo "relayhost = [${SMTP}]:${SMTP_PORT}" >> "${POSTFIX_SETTINGS}"main.cf
        else
            log '[w] Previous configuration found, overwriting.' 'w'
            sed  -i "/relayhost =/d" "${POSTFIX_SETTINGS}"main.cf 
            echo "relayhost = [${SMTP}]:${SMTP_PORT}" >> "${POSTFIX_SETTINGS}"main.cf
    fi

    # Check if the wrong cert is activated.
    cat "${POSTFIX_SETTINGS}"main.cf | grep -v '^#' | grep 'smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt' > /dev/null
    if [[ "${?}" -eq 0 ]]
    then
        log '[i] Removing /etc/pki/tls/certs/ca-bundle.crt entry.' 'g'
        sed  -i 's|smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt||' "${POSTFIX_SETTINGS}"main.cf 
    fi

    # Activate other settings.
    local SETTINGS="$(grep -v '^#' ${POSTFIX_SETTINGS}main.cf)"

    echo ${SETTINGS} | grep 'smtp_use_tls = yes' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'smtp_use_tls = yes' >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    echo ${SETTINGS} | grep "smtp_sasl_password_maps = hash:${POSTFIX_SETTINGS}sasl_passwd" > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo "smtp_sasl_password_maps = hash:${POSTFIX_SETTINGS}sasl_passwd" >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' >> "${POSTFIX_SETTINGS}"main.cf 
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_security_options = noanonymous' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'smtp_sasl_security_options = noanonymous' >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_tls_security_options = noanonymous' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'smtp_sasl_tls_security_options = noanonymous' >> "${POSTFIX_SETTINGS}"main.cf
           log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    echo ${SETTINGS} | grep 'smtp_sasl_auth_enable = yes' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'smtp_sasl_auth_enable = yes' >> "${POSTFIX_SETTINGS}"main.cf
           log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    
    # Starting Postfix
    log '[i] Starting postfix' 'g'
    systemctl daemon-reload
    systemctl enable --quiet postfix 
    systemctl start postfix

    # Sleep 10 seconds to see if it started successfully.
    sleep 10

    systemctl is-active --quiet  postfix
    if [[ "${?}" -eq 0 ]]
        then
            log '[i] Postfix was successfully started.' 'g'
        else
            log '[!!!] Postfix could not be started, exsiting..' 'r'
            exit 1
    fi



   

}


function install_logwatch {
    # Check if postfix is already installed.
    yum list --installed | grep logwatch > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            log '[i] Logwatch is not installed, installing.' 'g'
            yum install -y logwatch > /dev/null 
        else
            log '[w] Logwatch is already installed, not installing again.' 'w'
                systemctl is-active --quiet  teamspeak
                if [[ "${?}" -eq 0 ]]
                    then
                        log '[w] Logwatch is currently running, stopping.' 'w'
                        systemctl stop teamspeak
                fi
    fi

    # Check logwatch directory
    directory_check "${LOGWATCH_SETTINGS}" 'force_failure'

    # Get the email address to report too.
    read -p 'Enter the email address for Logwatch reports : ' EMAIL



    
    # Set up Output to email host.
    cat "${LOGWATCH_SETTINGS}"conf/logwatch.conf | grep -v '^#' | grep 'Output = mail' > /dev/null
    if [[ "${?}" -ne 0 ]]
        then
            echo 'Output = mail' >> "${LOGWATCH_SETTINGS}"conf/logwatch.conf
    fi

    # Change Logwatch settings
    log 'Configuring...' 'g'

      # Set up Output to email host.
    cat "${LOGWATCH_SETTINGS}"conf/logwatch.conf | grep -v '^#' | grep 'MailTo = ' > /dev/null
    if [[ "${?}" -eq 0 ]]
        then
            log 'A previous email was set, changing.' 'w'
            sed  -i "/MailTo =/d" "${LOGWATCH_SETTINGS}"conf/logwatch.conf
            echo "MailTo = ${EMAIL}" >> "${LOGWATCH_SETTINGS}"conf/logwatch.conf
        else
            echo "MailTo = ${EMAIL}" >> "${LOGWATCH_SETTINGS}"conf/logwatch.conf
            log 'Setting up email address' 'g'
    fi


    # Setting up crontab
    log '[i] Setting up crontab' 'g'
    crontab -l > logwatch
    echo "* * * * * $(which logwatch)" >> logwatch
    crontab logwatch
    rm logwatch


    log '[i] Logwatch was installed started.' 'g'
    logwatch
    log '[i] I have sent a test email, please check if it was received.' 'g'





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


while getopts tnhrfpl OPTIONS
do
    case "${OPTIONS}" in
    t)
        install_teamspeak
        ;;
    l)
        install_logwatch
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

