#!/bin/bash

bundle_url=$1

root_dir="$( cd "$( dirname $0 )" && pwd )"
cd ${root_dir}

##FUNCTION################################################################
#  Check for exit status and print error msg
##########################################################################
check_error() 
{
        status=$1
        msg=$2
        exit_status=$3

        if [[ ${status} -ne 0 ]]; then
                echo -e "\033[31m       - ${msg} \033[0m"   
                exit ${exit_status}
        fi

        return 0
}

##FUNCTION################################################################
#  Display info to the user
##########################################################################
display_output() 
{
        status=$1
        msg=$2
        exit_status=$3

        if [[ ${status} == "info" ]]; then
                echo -e "\033[32m       - ${msg} \033[0m"   
	elif [[ ${status} == "steps" ]]; then
                echo -e "\033[36m       - ${msg} \033[0m"   
	elif [[ ${status} == "warn" ]]; then
                echo -e "\033[33m       - ${msg} \033[0m"   
	elif [[ ${status} == "error" ]]; then
                echo -e "\033[31m       - ${msg} \033[0m"   
        fi

 	if [[ ${exit_status} -ne 0 ]]; then
		exit ${exit_status}
	fi	

        return 0
}
  

##FUNCTION################################################################
#  Display command usage
##########################################################################
display_usage() 
{
  echo " "  
  echo "Usage: set_bundle_location.sh <bundle_url>"
  echo "       ex: ./set_bundle_location.sh http://example.com/bundle "
  echo " "  
  exit 0
}


##FUNCTION################################################################
#  Change current url to the new url provided
##########################################################################
change_url() 
{
  old_url="$1"
  new_url="$2"
  file_name="$3"

  echo ${old_url} | grep '/user-data' >> /dev/null 2>&1
  if [[ $? -eq 0 ]]; then
    return 0
  fi
  
  
  file_in_url=$(echo ${old_url} | sed "s#^.*/\(.*\)#\1#" )

  if [[ -z $file_in_url ]]; then
    rep_url=${new_url}
  elif [[ -d $file_in_url ]]; then
    rep_url=$(echo ${old_url} | sed "s#^.*/\(.*\)#$new_url\1#" )
  elif [[ -f $file_in_url ]]; then
    rep_url=$(echo ${old_url} | sed "s#^.*/\(.*\)#$new_url\1#" )
  else
    display_output "warn" "${file_in_url}  not present in current bundle directory. Could be due to missing trailing slash in URL " 0 
    rep_url=${new_url}
  fi
  sed -i "s#$old_url#$rep_url#" ${file_name}
  display_output "steps" "Changing $each_url => $rep_url" 0
 
}

if [[ $# -lt 1 ]]; then
  display_usage	
fi

echo ${bundle_url} | grep  'https\?://' >> /dev/null 2>&1
if [[ $? -ne 0 ]]; then
  display_output "error" "Provide http or https as protocol argument" 0
  display_usage	
fi

# Add a traling quote always to user URL
bundle_url=$(echo ${bundle_url} | sed 's#/\?$#/#' )


file_list="bootstrap-cliqr-init.cmd bootstrap-cliqr-init.ps1 bootstrap-cliqr-worker.ps1 bootstrap-cliqr-worker.sh bootstrap.json bootstrap-cliqr-init.sh bootstrap-cliqr-init-softlayer.sh bootstrap-cliqr-dfs.sh"

for each_file in ${file_list}; do

  if [[ -f ${each_file} ]]; then
    http_urls=$(grep 'https\?://'  ${each_file} | sed "s/.*\(http[s]\?:\/\/.*\)/\1/" | sed "s/[\"\'].*//" )
    display_output "info" "File: ${each_file}" 0 	
    for each_url in ${http_urls}; do 
      change_url $each_url $bundle_url $each_file 	
    done	
  else
    display_output "warn" "File ${each_file} not present" 0
  fi

done

exit 0
