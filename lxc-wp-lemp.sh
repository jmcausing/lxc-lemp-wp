#!/bin/bash
clear
echo "#### LXC + LEMP + WordPress by generator by John Mark C."
echo "#"


# Cloudflare add DNS for this LXC
# Cloudflare zone is the zone which holds the record
zone=causingdesigns.net

## Cloudflare authentication details
## keep these private
cloudflare_auth_email=xxxx@xxx.com
cloudflare_auth_key=xxxxxxx





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

   # haproxy.cfg file check
   FILE=haproxy.cfg
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

   #  - START - Cloudflare subdomain clean up
   #
   if [[ $(lxc list | awk '!/NAME/{print $2}') ]]; 

   then
      echo "# Cloudflare DNS subdomain clean up"+


      lxc_list=$(lxc list | awk '!/NAME/{print $2}' | awk NF)
 
      # Setting up array for list of LXC
      lxc_list_array=($lxc_list)

      # Marking lxc not for deletion
      dont_delete=haproxy

      # Start loop
      for item in "${lxc_list_array[@]}"; do

         if [[ $dont_delete == "$item" ]]; 
         then 
            echo "# $item is found! Not for CF Deletion.."
         else

            # Start -- Deleting subdomain block 
            echo "# Deleting Cloudflare subdomain $item... "


            # Get the zone id for the requested zone
            zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
            -H "X-Auth-Email: $cloudflare_auth_email" \
            -H "X-Auth-Key: $cloudflare_auth_key" \
            -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

            echo "# Zoneid for $zone is $zoneid"
            echo "#"
            dnsrecord=$item

            # Get the DNS record ID
            dnsrecordid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records?type=A&name=$dnsrecord.${zone}" \
               -H "X-Auth-Email: $cloudflare_auth_email" \
               -H "X-Auth-Key: $cloudflare_auth_key" \
               -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

            echo "# DNS record ID for $dnsrecord is $dnsrecordid" 

            # Delete DNS records
            echo "# Deleting $dnsrecord dns record.."
            echo "#"
            result=$(
            curl -s -X DELETE "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/$dnsrecordid" \
               -H "X-Auth-Email: $cloudflare_auth_email" \
               -H "X-Auth-Key: $cloudflare_auth_key" \
               -H "Content-Type: application/json" \
            )
            # echo $result
            if [[ "$result" == *"method_not_allowed"* ]]
            then
               echo "# Failed. Result: $result"
               echo "#"
               echo "# Make sure you entered the correct domain like domain.com or subdomain like hello.domain.com"
               echo "# Or make sure it exist!"
               else 
               echo "# Success!"
               echo "#"
               echo "# Result: $result"
            fi
            # END -- Deleting subdomain block 
         fi
      done
      # End loop

else
   echo "# Already clean!"
fi   
   #
   # - END -   Cloudflare subdomain clean up



   #  - START - Clean up LXC containers
   #
if [[ $(lxc list | awk '!/NAME/{print $2}') ]]; 
then
   echo "# LXC Containers found! Deleting.."+
   if [[  $(lxc list | awk '!/NAME/{print $2}') == *"haproxy"* ]]; then
   echo "# There's a proxy container.."
   fi
   lxc_list=$(lxc list | awk '!/NAME/{print $2}' | awk NF)

   # Setting up array for list of LXC
   lxc_list_array=($lxc_list)
   # Marking lxc not for deletion
   dont_delete=haproxy
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

   # Cleaning HAProxy Config
   echo "# Cleaning  HAProxy config"
   wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/haproxy.cfg
   lxc exec haproxy -- sh -c "rm /etc/haproxy/haproxy.cfg"
   lxc file push haproxy.cfg haproxy/etc/haproxy/haproxy.cfg --verbose
   echo "# Testing HAProxy config"
   lxc exec haproxy -- sh -c "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c" --verbose
   lxc exec haproxy -- sh -c "sudo systemctl reload haproxy"   --verbose
   rm haproxy.cfg
   echo "# Done! HAProxy is now clean!!" 
   echo "#"

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


echo "#"
echo "# Testing Cloudflare connection.."
# Get the zone id for the requested zone
zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
-H "X-Auth-Email: $cloudflare_auth_email" \
-H "X-Auth-Key: $cloudflare_auth_key" \
-H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "# Zoneid for $zone is $zoneid"
echo "#"


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
        echo "#"
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
   

# Check if Ansible app exist. If not, then install.
if ! command -v ansible &> /dev/null
then
    echo "# Ansible is not yet installed"
    echo "# Installing Ansible.."
    sudo apt -y update -q
    sudo apt -y install ansible -q
    
else
    echo "# Ansible is here.."
fi



#  - START - HAPRoxy check
##    
##    
if [[ $(lxc list | grep haproxy) ]]; 
then
     echo "# HAProxy is found!"
