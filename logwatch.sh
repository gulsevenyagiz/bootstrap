#!/usr/bin/env bash
function install_logwatch {
    # Check if postfix is  installed.
    if ! yum list --installed | grep postfix > /dev/null
        then
            log '[!!!] Postfix is not installed, aborting.' 'r'
            exit 1  
    fi


    # Check if postfix is already installed.
    if ! yum list --installed | grep logwatch > /dev/null
        then
            log '[i] Logwatch is not installed, installing.' 'g'
            yum install -y logwatch > /dev/null 
        else
            log '[w] Logwatch is already installed, not installing again.' 'w'
                if systemctl is-active --quiet  teamspeak
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
    if ! cat "${LOGWATCH_SETTINGS}"conf/logwatch.conf | grep -v '^#' | grep 'Output = mail' > /dev/null
        then
            echo 'Output = mail' >> "${LOGWATCH_SETTINGS}"conf/logwatch.conf
    fi

    # Change Logwatch settings
    log 'Configuring...' 'g'

      # Set up Output to email host.
    if cat "${LOGWATCH_SETTINGS}"conf/logwatch.conf | grep -v '^#' | grep 'MailTo = ' > /dev/null
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