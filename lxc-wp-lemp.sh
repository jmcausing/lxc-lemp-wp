#!/bin/bash

clear


echo "#### LXC + LEMP + WordPress by generator by John Mark C."
echo "#"
echo "#"

if [ "$1" == "clean" ]
  then


   # play.yml file check
   FILE=play.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting..!"
      rm $FILE 
   else 
      echo "#"
      echo "# $FILE does not exist. Already clean!"
   fi


   # vars file check
   FILE=vars.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting..!"
      rm $FILE 
   else 
      echo "#"
      echo "# $FILE does not exist. Already clean!"
   fi

   # ansible_wpconfig.php file check
   FILE=ansible_wpconfig.php
   if [ -f "$FILE" ]; then
      echo "# $FILE exists. Deleting..!"
      rm $FILE 
   else 
      echo "# $FILE does not exist. Already clean!"
   fi

   
   # host file check
   if ls *host* 1> /dev/null 2>&1; then
      echo "# Hosts file do exist. Deleting!"
      rm *host*
   else
      echo "# Hosts file is already clean!"
   fi

    # playbook retry file check
   if ls *retry* 1> /dev/null 2>&1; then
      echo "# playbook retry file do exist. Deleting!"
      rm *retry*
   else
      echo "# Hosts file is already clean!"
   fi 



   # default nginx file check
   FILE=default
   if [ -f "$FILE" ]; then
      echo "# $FILE nginx config exists. Deleting..!"
      rm $FILE 
      
   else 
      echo "# $FILE nginx config file does not exist. Already clean!"
   fi


   #  - START - Clean up ssh keys with lxc string
   #
   if [[ $(ls $HOME/.ssh/ | grep lxc) ]]; 
   then
      echo "# LXC ssh files found! Deleting.."
      rm $HOME/.ssh/*lxc*
   else
      echo "# No LXC SSH key found. Already clean!"
   fi
   #
   # - END -  Clean up ssh keys with lxc string


   #  - START - Clean up LXC containers
   #
   if [[ $(lxc list | awk '!/NAME/{print $2}') ]]; 
   then
      echo "# LXC Containers found! Deleting.."
      lxc delete $(lxc list | awk '!/NAME/{print $2}' | awk NF) --force
  
   else
      echo "# No LXC Containers found. Already clean!"
   fi   
   #
   # - END -   Clean up LXC containers

    lxc list
    ls -al $HOME/.ssh/
    echo "#"
    echo "# Done!"
    exit 1
fi


echo "# Hello! Enter the LXC container name please:"

read -p "# Enter LXC name: " lxcname


echo "# Alright! Let's generate the LXC container Ubuntu 18.04: $lxcname"
echo "#"
echo "#"


# 18.04
lxc launch ubuntu:18.04 $lxcname

# 16.04
#lxc launch ubuntu:16.04 $lxcname


echo "#"
echo "# Let's generate SSH-KEY gen for this LXC"
echo "#"
ssh-keygen -f $HOME/.ssh/id_lxc_$lxcname -N '' -C 'key for local LXC'

echo "#"
echo "# - START - Details from ssh key gen"

# ls $HOME/.ssh/
# cat $HOME/.ssh/id_lxc_$lxcname.pub


echo "#"
echo "#"
echo "# START - Info of LXC: ${lxcname}"


echo "#"
echo "# Trying to get the LXC IP Address.."


LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')

VALID_IP=^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$


# START - SPINNER 
#
sp="/-\|"
sc=0
spin() {
   printf "\b${sp:sc++:1}"
   ((sc==${#sp})) && sc=0
}
endspin() {
   printf "\r%s\n" "$@"
}
#
# - END SPINNER


while ! [[ "${LXC_IP}" =~ ${VALID_IP} ]]; do
 # sleep 1
 #  echo "LXC ${lxcname} has still no IP "
 #  echo "Checking again.." 
 #  echo "#"
 #  echo "#"
 #  lxc list
    LXC_IP=$(lxc list | grep ${lxcname} | awk '{print $6}')
    spin
 #  echo "IP is: ${LXC_IP}"
done
endspin

echo "# IP Address found!  ${lxcname} LXC IP: ${LXC_IP}"
#lxc info $lxcname
echo "# "

echo "# Checking status of LXC list again.."
lxc list


echo "# Sending public key to target LXC: " ${lxcname}
echo "#"
#echo lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys

#Pause for 2 seconds to make sure we get the IP and push the file.
sleep 4

# Send SSH key file from this those to the target LXC
lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose

echo "#"
echo "# Fixing root permission for authorized_keys file"
echo "#"
lxc exec ${lxcname} -- chmod 600 /root/.ssh/authorized_keys --verbose
lxc exec ${lxcname} -- chown root:root /root/.ssh/authorized_keys --verbose
echo "#"
echo "# Adding SSH-key for this host so we can SSH to the target LXC."
echo "#"
eval $(ssh-agent); 
ssh-add $HOME/.ssh/id_lxc_$lxcname
echo "#"
echo "# Done! Ready to connect?"
echo "#"
echo "# Connect to this: ssh -i ~/.ssh/id_lxc_${lxcname} root@${LXC_IP}"
echo "#"
echo "#"

# ssh key variable location
SSHKEY=~/.ssh/id_lxc_${lxcname}

echo "[lxc]
${LXC_IP} ansible_user=root "> ${lxcname}_hosts

# Downloading ansible files 
# Ansible playbook file check


# nginx default config file
FILE=default
if [ -f "$FILE" ]; then
    echo "#"
    echo "# $FILE exists. Deleting and downloading a fresh one!"
    rm default
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/default
    echo "#"
    
else 
    echo "#"
    echo "$FILE does not exist."
    echo "# Downloading a fresh nginx default config file"
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/default
    echo "#"
fi

# vars file check
FILE=vars.yml
if [ -f "$FILE" ]; then
    echo "#"
    echo "# $FILE exists. Deleting and downloading a fresh one!"
    rm vars.yml
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/vars.yml
    echo "#"
    
else 
    echo "#"
    echo "$FILE does not exist."
    echo "# Downloading a fresh nginx default config file"
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/vars.yml
    echo "#"
fi

# wp-config.php file check
FILE=ansible_wpconfig.php
if [ -f "$FILE" ]; then
    echo "#"
    echo "# $FILE exists. Deleting and downloading a fresh one!"
    rm ansible_wpconfig.php
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/ansible_wpconfig.php
    echo "#"
    
else 
    echo "#"
    echo "$FILE does not exist."
    echo "# Downloading a fresh nginx default config file"
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/ansible_wpconfig.php
    echo "#"
fi

# Ansible playbook play.yml file check
FILE=play.yml
if [ -f "$FILE" ]; then
    echo "#"
    echo "# $FILE exists. Deleting and downloading a fresh one!"
    rm play.yml
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/play.yml
    mv play.yml ${lxcname}_lemp.yml
    echo "#"
    
else 
    echo "#"
    echo "$FILE does not exist."
    echo "# Downloading a fresh nginx default config file"
    wget https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/play.yml
    mv play.yml ${lxcname}_lemp.yml
    echo "#"
fi



echo "# Checking files.."
ls -al  ${lxcname}_lemp.yml
ls -al  ${lxcname}_hosts
ls -al vars.yml
echo "#"

echo "#"
echo "# Running playbook with this command:"
echo "#"
echo "# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=${SSHKEY} -vvv"
echo "#"


time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=~${SSHKEY} 

# Checking LXD version.  Version 3 will continue. Version 2 will exit!
if [[ $(sudo lxd --version | grep 3) ]]; 
then
   echo "# LXD is version $(sudo lxd version). We will proceed adding LXD Proxy device"
   echo "# Adding proxy device for port 8080"
   echo "#"
   lxc config device add ${lxcname} webproxy8080 proxy listen=tcp:0.0.0.0:8080 connect=tcp:localhost:80 --verbose
   echo "#"
   echo "# Try to access the WordPress site using this links:"
   echo "# http://$(ip -o route get to 8.8.8.8 | sed -n 's/.*src \([0-9.]\+\).*/\1/p'):8080"
   echo "# or connect to your external ip using port: 8080 (ex: 192.68.2.1:8080)"
   echo "#"
   echo "#"
   echo "#"
else
   echo "Please run LXD version 3 or up to proceed to add proxy device!!"
   echo "#"
fi
echo "#"
echo "# Thank you for using LXC LEMP + WordPress setup!"
