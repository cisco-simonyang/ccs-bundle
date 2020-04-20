__author__ = 'zfeng'

import sys
import os
import logging
import re
import urllib2
import time
import shutil

LOG_FILENAME = '/tmp/cliqr_bootstrap.log'

def setupBundleStoreCredential():
    netrc = "/root/.netrc"
    if os.path.exists(netrc):
        f = open(netrc)
        str = f.read()
        bundleStoreCredential = str.rstrip().split(' ')
        bundleStoreLocation = bundleStoreCredential[1]
        user = bundleStoreCredential[3];
        password = bundleStoreCredential[5]
        url = urllib2.HTTPPasswordMgrWithDefaultRealm( )
        url.add_password(None, bundleStoreLocation, user, password)
        auth = urllib2.HTTPBasicAuthHandler(url)
        opener = urllib2.build_opener(auth)
        urllib2.install_opener(opener)

def downloadFileToFolder(downloadUrl, targetFolder, maxTry):
    while maxTry > -1:
        logging.info('Begin to download %s to folder %s' % (downloadUrl, targetFolder))
        fileName = os.path.basename(downloadUrl)
        target = os.path.join(targetFolder, fileName)

        try:
            req = urllib2.urlopen(downloadUrl)
            CHUNK = 4 * 1024 * 1024

            f = open(target, 'wb')
            while True:
                chunk = req.read(CHUNK)
                if not chunk:
                    break
                f.write(chunk)
            f.close()
        except urllib2.URLError:
            logging.error('Cannot find url %s' % downloadUrl)

        if os.path.exists(target):
            logging.info('Successfully download file %s to %s' % (downloadUrl, targetFolder))
            break
        else:
            logging.error('Failed to download file %s to %s, %d retries remain' % (downloadUrl, targetFolder, maxTry))
            --maxTry
            time.sleep(5)

    return target

def parseDistroFile(fileName, parsingMethods, osNameMap):
    '''

    :param fileName: Config file of the OS with distribution information
    :param parsingMethods: A dictionary tells how to parse the config file
    :return: osType String
    '''

    logging.info('Parsing os config file %s using method %s' % (fileName, parsingMethods))
    f = open(fileName)

    #Before doing any parsing, change all the characters to lower case
    lines = [line.lower() for line in f.readlines()]

    f.close()

    #Parse distribution name
    distro = None
    lineStart = parsingMethods['distro']['lineStart']

    for line in lines:
        if line.startswith(lineStart):
            content = line.replace(lineStart, '')

            for osName in osNameMap.keys():
                for osNameRecognizer in osNameMap[osName]:
                    if re.search(osNameRecognizer, content) is not None:
                        distro = osName
                        break

                if distro is not None:
                    break
    if distro is None:
        logging.error("Unable to find any information about what the distribution is in file %s" % fileName)
        return None, None

    #Parse distribution version
    def versionParser(lines, lineStart, pattern):
        version = None
        for line in lines:
            if line.startswith(lineStart):
                versionMatch = re.search(pattern, line)

                if versionMatch is not None:
                    version = line[versionMatch.start() : versionMatch.end()]
                    break
        return version

    version = None
    if 'version' in parsingMethods.keys():
        #In this case, the version is in the format major.minor
        lineStart = parsingMethods['version']['lineStart']
        pattern = parsingMethods['version']['regex']
        version = versionParser(lines, lineStart, pattern)

        if version is None:
            logging.error('Failed to get version information from file %s' % fileName)

    else:
        major = ''
        minor = ''
        #In this case, major version and minor version is stored seperately
        if 'major' in parsingMethods.keys():
            lineStart = parsingMethods['major']['lineStart']
            pattern = parsingMethods['major']['regex']
            major = versionParser(lines, lineStart, pattern)
        if 'minor' in parsingMethods.keys():
            lineStart = parsingMethods['minor']['lineStart']
            pattern = parsingMethods['minor']['regex']
            minor = versionParser(lines, lineStart, pattern)

        if major is None or minor is None:
            version = None
            logging.error('Failed to get major.minor information from file %s' % fileName)
        else:
            version = '%s.%s' % (major, minor)

    return distro, version

