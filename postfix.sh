#!/usr/bin/env bash

function install_postfix {
    # Check if postfix is runnig
    if systemctl is-active --quiet  postfix
        then
            log '[w] A postfix version is currently running, stopping.' 'w'
            systemctl stop postfix
    fi

    # Check if postfix is already installed.
    if ! yum list --installed | grep postfix > /dev/null
        then
            log '[i] Postfix is not installed, installing.' 'g'
            yum -y install postfix cyrus-sasl-plain mailx > /dev/null 
        
            # Fix interface.
            directory_check "${POSTFIX_SETTINGS}" 'force_failure'
            log '[i] Fixing default Postfix interface settings.' 'g'
            sed -i 's/inet_interfaces = localhost/inet_interfaces = 127.0.0.1/' "${POSTFIX_SETTINGS}"main.cf
            log '[i] Restarting Postfix.' 'g'
            if ! systemctl restart postfix
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
    if ! cat "${POSTFIX_SETTINGS}"main.cf | grep -v '^#' | grep relayhost > /dev/null
        then
            echo "relayhost = [${SMTP}]:${SMTP_PORT}" >> "${POSTFIX_SETTINGS}"main.cf
        else
            log '[w] Previous configuration found, overwriting.' 'w'
            sed  -i "/relayhost =/d" "${POSTFIX_SETTINGS}"main.cf 
            echo "relayhost = [${SMTP}]:${SMTP_PORT}" >> "${POSTFIX_SETTINGS}"main.cf
    fi

    # Check if the wrong cert is activated.
    if cat "${POSTFIX_SETTINGS}"main.cf | grep -v '^#' | grep 'smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt' > /dev/null
    then
        log '[i] Removing /etc/pki/tls/certs/ca-bundle.crt entry.' 'g'
        sed  -i 's|smtp_tls_CAfile = /etc/pki/tls/certs/ca-bundle.crt||' "${POSTFIX_SETTINGS}"main.cf 
    fi

    # Activate other settings.
    local SETTINGS
    SETTINGS="$(grep -v '^#' ${POSTFIX_SETTINGS}main.cf)"

    if ! echo "${SETTINGS}" | grep 'smtp_use_tls = yes' > /dev/null
        then
            echo 'smtp_use_tls = yes' >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    if ! echo "${SETTINGS}" | grep "smtp_sasl_password_maps = hash:${POSTFIX_SETTINGS}sasl_passwd" > /dev/null
        then
            echo "smtp_sasl_password_maps = hash:${POSTFIX_SETTINGS}sasl_passwd" >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    if ! echo "${SETTINGS}" | grep 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' > /dev/null
        then
            echo 'smtp_tls_CAfile = /etc/ssl/certs/ca-bundle.crt' >> "${POSTFIX_SETTINGS}"main.cf 
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    if ! echo "${SETTINGS}" | grep 'smtp_sasl_security_options = noanonymous' > /dev/null
        then
            echo 'smtp_sasl_security_options = noanonymous' >> "${POSTFIX_SETTINGS}"main.cf
            log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    if ! echo "${SETTINGS}" | grep 'smtp_sasl_tls_security_options = noanonymous' > /dev/null
        then
            echo 'smtp_sasl_tls_security_options = noanonymous' >> "${POSTFIX_SETTINGS}"main.cf
           log "[i] Adding entry to  ${POSTFIX_SETTINGS}main.cf" 'g'
    fi

    if ! echo "${SETTINGS}" | grep 'smtp_sasl_auth_enable = yes' > /dev/null
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

    if systemctl is-active --quiet  postfix
        then
            log '[i] Postfix was successfully started.' 'g'
        else
            log '[!!!] Postfix could not be started, exsiting..' 'r'
            exit 1
    fi



   

}
