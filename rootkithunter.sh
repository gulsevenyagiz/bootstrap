#!/usr/bin/env bash

function install_rkhunter {
    if yum list --installed | grep rkhunter > /dev/null
        then
            log '[w] Rootkithunter is already installed, not installing again.' 'w'
        else
            # Activate epel-release
            log '[i] Activating epel-release' 'g'
            yum install -y epel-release > /dev/null

            # Intall fail2ban.
            log '[i] Installing fail2ban' 'g'
            yum install -y rkhunter > /dev/null
        fi    
    # Check if logwatch is installed 
    if yum list --installed | grep logwatch > /dev/null
        then
            log '[w] I see that logwatch is installed, do you want to remove daily mails from rkhunter since it is attached to logwatch anyway ?' 'w'
            read -p "Continue (y/n)?" choice
            case "$choice" in 
                y|Y|yes|Yes)
                    echo "yes";;
                n|N|no|No ) echo "no";;
                * ) echo 'Invalid option selected, aborting';;
            esac
    fi    


}