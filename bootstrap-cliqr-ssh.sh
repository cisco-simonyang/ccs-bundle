#!/bin/sh

COMMAND=$1

tryInstallPython() {
    if type apt-get 2>/dev/null; then
        sudo apt-get update
        sudo apt-get -y install python
    elif type yum 2>/dev/null; then
        sudo yum -y install python
    elif type zypper 2>/dev/null; then
        sudo zypper -n in python
    else
        exit 2
    fi
}

case $COMMAND in
    injectKey)
        USERNAME=$2
        if [ $USERNAME = "root" ]; then
            HOME_FOLDER="/root"
        else
            HOME_FOLDER="/home/$USERNAME"
        fi
        AUTHORIZED_FILE="$HOME_FOLDER/.ssh/authorized_keys"
    ;;
    killRequireTty)
        if type perl 2>/dev/null; then
            sudo perl -pi -pe 's/Defaults[[:space:]][[:space:]]*requiretty/#Defaults   requiretty/g;' -pe 's/Defaults[[:space:]][[:space:]]*!visiblepw/#Defaults   !visiblepw/g;' /etc/sudoers
        else
            sudo sed -i 's/Defaults[[:space:]][[:space:]]*requiretty/#Defaults   requiretty/g' /etc/sudoers
            sudo sed -i 's/Defaults[[:space:]][[:space:]]*!visiblepw/#Defaults   !visiblepw/g' /etc/sudoers
        fi
    ;;
    bootstrap)
        PY_BOOTSTRAP_URL=$2
        BOOTSTRAP_SETTING=$3
        CLOUD_FAMILY=$4
        CLOUD_TYPE=$5
        BOOTSTRAP_FILE="/tmp/cliqr-bootstrap.py"

        if type wget 2>/dev/null; then
            wget $PY_BOOTSTRAP_URL -O $BOOTSTRAP_FILE
        elif type curl 2>/dev/null; then
            curl -o $BOOTSTRAP_FILE $PY_BOOTSTRAP_URL
        else
            logger "CliQr Bootstrap - Unable to find command curl or wget"
        fi

        if [ -f $BOOTSTRAP_FILE ]; then
            if type sudo 2>/dev/null; then
                sudo python $BOOTSTRAP_FILE $CLOUD_FAMILY $CLOUD_TYPE $BOOTSTRAP_SETTING
            else
                python $BOOTSTRAP_FILE $CLOUD_FAMILY $CLOUD_TYPE $BOOTSTRAP_SETTING
            fi
            rm $BOOTSTRAP_FILE
        fi
        rm -- "$0"
    ;;
    checkAndInstallPython)
        if type python 2>/dev/null; then
            exit 0
        else
            tryInstallPython
        fi
     ;;
esac

logger "Cliqr-Bootstrap - Unknown command $1"