def getOsType(distro, version, osTypeMap):
    try:
        fver = float(version)
    except ValueError:
        logging.error("Failed to parse version string %s, float expected" % version)
        return None

    if distro not in osTypeMap.keys():
        logging.error("Unexpected distribution name %s, configuration file may contain errors" % distro)
        return None

    distros = osTypeMap[distro]
    for osTypeName in distros.keys():
        if distros[osTypeName]['lowerVersion'] <= fver < distros[osTypeName]['upperVersion']:
            return osTypeName

    logging.error("Unable to find matching osTypeName in osTypeMap")
    return None

def getDistroFile(parsingRules):
    '''

    :param parsingRules: A dictionary including all the knowledges
                         required to get the distribution of the system
    :return: osType string, osName String, version String
             if out of knowledges, return none
    '''
    if parsingRules is None:
        return None, None, None
    else:
        logging.info("Begin to parse the configuration file")

        configFileTypes = parsingRules['configFileType']
        configFilePrefs  = parsingRules['configFilePref']
        levels = len(configFilePrefs.keys())
        found = False
        parsingMethodName = None
        confFileName = None

        for level in range(levels):
            levelKey = str(level)
            for confType in configFilePrefs[levelKey]:
                confFileName = configFileTypes[confType]['fileName']

                if os.path.exists(confFileName):
                    parsingMethodName = configFileTypes[confType]['parsingMethod']
                    found = True
                    break
            if found:
                break

        if not found:
            logging.error("Unable to find any configuration file I know to get the distribution of the os")
            return None, None, None
        else:
            parsingMethod = parsingRules['parsingMethod'][parsingMethodName]
            osNameMap = parsingRules['osNameMap']
            osTypeMap = parsingRules['osTypeMap']
            distro, version = parseDistroFile(confFileName, parsingMethod, osNameMap)

            if distro is None or version is None:
                return None, None, None

            return getOsType(distro, version, osTypeMap), distro, version


def readParsingMethodFile(parsingMethodFile):
    '''
    Read configuration file of json format which
    defining the parsing rules for configuration file
    :param parsingMethodFile: The path to the json config file
    :return: a json dictionary storing the mapping of
             config file type and parsing methods
             In an error, return None
    '''

    H = dict(line.strip().split('=') for line in open('/usr/local/bundle-store-url'))
    bundle_store_url = H.get('BUNDLE_STORE_URL')

    try:
        f = open(parsingMethodFile, 'r+b')
        content = f.read()
        content = content.replace("BUNDLE_STORE_URL", bundle_store_url)
        f.write(content)
        f.close()

        return json.loads(content)
    except IOError:
        logging.error('Failed to read json config file %s with exception %s' % (parsingMethodFile, sys.exc_info()[0]))
        return None
    except Exception:
        logging.error('Unexpected error during reading config file %s with exception %s' % (parsingMethodFile, sys.exc_info()[0]))

def disableReqruieTTY():
    cmd = "sed -i 's/Defaults[[:space:]][[:space:]]*requiretty/#Defaults   requiretty/g' /etc/sudoers"
    os.system(cmd)
    cmd = "sed -i 's/Defaults[[:space:]][[:space:]]*!visiblepw/#Defaults   !visiblepw/g' /etc/sudoers"
    os.system(cmd)