else
     echo "# HAProxy is not here. Installing HAProxy"
     lxc launch ubuntu:18.04 haproxy
     echo "#"
     echo "# Trying to get the HAProxy IP Address.."
     HAProxy_LXC_IP=$(lxc list | grep haproxy | awk '{print $6}')
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
     # Getting the IP of LXC
     while ! [[ "${HAProxy_LXC_IP}" =~ ${VALID_IP} ]]; do
         HAProxy_LXC_IP=$(lxc list | grep haproxy | awk '{print $6}')
         spin
     done
     endspin
     echo "# "
     echo "# IP Address found! HAProxy LXC IP: ${HAProxy_LXC_IP}"
     
     echo "# "
     echo "# Updating HAProxy container"
     echo "# "
     lxc exec haproxy -- sh -c "apt update" --verbose
     echo "# "
     echo "# Downloading HAProxy (apt install haproxy))"
     lxc exec haproxy -- sh -c "apt -y install haproxy" --verbose
     echo "# "
     echo "# Download and transfer HAProxy config file"    
     wget -q https://raw.githubusercontent.com/jmcausing/lxc-lemp-wp/master/haproxy.cfg
     lxc exec haproxy -- sh -c "rm /etc/haproxy/haproxy.cfg"
     lxc file push haproxy.cfg haproxy/etc/haproxy/haproxy.cfg --verbose
     echo "# "
     echo "# Testing and reloading HAProxy config"
     lxc exec haproxy -- sh -c "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c" --verbose
     lxc exec haproxy -- sh -c "sudo systemctl reload haproxy"   --verbose
     rm haproxy.cfg     
     haproxyip=$(lxc exec jm1 -- sh -c "ip -4 addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}'")
     echo "# "
     echo "# HAProxy is now installed!"
     # Flushing IP Tables
     echo "# Flushing iptables rules..."
     sleep 1
     sudo iptables -F
     sudo iptables -X
     sudo iptables -t nat -F
     sudo iptables -t nat -X
     sudo iptables -t mangle -F
     sudo iptables -t mangle -X
     sudo iptables -P INPUT ACCEPT
     sudo iptables -P FORWARD ACCEPT
     sudo iptables -P OUTPUT ACCEPT
     # Adding IP tables for HAProxy 
     echo "#"
     echo "# Inserting new IP tables for HAProxy"
     sudo iptables -t nat -I PREROUTING -i ens4 -p TCP --dport 80 -j DNAT --to-destination ${HAProxy_LXC_IP}:80
     # Reload and save IP Tables
     echo "#"
     echo "# Save IP tables"
     echo "#"
     sudo /sbin/iptables-save
fi
##    
## 
#  - END - HAPRoxy check




# 18.04
lxc launch ubuntu:18.04 $lxcname

# 16.04
#lxc launch ubuntu:16.04 $lxcname

# Initial Cloudflare Setup
echo "#"
echo "# This is still designed for subdomain. Hardcoded in haproxy.cfg acl host_\${lxcname} hdr(host) -i \${cfdomain}.causingdesigns.net"
echo "#"
echo "# Let's setup your Cloudflare domain to add the dns.."

cfdomain=$lxcname

# Get the current external IP address
ip=$(curl -s -X GET https://checkip.amazonaws.com)

echo "# Current IP is $ip"


if host $cfdomain 1.1.1.1 | grep "has address" | grep "$ip"; then
  echo "# $cfdomain is currently set to $ip; no changes needed"
 # exit
fi



# Get the zone id for the requested zone
zoneid=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones?name=$zone&status=active" \
  -H "X-Auth-Email: $cloudflare_auth_email" \
  -H "X-Auth-Key: $cloudflare_auth_key" \
  -H "Content-Type: application/json" | jq -r '{"result"}[] | .[0] | .id')

echo "# Zoneid for $zone is $zoneid"
echo "#"


# Create DNS records
  result=$(
  curl -s -X POST "https://api.cloudflare.com/client/v4/zones/$zoneid/dns_records/" \
    -H "X-Auth-Email: $cloudflare_auth_email" \
    -H "X-Auth-Key: $cloudflare_auth_key" \
    -H "Content-Type: application/json" \
    --data "{\"type\":\"A\",\"name\":\"$cfdomain\",\"content\":\"$ip\",\"ttl\":1,\"proxied\":false}"
  )
  # echo $result
  if [[ "$result" == *"success\":false"* ]]
    then
     echo "# Failed. "
     echo "#":
     echo "# Result: $result"
     echo "#"
    else 
      echo "# Success!!"
      echo "#"
      echo "# Result: $result"
      echo "#"
  fi

echo "#"
echo "#"
echo "# Cloudflare DNS setup i done! Your subdomain is $cfdomain.causingdesigns.net"
echo "# Visit your WordPress site after this install using this link: http://$cfdomain.causingdesigns.net"


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
    echo "# Downloading a fresh nginx default config file"
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

echo "#"
echo "# Running playbook with this command:"
echo "#"
echo "# ANSIBLE_HOST_KEY_CHECKING=False ansible-playbook ${lxcname}_lemp.yml -i ${lxcname}_hosts --private-key=${SSHKEY}"
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


# Configure HAProxy for this LXC
#!/bin/bash
echo "#"
echo "# Let's configure HAPRoxy for this container so the world can see it!"

lxc exec haproxy -- sh -c "sed -i  '/^    # It matches/a\    acl host_${lxcname} hdr(host) -i ${cfdomain}.causingdesigns.net'  /etc/haproxy/haproxy.cfg" --verbose

lxc exec haproxy -- sh -c "sed -i  '/^    # Redirect the /a\    use_backend ${lxcname}_cluster if host_${lxcname}'  /etc/haproxy/haproxy.cfg" --verbose

lxc exec haproxy -- sh -c "sed -i -e '\$abackend ${lxcname}_cluster\n    balance leastconn\n    http-request set-header X-Client-IP %[src]\n    server ${lxcname} ${lxcname}.lxd:80 check \n' /etc/haproxy/haproxy.cfg"

lxc exec haproxy -- sh -c "/usr/sbin/haproxy -f /etc/haproxy/haproxy.cfg -c"

lxc exec haproxy -- sh -c "sudo systemctl reload haproxy"

lxc exec haproxy cat /etc/haproxy/haproxy.cfg | grep ${lxcname}_

echo "#"
echo "#"
echo "# Visit your WordPress site using this link: http://$cfdomain.causingdesigns.net"
echo "# Thank you for using LXC LEMP + WordPress setup!"
