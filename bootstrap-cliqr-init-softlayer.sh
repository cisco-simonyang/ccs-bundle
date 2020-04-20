#!/bin/bash

BUNDLE_STORE_URL_FILE=/usr/local/bundle-store-url

logger -t "OSMOSIX" "Input arguments to softlayer init bootstrap ? :: $@"
#isAgentFlavorLite="$4"
#logger -t "OSMOSIX" "is Agent Flavor Lite ? :: $isAgentFlavorLite"

bundleStoreURLValue="http://cdn.cliqr.com/release-5.2.2/bundle"

logger -t "OSMOSIX" "Trim any trailing / from Bundle URL: ${bundleStoreURLValue}..."
bundleStoreURLValue=$(echo ${bundleStoreURLValue} | sed 's|/*$||')

logger -t "OSMOSIX" "Add to file $BUNDLE_STORE_URL_FILE: BUNDLE_STORE_URL=${bundleStoreURLValue}"
echo "BUNDLE_STORE_URL=${bundleStoreURLValue}" >& $BUNDLE_STORE_URL_FILE

export BUNDLE_STORE_URL="${bundleStoreURLValue}"

if [ ! -d /usr/local/osmosix ]; then
	PY_BOOTSTRAP_URL="$bundleStoreURLValue/cliqr-bootstrap.py"
	BOOTSTRAP_SETTING="$bundleStoreURLValue/bootstrap.json"
	BOOTSTRAP_FILE="/tmp/cliqr-bootstrap.py"

	if type curl 2>/dev/null; then
		curl --retry 300 -n -o $BOOTSTRAP_FILE $PY_BOOTSTRAP_URL
		if [ $? -ne 0 ]; then
		    sleep 60
		    curl --retry 300 -n -o $BOOTSTRAP_FILE $PY_BOOTSTRAP_URL
		fi
	elif type wget 2>/dev/null; then
		wget $PY_BOOTSTRAP_URL -O $BOOTSTRAP_FILE -t inf
        if [ $? -ne 0 ]; then
            sleep 60
            wget $PY_BOOTSTRAP_URL -O $BOOTSTRAP_FILE -t inf
        fi
	else
		logger -t "OSMOSIX" "No cURL or wget found. Cannot download $PY_BOOTSTRAP_URL"
	fi

	export CUSTOM_REPO="http://repo.cliqrtech.com"

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

	logger -t "OSMOSIX" "Invoke python $BOOTSTRAP_FILE softlayer $BOOTSTRAP_SETTING true ..."
	python $BOOTSTRAP_FILE softlayer $BOOTSTRAP_SETTING true

	logger -t "OSMOSIX" "Delete temporary file: $BOOTSTRAP_FILE ..."
	rm $BOOTSTRAP_FILE
fi

#{cliqrConfigScript}
#{cliqrJsonInjection}
