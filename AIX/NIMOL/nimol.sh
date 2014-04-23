#!/bin/bash
#
# GSL nimol server wrapper script
#
# Layne Breitkreutz
# <Department Redacted>
# <Company Redacted>

# variables
tab_1='    '
fileName='GSL NIMOL Script'
fileVersion='1.0.7'
# if this binary is not available, script won't run necessary to avoid error or un-expected behaviour.
requiredBIN='nimol_install'
# configs for all available images will be in this directory, so we can use it to get a list of all images available
imagesDir='/export/aix'

# functions
display_help () {
    case "$1" in
            "add-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} add-client <Hostname> <mac address> <image>
Example: ${0##*/} add-client sprnp5208c-01 00:09:6b:6b:4b:26 AIX_61_TL1

EOF
            ;;
        "remove-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} remove-client (<hostname>)
Example: ${0##*/} remove-client sprnp5208c-01

EOF
            ;;
        "main"|*)
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} [commands]

Commands:
${tab_1}add-client    - add host record for NIMOL (Network Install Manager On Linux)
${tab_1}remove-client - remove host record for NIMOL
${tab_1}list-clients  - list systems current configured for install
${tab_1}list-images   - list systems current configured for install
${tab_1}help          - display this message

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
        local IMAGE="$3";
        # cut off the FQDN from the hostname before using it here
        HostName=$(echo "$HostName" |  awk -F"." '{print $1}');
        # remove the existing record
        remove-client ${HostName};
        # add new record
        nimol_install -c ${HostName} -p ${HostIP} -m ${MAC} -s ${subnet} -L ${IMAGE};
    fi
}

remove-client() {
# if empty; display help for command
    if [ -z $1 ]; then
        display_help remove-client;
    else
        local HostName=$1
        # match the hostname in the nimol database
        HostName=$(cat /etc/nimol.conf | grep -i "${HostName}" | head -n 1 | awk '{print $2}');
        nimol_install -c $HostName -r;
    fi
}

clientList () {
    if [ -z $1 ]; then
        echo;
        echo -e "Client\nMAC Address\nImage\n-------------\n-----------------\n----------" | pr -t -3a -;
        cat /etc/nimol.conf | grep 'CLIENT' | awk '{print $2 "\n" $3 "\n" $6}' | pr -t -3a -;
        echo;
    else
        echo;
        echo -e "Client\nMAC Address\nImage\n-------------\n-----------------\n----------" | pr -t -3a -;
        clientList | grep -i "$1";
        echo;
    fi
}

imageList () {
    echo;
    echo -e "available images:";
    ls ${imagesDir};
    echo;
}

if [ "$(which ${requiredBIN})" = "which: no ${requiredBIN} in ($PATH)" ]; then
    echo;echo "${requiredBIN} not found. Exiting"
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
        add-client $2 $3 $4
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
        display_help main
        exit 0
        ;;
    *)
        # catches all non-defined arguments, responds with help, and exits unsuccessfully.
        display_help main
        exit 2
        ;;
esac

#EOF
