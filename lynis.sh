#!/usr/bin/env bash

function install_lynis {
    # Check if fail2ban is already installed.
    if yum list --installed | grep lynis > /dev/null
        then
            log '[!!!] Lynis is already installed, not installing again.' 'r'
            exit 1
    fi

    # Activate epel-release
    log '[i] Activating epel-release' 'g'
    yum install -y epel-release > /dev/null

    # Intall fail2ban.
    log '[i] Installing Lynis' 'g'
    yum install -y lynis > /dev/null

    # Add cronjob
    log '[i] Adding cronjob for lynis.' 'g'
    cp lynis.cron  /etc/cron.weekly/lynis

    log '[i] Setting permissions for the cronjob.' 'g'
    chmod 700 /etc/cron.weekly/lynis
    chown root:root /etc/cron.weekly/lynis

    # Create log directory, if necessary.
    if ! directory_check "${LYNIS_LOG}"
    then
        log "[i] Creating ${LYNIS_LOG} " 'g'
        mkdir "${LYNIS_LOG}"
    fi


}
    