def downloadAndSetupCorePkg(downloadUrl, osType, cloud):
    target = downloadFileToFolder(downloadUrl, '/tmp', MAX_RETRY)

    #Extract the package
    os.system('cd /tmp; tar xvf %s' % (target,))


    #Install worker
    while not os.path.exists('/usr/local/osmosix/bin/setup-worker.sh'):
        os.system('bash /tmp/corePkg/installer.sh %s 64 %s worker > /tmp/worker.log 2>&1' % (osType, cloud))
        if os.path.exists('/usr/local/osmosix/bin/setup-worker.sh'):
            logging.info("Worker installed succeeded.")
            break
        else:
            logging.error("Failed to install Worker")
            time.sleep(5)

    #Copy the starter file out before removal
    originStarter = '/tmp/corePkg/worker/starter'
    targetStarter = '/tmp/starter'
    os.system('cp %s %s' % (originStarter, targetStarter))

    #Clean the workspace
    shutil.rmtree('/tmp/corePkg')
    os.remove(target)

    return targetStarter

def installPkg(configJson, distro, pkgs):
    pkgInstallCmd = configJson['packageManageCmd'][distro]['install']
    pkgIndexRefresh = configJson['packageManageCmd'][distro]['refreshIndex']

    if len(pkgs) == 0:
        return

    if not installPkg.refresh:
        if pkgIndexRefresh != '':
            os.system('%s' % pkgIndexRefresh)
        installPkg.refresh = True

    cmd = '%s %s' % (pkgInstallCmd, ' '.join(pkgs))
    os.system(cmd)

installPkg.refresh = False

def which(program):
    '''
    This function checks if the specified program does exists in the current env settings.
    :param program: The command we want to check
    :return: if found, return the full path of the program, return none if not found
    '''

    import os
    def is_exe(fpath):
        return os.path.isfile(fpath) and os.access(fpath, os.X_OK)

    fpath, fname = os.path.split(program)
    if fpath:
        if is_exe(program):
            return program
    else:
        for path in os.environ["PATH"].split(os.pathsep):
            path = path.strip('"')
            exe_file = os.path.join(path, program)
            if is_exe(exe_file):
                return exe_file

    return None

#NOTE: This method was used to install wget and curl which we cannot do for security reasons: CORE-19530
#TODO Delete this method in next release
def checkAndInstallPkgs(configJson, distro, whichProg):
    programs = ['wget', 'curl']
    pkg2Installs = []

    for i in programs:
        if whichProg(i) is None:
            pkg2Installs.append(i)

    installPkg(configJson, distro, pkg2Installs)

def getPkgUrls(configJson):
    packageUrls = configJson['packageUrl']

    return packageUrls['corePkg'], packageUrls['cliqrInstaller']

def tryLock(fileName):
    try:
        fd = os.open(fileName, os.O_CREAT|os.O_EXCL|os.O_RDWR)
        return True, fd
    except OSError:
        return False, None

def releaseLock(fd):
    os.close(fd)

