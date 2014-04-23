#!/usr/bin/bash
#
# GSL Automated Install server wrapper script
#
# Layne Breitkreutz
# <Department Redacted>
# <Company Redacted>

# variables
tab_1='    '
fileName='GSL Solaris Automated Install Script'
fileVersion='1.1.0'
GSL_Standard_AI_Service='s11-sparc'
GSL_System_AI_Config_File='/export/auto_install/configs/profiles/GSL.config.system.xml'
# if this binary is not available, script won't run necessary to avoid error or un-expected behaviour.
requiredBIN='installadm'
# configs for all available images will be in this directory, so we can use it to get a list of all images available
imagesDir='/export/aix'

#functions
display_help () {
    case "$1" in
        "add-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} add-client <FQDN> <mac address>

EOF
            ;;
        "remove-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} remove-client (<hostname>|<FQDN>)

EOF
            ;;
        "list-clients")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} list-clients (search terms)
       accepts grep regex (case insensitive)

EOF
            ;;
        "main"|*)
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} [commands]

Commands:
${tab_1}add-client       - add host record for Automated Install
${tab_1}remove-client    - remove host record for Automated Install
${tab_1}list-clients     - list systems
${tab_1}list-images      - list all available images
${tab_1}help             - display this message

EOF
            ;;
    esac
}

validateIP(){
    local  ip=$1
    local  stat=1

    if [[ "$ip" =~ "^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$" ]]; then
        OIFS=$IFS;
        IFS='.';
        ip=($ip);
        IFS=$OIFS;
        #[[ ${ip[0]} -le 255 && ${ip[1]} -le 255 && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    echo "$stat"
}

requestIP () {
    local invalid=$1
    local ip=
    if [ $invalid == "0" ]; then
        read -p "Please enter a valid IP Address: " ip;
    else
        read -p "IP not valid. Please enter a valid IP Address: " ip;
    fi
    if [[ "$(validateIP $ip)" != "0" ]]; then
        ip=$(requestIP 1);
    fi
    echo "$ip";
}

HostIP () {
    local HostName=$1
    local IP=
    if [ "$(nslookup ${HostName} | grep "** server can\'t find ${HostName}" > /dev/null 2>&1;echo $?)" != "0" ]; then
       IP=$(nslookup ${HostName} | grep -i 'address' | tail -1 | awk '{print $2}');
    else
       IP=$(requestIP 0);
    fi
    echo "$IP";
}

getGateWay () {
    local host=$1
    local GW=
    if [ "$(echo ${host} | awk -F"." '{print $1}' | grep '^sprs.*' >/dev/null 2>&1;echo $?)" = "0" ]; then
        GW="10.168.20.1";
    elif [ "$(echo ${host} | awk -F"." '{print $1}' | grep '^sprn.*' >/dev/null 2>&1;echo $?)" = "0" ]; then
        GW="10.122.4.1";
    else
        echo "Could not determine default gateway."
        GW=$(requestIP 0);
    fi
    echo "$GW";
}

getSubnet () {
    local gw=$1
    local subnet=
    # we keep like subnets seperate for flexibility
    if [ $gw == "10.168.20.1" ]; then
        subnet="255.255.252.0";
    elif [ $gw == "10.122.4.1" ]; then
        subnet="255.255.252.0";
    else
        echo "Could not determine subnet mask."
        subnet=$(requestIP 0);
    fi
    echo "$subnet";
}

add-client () {
    # if empty; display help for command
    if [ -z $2 ]; then
        display_help add-client;
    else
    local IMAGE=
    if [ -z $3 ]; then
        IMAGE=${GSL_Standard_AI_Service};
    else
        IMAGE=$3;
    fi
    # Santize inputted hostname to be lowercase
    local HostName=$(echo "$1" | tr '[:upper:]' '[:lower:]');
    # Sanitize the MAC Address
    local MAC=$(echo "$2" | sed 's/^0:/00:/g' | sed 's/:0:/:00:/g' | sed 's/:\(.\):/:0\1:/g' | tr '[:lower:]' '[:upper:]');
    # IP is sanitized in validateIP function
    local HostIP=$(HostIP $HostName);
    # Gateway is sanitized in getGateWay function
    local GateWay=$(getGateWay $HostName);
    # subnet is sanitized in validateIP function
    local subnet=$(getSubnet $GateWay);
    # these variables are needed by the AI service to customized the network for the client install
    export AI_HOSTNAME=$(echo $HostName | awk -F"." '{print $1}');
    export AI_IPV4=$HostIP;
    export AI_NETWORK=$GateWay;
    remove-client ${HostName} silent;
    installadm create-profile -n ${IMAGE} -f ${GSL_System_AI_Config_File}  -p system.${AI_HOSTNAME} -c mac=${MAC} >/dev/null 2>&1;
    installadm create-client -e ${MAC} -n ${IMAGE} >/dev/null 2>&1;
    echo;
    echo "Hostname:   ${AI_HOSTNAME}";
    echo "IP Address: ${AI_IPV4}";
    echo "MAC Addres: ${MAC}"
    echo "Gateway:    ${AI_NETWORK}";
    unset AI_HOSTNAME;
    unset AI_IPV4;
    unset AI_NETWORK;
    echo "host record added to database";
fi
}

remove-client() {
# if empty; display help for command
    if [ -z $1 ]; then
        display_help remove-client;
    else
        local hostName=$(echo "$1" | awk -F"." '{print $1}');
        local SERVICE=$(clientList | grep "${hostName}" | awk '{print $3}');
        installadm delete-profile -n ${SERVICE} -p system.${hostName} >/dev/null 2>&1;
        if [ "$2" != "silent" ]; then 
            echo "host record removed from database";
        fi
    fi
}

clientList () {
    if [ -z $1 ]; then
        echo;
        echo "Client\nMAC Address\nImage\n--------------\n-----------------\n---------" | pr -t -3a -
        for i in `installadm list | awk '{print $1}' | grep -v '^$' | sed '1,3d'`; do
            installadm list -n ${i} -p | grep 'system\..*' | sed 's/system.//g' | sed 's/mac = //g' | sed "s/$/  ${i}/g" | sed 's/  /\^/g' | tr '^' '\n' | pr -t -3a -
        done;
        echo;
    else
        echo;
        echo "Client\nMAC Address\nImage\n--------------\n-----------------\n---------" | pr -t -3a -
        clientList | grep "$1";
        echo;
    fi
}

imageList () {
    echo
    echo -e "available images:"
    ls /export/ai | grep '^s' | pr -t -5a -
    echo
}

list_ () {
    # Legacy
    display_help list;
}

if [ "$(which ${requiredBIN})" = "no ${requiredBIN} in $(echo $PATH | sed 's/:/ /g')" ]; then
    echo;echo "${requiredBIN} not found. Exiting";echo;
    exit 72
fi

# parse arguments ()

    case "$1" in
    "list-clients")
        clientList $2
        exit 0
        ;;
    "list-images")
        imageList
        exit 0
        ;;
    "add-client")
        # passes arguments 2, 3, and 4, where arguments are hostname, mac, and OS Image, respectively
        add-client $2 $3
        echo
        exit 0
        ;;
    "remove-client")
        # passes argument 2, where arguments are hostname to be removed
        remove-client $2
        echo
        exit 0
        ;;
    "help" | "--help" | "-h")
        # catches all default help arguments, and displays help, exiting successfully
        display_help $2
        exit 0
        ;;
    *)
        # catches all non-defined arguments, responds with help, and exits unsuccessfully.
        display_help main
        exit 2
        ;;
esac

#EOF
