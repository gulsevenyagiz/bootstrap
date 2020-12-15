#!/usr/bin/env bash

function cleanup()
{
    log "[i] Removing Teamspeak zip from ${TMP_LOCATION}." 'g'
    rm -r "${TMP_LOCATION}"/teamspeak.tar
}

trap cleanup EXIT


function install_teamspeak {
    # Make sure all the directories are accessible.
    directory_check "${TMP_LOCATION}" 'force_failure'
    directory_check "${OPT_LOCATION}" 'force_failure'

    # Check if Teamspeak is running.
    if systemctl is-active --quiet  teamspeak
        then
            log '[w] A teamspeak version is currently running, stopping.' 'w'
            systemctl stop teamspeak
    fi

    # Get a copy of Teamspeak.
    fetch "${TEAMSPEAK_URL}" 'teamspeak.tar'

    # Check if Teamspeak is installed in the default location
    if directory_check "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
        then
            log '[w] Previous version of teamspeak found, removing.' 'w'
            rm -rf "${OPT_LOCATION}${TEAMSPEAK_FOLDER_NAME}"
    fi
    unzip_move "${TMP_LOCATION}/teamspeak.tar" "${OPT_LOCATION}"

    # Check if the teamspeak user exsists, if not create it.
    if grep 'teamspeak' /etc/passwd > /dev/null
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
    if ! systemctl restart firewalld

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
            if ! directory_check "${TEAMSPEAK_STATE}" 
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
            cat teamspeak.service > /etc/systemd/system/teamspeak.service  
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
    if systemctl is-active --quiet  teamspeak
        then
            log '[i] Teamspeak was successfully started.' 'g'
        else
            log '[!!!] Teamspeak could not be started, exsiting..' 'r'
    fi

}