if __name__ == '__main__':
    #The first thing to do is to create a lock file, forbidding the same scripts to run together
    CLIQRINSTALLING = '/usr/local/osmosix/etc/.CLIQRINSTALLING'
    #This agentinstalled to indicate agent already got installed, to skip later c3agent install
    AGENTINSTALLED='/usr/local/osmosix/etc/.AGENTINSTALLED'
    #This dynamic_bootstrap flag is used for worker installer script to keep agent.war
    DYNAMIC_BOOTSTRAP='/root/.DYNAMIC_BOOTSTRAP'
    # This snapshot flag file is used to indicate the agent is running in snapshot mode
    SNAPSHOT_FILE='/usr/local/osmosix/etc/.snapshot'

    if os.path.exists(SNAPSHOT_FILE):
        os.system('/etc/init.d/c3agent start')
        sys.exit(0)

    if os.path.exists(CLIQRINSTALLING):
        sys.exit(0)

    CLOUD_FILE = '/usr/local/osmosix/etc/cloud'

    if os.path.exists(CLOUD_FILE):
        #If the cloud file exists, it means that this is already a cliqr-enabled image,
        #then we only need to delete the lock file and exits
        sys.exit(0)
    else:
        disableReqruieTTY()
        parentDir = os.path.dirname(CLIQRINSTALLING)
        os.system('mkdir -p %s' % parentDir)

        locked, lockFd = tryLock(CLIQRINSTALLING)
        if locked is False:
            sys.exit(0)

    LOGFORMAT = '%(asctime)s - %(filename)s - %(lineno)d - %(levelname)s - %(message)s'
    logging.basicConfig(format=LOGFORMAT, filename=LOG_FILENAME, level=logging.DEBUG)
    logging.info("Begin logging")
    URL_OSCONFIG = sys.argv[2]
    MAX_RETRY = 5

    setupBundleStoreCredential()

    configFile = downloadFileToFolder(URL_OSCONFIG, '/tmp', MAX_RETRY)

    #json module is introduced in python2.6
    #for python2.4, we can only use a third-party package called simplejson
    
    try:
        import json
    except ImportError:
        if not os.path.exists('/tmp/simplejson'):
            f = open(configFile)
            s = f.read()
            f.close()

            pattern = '"simpleJson".*"(.*)"'
            r = re.search(pattern, s)
            url = re.match(pattern, s[r.start() : r.end()]).group(1)

            logging.info('URL to download simplejson: %s' % url)
            logging.info('Replace BUNDLE_STORE_URL token with bundle value')
            H = dict(line.strip().split('=') for line in open('/usr/local/bundle-store-url'))
            bundle_store_url = H.get('BUNDLE_STORE_URL')
            url = url.replace("BUNDLE_STORE_URL", bundle_store_url)
            logging.info('Resolved URL to download simplejson: %s' % url)

            target = downloadFileToFolder(url, '/tmp', MAX_RETRY)
            logging.info("Downloaded file path: %s" % target)
            cmd = 'cd /tmp; tar xvf %s' % target
            logging.info("Command to execute to extract simplejson: %s" % cmd)
            os.system(cmd)
            logging.info("Command executed. Check if the simplejson directory got created...")
            if os.path.isdir("/tmp/simplejson"):
                logging.info("Simplejson was extracted. Import and use it.")
            else:
                logging.error("Simplejson could not be extracted. Abort bootstrapping.")
                sys.exit(0)
            sys.path.append('/tmp')
        import simplejson as json


    parsingRules = readParsingMethodFile(configFile)
    osType, osName, version = getDistroFile(parsingRules)

    if osType is not None:
        logging.info('Suceedeed to get osType %s' % osType)
    else:
        logging.error('Failed to get osType')

    #We need some basic commands for installing the basic packages
    #So we'll check and install them if they do not exist
    #NOTE: Due to security concerns, we cannot install wget or curl: CORE-19530 so disable this call
    #checkAndInstallPkgs(parsingRules, osName, which)
    logging.info("Agent installation assumes either cURL or wget will be available in the Image. They are not installed as part of installation due to security concerns.")

    #Stop iptables
    os.system('/sbin/service iptables stop > /tmp/i.log 2>&1')

    cloud = sys.argv[1].lower()
    url_corepkg, _ = getPkgUrls(parsingRules)

    AGENT_LITE_MODE = sys.argv[3]
    logging.info("Agent lite mode? : %s" % AGENT_LITE_MODE)
    #Create flag file to indicate dynamic bootstrap, so setup corepkg will keep agent.war
    if AGENT_LITE_MODE == 'false' : open(DYNAMIC_BOOTSTRAP,'a').close()

    logging.info("Cloud Family: %s" % cloud)
    starterPath = downloadAndSetupCorePkg(url_corepkg, osType, cloud)

    #Create flag file to indicate agent already installed
    open(AGENTINSTALLED,'a').close()

    logging.info("Start c3agent for node metadata service")
    os.system('/etc/init.d/c3agent start')

    #Not needed as we will skip the service script installation
    #Avoid system run the service script at the same time
    #time.sleep(10)

    logging.info('Finished calling the bash script to start the agent. Please check the agent log for the status.')

    #Clean the files
    os.remove(configFile)

    releaseLock(lockFd)


