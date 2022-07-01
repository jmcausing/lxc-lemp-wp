#!/bin/bash

webport=8$(( $RANDOM % 10 + 909 ))
sshport=2$(( $RANDOM % 10 + 909 ))
hostip=$(hostname -I | cut -d' ' -f2)
#hostip=$(hostname -I | cut -d' ' -f1)
# 'f2' fix for windows multipass --network

clear
echo "#### LXC + LEMP + WordPress by generator by John Mark C."
echo "#"

   # Checking LXD version.  Version 3 will continue. Version 2 will exit!
   if [[ !$(sudo lxd --version | grep 2.) ]]; 
   then
      echo "# LXD verson is good. $(sudo lxd --version). Let's proceed!"

   else
      echo "Please run LXD version 3 or up to proceed to add proxy device!!"
      echo "#"
      exit
   fi

   #################### 
   # Start - Clean mode
   if [ "$1" == "clean" ]
   then
      # play.yml file check
      FILE=*.yml
      if ls $FILE 1> /dev/null 2>&1; then
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
      echo "# LXC Containers found! Deleting.."+


      lxc_list=$(lxc list | awk '!/NAME/{print $2}' | awk NF)

      # Setting up array for list of LXC
      lxc_list_array=($lxc_list)
      # Marking lxc not for deletion
      # This is was haproxy keyword
      dont_delete=xxxxxxx
      for item in "${lxc_list_array[@]}"; do
         if [[ $dont_delete == "$item" ]]; 
         then 
            echo "# $item is found! This is your proxy container. NEVER DELETE!"
         else
            echo "# Deleting LXC $item... (FORCED)"
            lxc delete $item --force

         fi
      done

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
   # END - Clean mode
   ################## 



   echo "# Hello! Enter the LXC container name please:"
   read -p "# Enter LXC name: " lxcname
   echo "# Alright! Let's generate the LXC container Ubuntu 18.04: $lxcname"
   echo "#"
   echo "#"

   # Read WordPress Password
   echo -n "# Enter your WordPress Password": 
   read -s wppassword

   echo "#"
   read -p "# Enter your WordPress email: " wpemail
   echo "#"
   echo "#"

   echo "# Make sure you run this from your local laptop/machine FIRST"
   echo "# For Mac or Linux"
   echo "# ssh-keygen -f ~/.ssh/$lxcname"
   echo "#"
   echo "# For Windows"
   echo "# ssh-keygen -f %HOMEDRIVE%%HOMEPATH%/.ssh/$lxcname"
   echo "#"   
   echo "# Are you done generating SSH key? Paste the public key here of $lxcname.pub"
   read -p "# Enter PUBLIC KEY $lxcname.pub : " lxcpub


   echo "# Let's update.. (apt install update)"
   echo "#"
   sudo apt -y update -qq
   
   
   echo "# Checking required apps.."

   # Check if jq app exist. If not, then install.
   if ! command -v jq &> /dev/null
   then
      echo "# jq is not yet installed"
      echo "# Installing jq.."
      echo "#"
      sudo apt -y install jq -qq
      
   else
      echo "# jq is here.."
   fi


   # Check if Ansible app exist. If not, then install.
   if ! command -v ansible &> /dev/null
   then
      echo "# Ansible is not yet installed"
      echo "# Installing Ansible.."
      sudo apt -y update -qq
      sudo apt -y install ansible -qq
      
   else
      echo "# Ansible is here.."
   fi


   # Upgrades are needed for Ansible to work
   echo "# Checking for apt update and upgrades.."
   if [[ $(sudo apt list --upgradeable | grep ubuntu) ]];
   then   
      echo "# There's an upgrade available."
      echo "# Updating and upgrading now.. - apt update && apt upgrade"
      sudo apt -y update -qq
      sudo apt -y upgrade -qq
   else
      echo "# No upgrades needed.."
   fi


   # LXD check profile and permission
   if [[ $(lxc profile show default | grep "devices: {}") ]]; 
   then
      if [[ $(groups $(whoami) | grep "lxd") ]];  
      then
         echo "# You are a member of LXD group!"
         echo "# Downloading and applying LXD config.."
         wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/lxdconfig.yaml
         sudo lxd init --preseed < lxdconfig.yaml
         rm lxdconfig.yaml   
      else
         echo "# You are NOT a member of LXD Group.."
         echo "#"
         echo "# Adding this user $(whoami) to LXD group. Please run this script again!" 
         sudo adduser $(whoami) lxd
         newgrp lxd
      fi
   else
      echo "# LXD is already configured. Let's proceed."
   fi
      

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
   sleep 5

   # Send SSH key file from this those to the target LXC
   echo "######## lxc file push $HOME/.ssh/id_lxc_${lxcname}.pub ${lxcname}/root/.ssh/authorized_keys --verbose"
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
   echo "# Adding local machine puiblic key to LXC"
   lxc exec ${lxcname} -- sh -c "echo $lxcpub >> ~/.ssh/authorized_keys" --verbose
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
      wget -q w https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/default
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/default
      echo "#"
   fi

   # vars file check
   FILE=vars.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm vars.yml
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/vars.yml
      echo "#"
      
   else 
      echo "#"
      echo "# $FILE does not exist."
      echo "# Downloading vars.yml for Ansible"
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/vars.yml
      echo "#"
   fi

   # wp-config.php file check
   FILE=ansible_wpconfig.php
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm ansible_wpconfig.php
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/ansible_wpconfig.php
      echo "#"
      
   else 
      echo "#"
      echo "$FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/ansible_wpconfig.php
      echo "#"
   fi

   # Ansible playbook play.yml file check
   FILE=play.yml
   if [ -f "$FILE" ]; then
      echo "#"
      echo "# $FILE exists. Deleting and downloading a fresh one!"
      rm play.yml
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/play.yml
      mv play.yml ${lxcname}_lemp.yml
      echo "#"
      
   else 
      echo "#"
      echo "$FILE does not exist."
      echo "# Downloading a fresh nginx default config file"
      wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/play.yml
      mv play.yml ${lxcname}_lemp.yml
      echo "#"
   fi

   echo "# Checking files.."
   ls -al  ${lxcname}_lemp.yml
   ls -al  ${lxcname}_hosts
   ls -al vars.yml
   echo "#"


   echo "# Updating mysql credentials.."
   sed -i "s/wp_user/${lxcname}/g" vars.yml
   sed -i "s/wp_password/${wppassword}/g" vars.yml


   echo "#"
   echo "# Running playbook with this command:"
   echo "#"
   echo "# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=${SSHKEY}"
   echo "#"

   time ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=~${SSHKEY} 

   echo "#"
   echo "# Add user 'ubuntu' to groups www-data"
   lxc exec ${lxcname} -- sh -c "usermod -a -G www-data ubuntu" --verbose
   lxc exec ${lxcname} -- sh -c "ls -al /var/www/html" --verbose


  # Setup WP CLI
   echo "#"
   echo "# Download and install WP-CLI"
   lxc exec ${lxcname} -- sh -c "curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar" --verbose
   lxc exec ${lxcname} -- sh -c "php wp-cli.phar --info" --verbose
   lxc exec ${lxcname} -- sh -c "chmod +x wp-cli.phar" --verbose
   lxc exec ${lxcname} -- sh -c "sudo mv wp-cli.phar /usr/local/bin/wp" --verbose


   # Install the WordPress database.
   echo "# Installing WP Core -  wp core install"
   echo "#"
   lxc exec ${lxcname} -- sudo --login --user ubuntu sh -c "wp core install --url=http://$hostip:$webport --title=${lxcname} --admin_user=${lxcname}  --admin_password=${wppassword}  --admin_email=${wpemail}   --path=/var/www/html" --verbose


   # Test WP Cli
   echo "# Testing WP CLI. Get WP Core version"
   # echo "# WP-CLI run search and relace to fix mixed-content issue"
   lxc exec ${lxcname} -- sudo --login --user ubuntu sh -c "wp core version --path=/var/www/html" --verbose


   # Seutp phpmyadin
   echo "#"
   echo "# Let's setup phpmyadmin..."
   echo "#"
   echo "# Running: export DEBIAN_FRONTEND=noninteractive;apt-get -yq install phpmyadmin"
   lxc exec  ${lxcname} -- sh -c "export DEBIAN_FRONTEND=noninteractive;apt-get -yq install phpmyadmin > /dev/null" --verbose


   echo "#"
   echo "# Running: dpkg-reconfigure --frontend=noninteractive phpmyadmin"
   lxc exec ${lxcname} -- sh -c "dpkg-reconfigure --frontend=noninteractive phpmyadmin" --verbose 
   echo "#"
   echo "# systemctl restart php7.4-fpm"

   echo "#"
   echo "# ln -s /usr/share/phpmyadmin /var/www/html"
   lxc exec ${lxcname} -- sh -c "ln -s /usr/share/phpmyadmin /var/www/html" --verbose 

   # Fix permission in wp-content/uploads
   lxc exec ${lxcname} sh -c "chmod -R 775 /var/www/html/wp-content/uploads" --verbose
   lxc exec ${lxcname} sh -c "chown -R ubuntu:www-data /var/www/html/wp-content/uploads" --verbose




   # Add proxy device
   lxc config device add ${lxcname} webport$webport proxy listen=tcp:0.0.0.0:$webport connect=tcp:127.0.0.1:80
   lxc config device add ${lxcname} sshport$sshport proxy listen=tcp:0.0.0.0:$sshport connect=tcp:127.0.0.1:22

   echo "#"
   echo "#"
   echo "# Insert nginx config client_max_body_size 100M;"

   lxc exec ${lxcname} -- sh -c "sed -i  '/^http {/a\        client_max_body_size 100M;'  /etc/nginx/nginx.conf"

   echo "#"
   echo "#"
   echo "# Test and reload nginx;"

   lxc exec ${lxcname} -- sh -c "nginx -t;sudo systemctl restart nginx" 

   echo "#"
   echo "#"
   echo "# Connecto to your local site using this http://$hostip:$webport"
   echo "# Connect to this: ssh -i ~/.ssh/${lxcname} -p $sshport root@$hostip"
   echo "#"
   echo "#"
   echo "# WordPress login url: http://$hostip:$webport/wp-admin "
   echo "# WordPerss username: ${lxcname} -- Password: the one you entered earlier" 

   echo "#"
   echo "# Add this also to your ssh config file like if you are using Visual Code Studio for remote SSH"
   echo "Host ${lxcname}"
   echo  "   User root"
   echo  "   Hostname $hostip"
   echo  "   Port $sshport"
   echo  "   PreferredAuthentications publickey"
   echo  "   IdentityFile ~/.ssh/${lxcname}"
   echo "#"
   echo "#"
   echo "# Thank you for using LXC LEMP + WordPress setup!"
