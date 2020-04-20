#!/bin/bash

OSMOSIX_INSTALL_DIR=/usr/local
OSMOSIX_BASE_DIR=/usr/local/osmosix
DFS_INSTALLED_FILE=$OSMOSIX_BASE_DIR/etc/.DFSINSTALLED
USER_DATA_URL="http://169.254.169.254/latest/user-data"
DFS_BUNDLE_PROP="dfsBundleURL"
DFS_BUNDLE_FILE=/root/dfs_bundle.tar.gz
DFS_BUNDLE_URL=http://${s3Bucket}/${dfsBundlePath}/bundle/cliqr-dfs-@project.version@-dfs-bundle.tar.gz
DFS_BUNDLE_DOWNLOAD_CMD="wget -O $DFS_BUNDLE_FILE  $DFS_BUNDLE_URL"
WATCHME_SCRIPT=/usr/local/osmosix/bin/watchme.sh

createWatchmeScript() {
        echo "#!/bin/bash" > $WATCHME_SCRIPT
        echo "while true; do" >> $WATCHME_SCRIPT
        echo "    sleep 300" >> $WATCHME_SCRIPT
        echo "    if [ -f /root/.done ]; then" >> $WATCHME_SCRIPT
        echo "        exit 0" >> $WATCHME_SCRIPT
        echo "    fi" >> $WATCHME_SCRIPT
	echo "    pid=\`ps aux | grep \"wget -O $DFS_BUNDLE_FILE\" | grep -v \"grep\" | awk '{print \$2}'\`" >> $WATCHME_SCRIPT
        echo "    kill -9 \$pid" >> $WATCHME_SCRIPT
        echo "    rm -rf /root/*.tar.gz" >> $WATCHME_SCRIPT
        echo "    $DFS_BUNDLE_DOWNLOAD_CMD" >> $WATCHME_SCRIPT
	echo "    touch /root/.done" >> $WATCHME_SCRIPT
        echo "done" >> $WATCHME_SCRIPT
	chmod +x $WATCHME_SCRIPT
	$WATCHME_SCRIPT &
}

installDfsBundle() {
        if [ ! -f $DFS_INSTALLED_FILE ]; then
                logger -t "OSMOSIX" "Downloading bundle $DFS_BUNDLE_URL"
                $DFS_BUNDLE_DOWNLOAD_CMD

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
                if [ ! -s $DFS_BUNDLE_FILE ]; then
                        logger -t "OSMOSIX" "Downloaded empty bundle file $DFS_BUNDLE_FILE ..Aborting"
                        exit 1
                fi
                cd $OSMOSIX_INSTALL_DIR
                tar xzf $DFS_BUNDLE_FILE
                chown -R root.root $OSMOSIX_BASE_DIR
		## Due to the tar not preserving symlinks in the new dfs build, need to set the exec perms for all the files as hack
	        ## for now
                chmod -R 755 $OSMOSIX_BASE_DIR
                cd -
                touch $DFS_INSTALLED_FILE
                logger -t "OSMOSIX" "Installed DFS Bundle "
        fi
}

runComponentScript() {
        COMPONENT=`cat /usr/local/osmosix/etc/component`

        test "$COMPONENT" == "" && exit 1

        ## call component's init script
        if [ -f /usr/local/osmosix/bin/$COMPONENT-init.sh ]; then
            /usr/local/osmosix/bin/$COMPONENT-init.sh
        fi

        ## call component's main script
        if [ -f /usr/local/osmosix/bin/$COMPONENT.sh ]; then
            /usr/local/osmosix/bin/$COMPONENT.sh
        fi
}

installDfsAutoUpdateCronJob() {
    if [ -f /usr/local/osmosix/bin/dfs_bundle_update.sh ]; then
        cat /etc/crontab | grep "dfs_bundle_update" >/dev/null 2>&1
        if [ $? -eq 0 ]; then
            return
        fi
        #set cronJob to be every 10 minutes
        #add offset in cronJob to separate the check requests
        offset=`expr $RANDOM % 10`
        echo "$offset-59/10 * * * * root /usr/local/osmosix/bin/dfs_bundle_update.sh >/dev/null 2>&1" >> /etc/crontab
    fi
}

createWatchmeScript
installDfsBundle
#installDfsAutoUpdateCronJob
runComponentScript

exit 0
