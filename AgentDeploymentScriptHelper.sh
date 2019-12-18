#!/bin/bash
## AgentDeploymentScriptHelper.sh <dsm_elb_fqdn> <heartbeat_port> <manager_port> <policy_id>
ACTIVATIONURL="dsm://$1:$2/"
MANAGERURL="https://$1:$3"
CURLOPTIONS='--silent --tlsv1.2'
linuxPlatform='';
isRPM='';

if [[ $(/usr/bin/id -u) -ne 0 ]]; then
    echo You are not running as the root user.  Please try again with root privileges.;
    logger -t You are not running as the root user.  Please try again with root privileges.;
    exit 1;
fi;

if type curl >/dev/null 2>&1; then
  curl $MANAGERURL/software/deploymentscript/platform/linuxdetectscriptv1/ -o /tmp/PlatformDetection $CURLOPTIONS --insecure

  if [ -s /tmp/PlatformDetection ]; then
      . /tmp/PlatformDetection
      platform_detect

      if [[ -z "${linuxPlatform}" ]] || [[ -z "${isRPM}" ]]; then
         echo Unsupported platform is detected
         logger -t Unsupported platform is detected
         false
      else
         echo Downloading agent package...
         if [[ $isRPM == 1 ]]; then package='agent.rpm'
         else package='agent.deb'
         fi
         curl $MANAGERURL/software/agent/$linuxPlatform -o /tmp/$package $CURLOPTIONS --insecure

         echo Installing agent package...
         rc=1
         if [[ $isRPM == 1 && -s /tmp/agent.rpm ]]; then
           rpm -ihv /tmp/agent.rpm
           rc=$?
         elif [[ -s /tmp/agent.deb ]]; then
           dpkg -i /tmp/agent.deb
           rc=$?
         else
           echo Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager
           logger -t Failed to download the agent package. Please make sure the package is imported in the Deep Security Manager
           false
         fi
         if [[ ${rc} == 0 ]]; then
           echo Install the agent package successfully

            sleep 15
            /opt/ds_agent/dsa_control -r
            /opt/ds_agent/dsa_control -a $ACTIVATIONURL "policyid:$4"
            # /opt/ds_agent/dsa_control -a dsm://cloud-one-dsm-elb-1270978254.us-east-1.elb.amazonaws.com:4120/ "policyid:1"
       else
           echo Failed to install the agent package
           logger -t Failed to install the agent package
           false
         fi
      fi
  else
     echo "Failed to download the agent installation support script."
     logger -t Failed to download the Deep Security Agent installation support script
     false
  fi
else 
  echo "Please install CURL before running this script."
  logger -t Please install CURL before running this script
  false
fi

