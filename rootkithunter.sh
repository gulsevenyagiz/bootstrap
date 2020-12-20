#!/usr/bin/env bash

function install_rkhunter {
    if ! yum list --installed | grep rkhunter > /dev/null
        then
            # Activate epel-release
            log '[i] Activating epel-release' 'g'
            yum install -y epel-release > /dev/null

            # Intall fail2ban.
            log '[i] Installing rkhunter' 'g'
            yum install -y rkhunter > /dev/null

            #
            log '[i] Updating rkhunter' 'g'
            rkhunter --update
            #
            log '[i] Setting baseline for rkhunter' 'g'
            rkhunter --propupd


        else
             log '[w] Rootkithunter is already installed, not installing again.' 'w'
        fi    



}