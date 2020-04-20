#!/bin/bash

BUNDLE_STORE_URL_FILE=/usr/local/bundle-store-url
SNAPSHOT_FILE=/usr/local/osmosix/etc/.snapshot

logger -t "OSMOSIX" "Bootstrap Cliqr Init started for Cloud Family: $1"
logger -t "OSMOSIX" "Bootstrap Cliqr Init invoked with Bundle store URL value: $3"

isAgentFlavorLite="$4"
logger -t "OSMOSIX" "Bootstrap Cliqr Init. Agent Flavor Lite ? $isAgentFlavorLite"

bundleStoreURLValue="DefaultEmptyURL"
if [ ! -f $BUNDLE_STORE_URL_FILE ] || [ -f $SNAPSHOT_FILE ]; then
	logger -t "OSMOSIX" "Bundle Store URL file does not exist or this is a Snapshot mode. Assign the 3rd input arg as bundle Store URL: $3"
	bundleStoreURLValue="$3"

	logger -t "OSMOSIX" "Trim any trailing / from Bundle URL..."
	bundleStoreURLValue=$(echo ${bundleStoreURLValue} | sed 's|/*$||')

	logger -t "OSMOSIX" "Add to file $BUNDLE_STORE_URL_FILE: BUNDLE_STORE_URL=${bundleStoreURLValue}"
	echo "BUNDLE_STORE_URL=${bundleStoreURLValue}" > $BUNDLE_STORE_URL_FILE

	export BUNDLE_STORE_URL="${bundleStoreURLValue}"
fi

#{bundleStoreCredential}

if [ ! -d /usr/local/osmosix ]; then
	BOOTSTRAP_METADATA_EXTRACTOR_URL="$bundleStoreURLValue/metadata_extractor.sh"
	BOOTSTRAP_METADATA_EXTRACTOR_FILE="/tmp/metadata_extractor.sh"
	logger -t "OSMOSIX" "Download the file : $BOOTSTRAP_METADATA_EXTRACTOR_URL and save as $BOOTSTRAP_METADATA_EXTRACTOR_FILE"
	curl --retry 300 -n -o $BOOTSTRAP_METADATA_EXTRACTOR_FILE  $BOOTSTRAP_METADATA_EXTRACTOR_URL
	if [ -f $BOOTSTRAP_METADATA_EXTRACTOR_FILE ]; then
		logger -t "OSMOSIX" "Execute the downloaded metadata extractor script: $BOOTSTRAP_METADATA_EXTRACTOR_FILE ..."
		bash -x $BOOTSTRAP_METADATA_EXTRACTOR_FILE $1 $3
	else
		logger -t "OSMOSIX" "Metadata extraction script not found. Supported clouds will use corresponding implementations to extract metadata."
	fi

	PY_BOOTSTRAP_URL="$bundleStoreURLValue/cliqr-bootstrap.py"
	BOOTSTRAP_SETTING="$bundleStoreURLValue/bootstrap.json"
	BOOTSTRAP_FILE="/tmp/cliqr-bootstrap.py"
	logger -t "OSMOSIX" "Download: $PY_BOOTSTRAP_URL and save as local file: $BOOTSTRAP_FILE"

	if type curl 2>/dev/null; then
		logger -t "OSMOSIX" "Using cURL..."
		curl --retry 300 -n -o $BOOTSTRAP_FILE $PY_BOOTSTRAP_URL
		if [ $? -ne 0 ]; then
		    sleep 60
		    curl --retry 300 -n -o $BOOTSTRAP_FILE $PY_BOOTSTRAP_URL
		fi
	elif type wget 2>/dev/null; then
		logger -t "OSMOSIX" "Using wget..."
		wget $PY_BOOTSTRAP_URL -O $BOOTSTRAP_FILE -t inf
        if [ $? -ne 0 ]; then
            sleep 60
            wget $PY_BOOTSTRAP_URL -O $BOOTSTRAP_FILE -t inf
        fi
	else
		logger -t "OSMOSIX" "No cURL or wget found. Cannot download $PY_BOOTSTRAP_URL"
	fi

	logger -t "OSMOSIX" "Export Custom Repo arg: $2"
	export CUSTOM_REPO="$2"

	# In Ubuntu Systems if python2 is not installed try and install it
	logger -t "OSMOSIX" "Check python < v3.0 is installed or not..."
	which python
	if [[ $? -ne 0 ]]; then
		logger -t "OSMOSIX" "python < v3.0 is not installed"
		if [[ -f /etc/lsb-release ]]; then
			logger -t "OSMOSIX" "Update packages..."
			apt-get -y update
			logger -t "OSMOSIX" "Install python..."
			apt-get -y install python
		else
			logger -t "OSMOSIX" "Cannot execute bootstrap python script"
		fi
	fi

	logger -t "OSMOSIX" "Invoke python $BOOTSTRAP_FILE $1 $BOOTSTRAP_SETTING $isAgentFlavorLite ..."
	python $BOOTSTRAP_FILE $1 $BOOTSTRAP_SETTING $isAgentFlavorLite

	logger -t "OSMOSIX" "Delete temporary file: $BOOTSTRAP_FILE ..."
	rm $BOOTSTRAP_FILE
fi

#{cliqrConfigScript}
#{cliqrJsonInjection}
