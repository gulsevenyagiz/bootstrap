#!/usr/bin/env bash

function install_fail2_ban {
    # Check if fail2ban is already installed.
    if yum list --installed | grep fail2ban > /dev/null
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
            cat fail2ban.settings > "${FAIL2BAN_SETTINGS}jail.local" 

        else
            log '[w] A fail2ban configuration file already exsists, not creating again.' 'w'
    fi

    # Start fail2ban.
    log '[i] Starting Fail2ban' 'g'
    systemctl daemon-reload
    systemctl enable --quiet fail2ban 
    systemctl start fail2ban
    if systemctl is-active --quiet  fail2ban
        then
            log '[i] Fail2ban was successfully started.' 'g'
        else
            log '[!!!] Fail2ban could not be started, exsiting..' 'r'
    fi
}