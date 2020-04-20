#!/bin/bash

#Check if bundle store url file is present, and if so then source it to set the env variable(s) like BUNDLE_STORE_URL
test -f /usr/local/bundle-store-url && . /usr/local/bundle-store-url

action=$1
exec_id=$2
cloud_unique_resource_id=$3
agent_flavor_lite_upgrade=$4
gateway_input_bundle_store_url=$5;

logger -t "OSMOSIX" "Bootstrap cliqr worker invoked with arguments: "$@""

if [[ ! $action ]]; then
  action="install"
  exec_id=''
  cloud_unique_resource_id=''
fi

logger -t "OSMOSIX" "Execute bootstrap cliqr worker in mode: $action"

extractAgentFlavorLite() {
	user_data_json="$OSMOSIX_SYSTEM_DATA"
	temp=`echo "$user_data_json" | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w agentFlavorLite`
	echo ${temp##*:}
}

extractBrokerHost(){
	user_data_json="$OSMOSIX_SYSTEM_DATA"
	brokerClusterAddresses=`echo "$user_data_json" | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w brokerClusterAddresses`
	portRemovedFragment=${brokerClusterAddresses%%:*}
    echo ${portRemovedFragment##*|}
}

extractBrokerPort(){
	user_data_json="$OSMOSIX_SYSTEM_DATA"
	brokerClusterAddresses=`echo "$user_data_json" | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w brokerClusterAddresses`
	echo ${brokerClusterAddresses##*:}
}

extractBundleStoreURL(){
	user_data_json="$OSMOSIX_SYSTEM_DATA"
	bundleStoreURLFragment=`echo "$user_data_json" | sed 's/\\\\\//\//g' | sed 's/[{}]//g' | awk -v k="text" '{n=split($0,a,","); for (i=1; i<=n; i++) print a[i]}' | sed 's/\"\:\"/\|/g' | sed 's/[\,]/ /g' | sed 's/\"//g' | grep -w BundleStoreUrl`
	echo ${bundleStoreURLFragment##*|}
}


#BASE_DIR='/usr/local'
STAGE_DIR='/usr/local/cliqrstage'
AGENTGO_UPGRADE_INPUT_FILE=${STAGE_DIR}/agentlite/bin/agentgo_upgrade_input

SYS_OSMOSIX_DIR='/usr/local/osmosix'
AGENT_INSTALLED_FILE=${SYS_OSMOSIX_DIR}/etc/.AGENTINSTALLED

user_data_json="$OSMOSIX_SYSTEM_DATA"
logger -t "OSMOSIX" "Obtained user_data :: [$user_data_json]"

isAgentFlavorLite=`extractAgentFlavorLite`
if [[ ${action} == "upgrade" ]] ; then
    isAgentFlavorLite="$agent_flavor_lite_upgrade"
    logger -t "OSMOSIX" "Action Mode is 'upgrade'. Is agent type to which upgrade is being done agent lite ? : $agent_flavor_lite_upgrade "
fi
logger -t "OSMOSIX" "New Agent being used: $isAgentFlavorLite"

if [[ ${isAgentFlavorLite} == "true" ]] ; then
    logger -t "OSMOSIX" "Stop any existing c3agent service..."
    if [ -f /etc/init.d/c3agent ]; then
        logger -t "OSMOSIX" "Stopping c3agent..."
        /etc/init.d/c3agent stop
        rm -f $AGENT_INSTALLED_FILE
    fi
    logger -t "OSMOSIX" "Stop any existing jetty service..."
    if [ -f /etc/init.d/jetty ]; then
        logger -t "OSMOSIX" "Stopping jetty..."
        /etc/init.d/jetty stop
        rm -f $AGENT_INSTALLED_FILE
    fi
elif [[ ! -f ${AGENT_INSTALLED_FILE} ]] || [[ ${action} == "upgrade" ]] ; then
    . ${SYS_OSMOSIX_DIR}/etc/.osmosix.sh
else
    logger -t "OSMOSIX" "Agent already at latest version.Skipping"
    echo "Agent already at latest version.Skipping"
    exit 0
fi

AGENT_BUNDLE_BASE_URL="$BUNDLE_STORE_URL"
logger -t "OSMOSIX" "Agent Bundle Store URL from env param: $AGENT_BUNDLE_BASE_URL"
if [ -z "$BUNDLE_STORE_URL" ]; then
    logger -t "OSMOSIX" "Bundle Store URL env param is empty. Extract from user-data..."
    AGENT_BUNDLE_BASE_URL=`extractBundleStoreURL`
    logger -t "OSMOSIX" "Agent Bundle Store URL from User-data: $AGENT_BUNDLE_BASE_URL"
fi

#If the Action is upgrade and the upgrade URL is passed, only then use it as the Agent Bundle Base URL
if [[ ${action} == "upgrade" ]] && [[ -n "$gateway_input_bundle_store_url" ]] ; then
    logger -t "OSMOSIX" "Action Mode is 'upgrade' with Bundle store URL provided as : $gateway_input_bundle_store_url "
	AGENT_BUNDLE_BASE_URL=$gateway_input_bundle_store_url
fi
logger -t "OSMOSIX" "Agent bundle base URL: [${AGENT_BUNDLE_BASE_URL}]"

TAR_AGENT_BUNDLE=osmosix-agent-@project.version@-worker-bundle.tar.gz
if [[ ${isAgentFlavorLite} == "true" ]]; then
    logger -t "OSMOSIX" "Golang agent will be installed"
    TAR_AGENT_BUNDLE=agent-lite-linux-bundle.tar.gz
fi
logger -t "OSMOSIX" "Tar Agent Bundle to be Used: $TAR_AGENT_BUNDLE"

OSMOSIX_CURL_CREDENTIAL=''
OSMOSIX_WGET_CREDENTIAL=''

if [ 'true' == "$OSMOSIX_CREDENTIAL_REQUIRED" ]; then
	logger -t "OSMOSIX" "Credentials will be used"
	OSMOSIX_CURL_CREDENTIAL="-u $OSMOSIX_BOOTSTRAP_USERNAME:$OSMOSIX_BOOTSTRAP_PASSWORD"
	OSMOSIX_WGET_CREDENTIAL="--user $OSMOSIX_BOOTSTRAP_USERNAME --password $OSMOSIX_BOOTSTRAP_PASSWORD"
fi

AGENT_BUNDLE_URL=$AGENT_BUNDLE_BASE_URL/$TAR_AGENT_BUNDLE
logger -t "OSMOSIX" "Agent Bundle URL:$AGENT_BUNDLE_URL"
AGENT_BUNDLE_FILE=/root/osmosix-agent.tar.gz
logger -t "OSMOSIX" "Agent Bundle Local file:$AGENT_BUNDLE_FILE"

AGENT_BUNDLE_DOWNLOAD_CMD=''
AGENT_BUNDLE_DOWNLOAD_CURL_CMD="curl ${OSMOSIX_CURL_CREDENTIAL} -o ${AGENT_BUNDLE_FILE} ${AGENT_BUNDLE_URL}"
AGENT_BUNDLE_DOWNLOAD_WGET_CMD="wget ${OSMOSIX_WGET_CREDENTIAL} -O ${AGENT_BUNDLE_FILE} ${AGENT_BUNDLE_URL}"

WATCHME_SCRIPT=/root/watchme.sh
WATCHME_REGEX=''
WATCHME_REGEX_WGET="wget.* -O $AGENT_BUNDLE_FILE"
WATCHME_REGEX_CURL="curl.* -o $AGENT_BUNDLE_FILE"

logger -t "OSMOSIX" "Check and choose curl or wget based on availability..."
if [ -x "$(command -v curl)" ]; then
	logger -t "OSMOSIX" "cURL will be used to download Agent Bundle..."
	AGENT_BUNDLE_DOWNLOAD_CMD=${AGENT_BUNDLE_DOWNLOAD_CURL_CMD}
	WATCHME_REGEX=${WATCHME_REGEX_CURL}
elif [ -x "$(command -v wget)" ]; then
	logger -t "OSMOSIX" "wget will be used to download Agent Bundle..."
	AGENT_BUNDLE_DOWNLOAD_CMD=${AGENT_BUNDLE_DOWNLOAD_WGET_CMD}
	WATCHME_REGEX=${WATCHME_REGEX_WGET}
else
	logger -t "OSMOSIX" "No curl or wget found. Cannot install Agent because $AGENT_BUNDLE_URL can't be downloaded."
	logger -t "OSMOSIX" "Use an image which has cURL or wget available."
	exit 1
fi

AGENT_VERSION=@project.version@

#-------------------------------------------------------
# Function - createWatchmeScript
# Make sure the bundle download is successful
#-------------------------------------------------------
createWatchmeScript() {
    logger -t "OSMOSIX" "Creating watchme script"

    echo "#!/bin/bash" > $WATCHME_SCRIPT
    echo "while true; do" >> $WATCHME_SCRIPT
    echo "    sleep 300" >> $WATCHME_SCRIPT
    echo "    if [ -f /root/.done ]; then" >> $WATCHME_SCRIPT
    echo "        exit 0" >> $WATCHME_SCRIPT
    echo "    fi" >> $WATCHME_SCRIPT
    echo "    pid=\`ps aux | grep \"$WATCHME_REGEX\" | grep -v \"grep\" | awk '{print \$2}'\`" >> $WATCHME_SCRIPT
    echo "    kill -9 \$pid" >> $WATCHME_SCRIPT
    echo "    rm -rf $AGENT_BUNDLE_FILE" >> $WATCHME_SCRIPT
    echo "    $AGENT_BUNDLE_DOWNLOAD_CMD" >> $WATCHME_SCRIPT
    echo "    touch /root/.done" >> $WATCHME_SCRIPT
    echo "done" >> $WATCHME_SCRIPT

    chmod +x $WATCHME_SCRIPT
    $WATCHME_SCRIPT &
}


#-------------------------------------------------------
# Function - installC3Agent
# Download and install the c3agent bundle
#-------------------------------------------------------
installC3Agent() {

    if [ ! -f $AGENT_INSTALLED_FILE ] || [ ${action} == "upgrade" ] ; then
        logger -t "OSMOSIX" "Downloading bundle: [${AGENT_BUNDLE_URL}] using command: [${AGENT_BUNDLE_DOWNLOAD_CMD}]"

        # Strip leading and trailing whitespace
        AGENT_BUNDLE_URL="${AGENT_BUNDLE_URL#"${AGENT_BUNDLE_URL%%[![:space:]]*}"}"   # remove leading whitespace
        AGENT_BUNDLE_URL="${AGENT_BUNDLE_URL%"${AGENT_BUNDLE_URL##*[![:space:]]}"}"   # remove trailing whitespace
        logger -t "OSMOSIX" "Downloading bundle  ${AGENT_BUNDLE_URL} using command: ${AGENT_BUNDLE_DOWNLOAD_CMD}"

        #echo -n ${AGENT_BUNDLE_URL} >> /root/checkURL.txt
        #echo -n ${AGENT_BUNDLE_DOWNLOAD_CMD} >> /root/checkURL.txt


        ${AGENT_BUNDLE_DOWNLOAD_CMD}  &>/root/checkDown.txt
        if [ $? -eq 0 ]; then
            touch /root/.done
        else
            while true; do
                if  [ -f /root/.done ]; then
                    break
                fi
                sleep 3
            done
        fi

        if [ ! -s $AGENT_BUNDLE_FILE ]; then
            logger -t "OSMOSIX" "Downloaded empty bundle file $AGENT_BUNDLE_FILE ..Aborting"
            exit 1
        fi

        installTarBundle

        touch $AGENT_INSTALLED_FILE
        logger -t "OSMOSIX" "Installed Agent Bundle "

    fi
}

#-------------------------------------------------------
# Function - installTarBundle
# Extract the bundle and call service start
#-------------------------------------------------------
installTarBundle () {

    logger -t "OSMOSIX" "Extract Agent Bundle and invoke install/upgrade script"

    if [[ ! -d ${STAGE_DIR} ]]; then
      mkdir -p ${STAGE_DIR}
    fi
    cd ${STAGE_DIR}

    currDir=$(pwd)
    logger -t "OSMOSIX" "Extract Agent Bundle file: $AGENT_BUNDLE_FILE in current directory: $currDir"
    tar xzf $AGENT_BUNDLE_FILE >/root/bunextract.txt

    # We create agent install marker prior to calling agent start script
    # to avoid a race condition where agent install may be called twice
    touch $AGENT_INSTALLED_FILE

    c3agent_init_script='c3agent/osmosix/bin/c3agent_init.sh'
    if [[ ${isAgentFlavorLite} == "true" ]]; then
        logger -t "OSMOSIX" "Agent Flavor is GOLANG so Use different INIT SCRIPT"
        c3agent_init_script='agentlite/bin/install'

        if [[ ${action} == "upgrade" ]]; then
            logger -t "OSMOSIX" "Write upgrade properties to upgrade input file: $AGENTGO_UPGRADE_INPUT_FILE_REL_PATH"
            export OSMOSIX_CLOUD=$(cat /usr/local/osmosix/etc/cloud 2>/dev/null)
            export AGENT_VERSION=$(cat agentlite/version 2>/dev/null)
            export OSMOSIX_SYSTEM_DATA=$(cat /usr/local/osmosix/etc/user-data 2>/dev/null)
            # Assumption is that colon : will not be used in any of the values being written
            echo "$exec_id:$cloud_unique_resource_id:$AGENT_VERSION" > "$AGENTGO_UPGRADE_INPUT_FILE"
            upgradeInput=$(cat $AGENTGO_UPGRADE_INPUT_FILE)
            logger -t "OSMOSIX" "Properties written to upgrade input file for AgentGo upgrade: $upgradeInput"
        fi
    fi

    logger -t "OSMOSIX" "Init Script being used - $c3agent_init_script"
    logger -t "OSMOSIX" "Action: $action"
    logger -t "OSMOSIX" "ExecId: $exec_id"
    logger -t "OSMOSIX" "cloudUniqueResourceId: $cloud_unique_resource_id"
    logger -t "OSMOSIX" "AgentVersion: $AGENT_VERSION"
    logger -t "OSMOSIX" "Cloud Family: $OSMOSIX_CLOUD"

    chmod 755 ${c3agent_init_script}

    if [[ ${isAgentFlavorLite} == "true" ]]; then
        logger -t "OSMOSIX" "Agent Flavor is GOLANG so Install Golang Agent"
        brokerHost=`extractBrokerHost`
        logger -t "OSMOSIX" "Broker Host from user-data: $brokerHost"
        brokerPort=`extractBrokerPort`
        logger -t "OSMOSIX" "Broker Port from user-data: $brokerPort"
        if [[ ! $brokerPort ]]; then
            logger -t "OSMOSIX" "Use default broker port 5671"
            brokerPort="5671"
        fi
        ./${c3agent_init_script} -bh ${brokerHost} -bp ${brokerPort} -c ${OSMOSIX_CLOUD} -m greenfield -a ${action} -S
    else
        logger -t "OSMOSIX" "Agent Flavor is JAVA so Install JAVA Agent"
        ./${c3agent_init_script} ${action} ${AGENT_VERSION} ${exec_id} ${cloud_unique_resource_id}
    fi

    if [[ $? -ne 0 ]]; then
        logger -t "OSMOSIX" "Failed to ${action} Agent service. Aborting..."
        rm -f $AGENT_INSTALLED_FILE
        exit 1
    fi
    return 0
}

createWatchmeScript
installC3Agent
