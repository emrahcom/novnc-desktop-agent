#!/bin/bash
set -e


# -----------------------------------------------------------------------------
# NOVNC-DESKTOP-AGENT
# -----------------------------------------------------------------------------
# Github: https://github.com/emrahcom/novnc-desktop-agent
# Dependencies: x11vnc, websockify, yad
#
# -----------------------------------------------------------------------------
NOVNC_SERVER="172.17.17.48"


# -----------------------------------------------------------------------------
# Messages
# -----------------------------------------------------------------------------
TITLE="noVNC Desktop Agent"
MSG_CLOSE_OLD="There is an already running instance and it will be terminated.\nDo you want to continue?"
MSG_SHARE="Do you want to share your desktop?"
MSG_SHARE_INFO="\nPlease, send the connection link and the password to your colleague"
MSG_CLOSE="The desktop sharing session is started. Close this window to terminate"
MSG_CONNECTED="someone connected from"


# -----------------------------------------------------------------------------
# ENVIRONMENT
# -----------------------------------------------------------------------------
PGID=$$
RUNDIR="/var/run/user/$UID"
PIDFILE="$RUNDIR/vnc.$PGID"
HOST=$(hostname -I | awk '{print $1}')
PORT=6080
SHARE_LINK="http://$NOVNC_SERVER/novnc/?host=$HOST&amp;port=$PORT"

echo $PGID > $PIDFILE


# -----------------------------------------------------------------------------
# cleanup
# -----------------------------------------------------------------------------
function cleanup {
    set +e

    pkill -U $UID -f " YAD-$PGID"
    pkill -U $UID -f " VNC-$PGID"
    sleep 0.2 && pkill -U $UID -9 -f " VNC-$PGID"
    pkill -U $UID -f "websockify .*$PORT"

    rm -f $PIDFILE
    pkill -U $UID -g $PGID
}

# trap func
trap cleanup EXIT


# -----------------------------------------------------------------------------
# terminate_active_instances: terminate the active instances except this one
# -----------------------------------------------------------------------------
function terminate_active_instances {
    ls $RUNDIR/vnc.* | grep -v "vnc.$PGID" | \
    while read -r pidfile
    do
        pgid=$(echo $pidfile | cut -d '.' -f2)

        pkill -U $UID -f " YAD-$pgid" || true
        pkill -U $UID -f " VNC-$pgid" || true
        sleep 0.2 && pkill -U $UID -9 -f " VNC-$pgid" || true
        pkill -U $UID -f "websockify .*$PORT" || true

        pkill -U $UID -g $pgid || true
        rm -f $pidfile
    done
}


# -----------------------------------------------------------------------------
# create-credential: x11vnc password
# -----------------------------------------------------------------------------
function create-credential {
    mkdir -p ~/.vnc
    PASSWD=$(shuf -i 100000-999999 -n 1)
    x11vnc -storepasswd $PASSWD ~/.vnc/passwd

    (yad --title="$TITLE" --splash --no-escape --borders=20 \
        --text-align=center --selectable-labels \
        --buttons-layout=edge --button=gtk-cancel:0 \
        --form --align=center \
        --field="<big>$SHARE_LINK</big>:LBL" --field=" :LBL" \
        --field="<b><big><big>$PASSWD</big></big></b>:LBL" \
        --field=" :LBL" --field=":LBL" --field="$MSG_SHARE_INFO:LBL" \
        -- YAD-$PGID && kill $PGID) &
}


# -----------------------------------------------------------------------------
# start-websockify
# -----------------------------------------------------------------------------
function start-websockify {
    while read -r output
    do
        if [[ -n "$(echo $output | egrep 'connecting to')" ]]; then
            ip=$(echo $output | cut -d ' ' -f1)
            yad --title="" --escape-ok --fixed --borders=20 \
                --text-align=center --timeout=5 --no-buttons \
                --text="$MSG_CONNECTED" \
                --form --align=center --field=" :LBL" \
                --field="<b><big><big>$ip</big></big></b>:LBL" \
                -- YAD-$PGID &
        fi
    done < <(websockify --heartbeat=30 $PORT 127.0.0.1:$VNCPORT 2>&1)
}


# -----------------------------------------------------------------------------
# share-desktop: start and manage the x11vnc and websockify instances
# -----------------------------------------------------------------------------
function share-desktop {
    oldport=0
    splashed=false

    while read -r output
    do
        if [[ -n "$(echo $output | egrep '^PORT=')" ]]; then
            VNCPORT=$(echo $output | cut -d '=' -f2)

            # restart websockify if the port is changed
            if [[ "$oldport" != "$VNCPORT" ]]; then
                pkill -U $UID -f "websockify .*$PORT" || true
                start-websockify &
                oldport=$VNCPORT
            fi
        # open the permanent splash window if it's not opened before
        elif [[ -n "$(echo $output | egrep 'client_set_net:')" ]] && \
             [[ "$splashed" = false ]]; then
            pkill -U $UID -f " YAD-$PGID" || true
            (yad --title="$TITLE" --splash --no-escape --borders=20 \
                --buttons-layout=edge --button=gtk-close:0 \
                --text="$MSG_CLOSE" \
                -- YAD-$PGID && kill $PGID) &
            splashed=true
        fi
    done < <(x11vnc -display :0 -localhost -autoport 5900 -noipv6 -nolookup \
                    -once -loop -usepw -shared -noxdamage -nodpms \
                    -tag VNC-$PGID 2>&1)
}

# -----------------------------------------------------------------------------
# RUN
# -----------------------------------------------------------------------------
# check the running instances. don't go on if the user don't accept to
# terminate the old instances.
[[ -n "$(ls $RUNDIR/vnc.* | grep -v vnc.$PGID)" ]] && \
    yad --title="$TITLE" --splash --no-escape --borders=20 \
        --buttons-layout=edge --button=gtk-yes:0 --button=gtk-no:1 \
        --text="$MSG_CLOSE_OLD" \
        -- YAD-$PGID

# terminate the running instances
terminate_active_instances

# confirmation to start a new instance
yad --title="$TITLE" --splash --no-escape --borders=20 \
    --buttons-layout=edge --button=gtk-yes:0 --button=gtk-no:1 \
    --text="$MSG_SHARE" \
    -- YAD-$PGID

# create and share the credential
create-credential

# start to share the desktop
share-desktop
