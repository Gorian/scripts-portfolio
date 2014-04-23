#!/usr/bin/bash
#
# GSL Solaris Jumpstart Script
#
# Layne Breitkreutz
# <Department Redacted>
# <Company Redacted>

# variables
fileName='GSL Solaris Jumpstart Script'
fileVersion='1.0.5'
# if this binary is not available, script won't run, necessary to avoid error or un-expected behaviour.
#requiredBIN='installadm'
# configs for all available images will be in this directory, so we can use it to get a list of all images available
imagesDir='/export/install'

# jumpstart specific files
ethersFile='/etc/ethers'
ethersTemp='/var/tmp/ethers.tmp'
bootparamsFile='/etc/bootparams'
bootparamsTemp='/var/tmp/bootparams.tmp'

# arrays. We'll use these to define what servers meet what architectures to attempt to guess the correct one.
array_validArchs=(sun4v sun4u sun4us) # exclude x86 as we aren't yet supporting it
array_sun4v=(t1000 t2000 t5120 t3)
array_sun4u=(v210 v215 v220 v240 v245 v440)
array_sun4us=()
array_x86=(v20z v40z x4200)

#functions
display_help () {
    case "$1" in
        "add-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} add-client <FQDN> <mac address> <image>

EOF
            ;;
        "remove-client")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} remove-client (<hostname>|<FQDN>)

EOF
            ;;
        "list")
            cat <<-EOF
${fileName}
Version ${fileVersion}

Usage: ${0##*/} list-[clients|images]

Commands:
${tab_1}list-clients    - list all configured clients
${tab_1}list-images     - list all available images

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
${tab_1}list-clients     - list configured clients
${tab_1}list-images      - list available images
${tab_1}help             - display this message

EOF
            ;;
    esac
}

sunArchTest () {
    local hostname=$1;
    local arch="unknown";
    for i in ${array_sun4v[*]}{;do
        if [[ "${hostname}" =~ "^[a-z]{3,4}${i}.*$" ]]; then
            arch="sun4v";
        fi
    done
    for i in ${array_sun4u[*]};do
        if [[ "${hostname}" =~ "^[a-z]{3,4}${i}.*$" ]]; then
            arch="sun4u";
        fi
    done
    for i in ${array_sun4us[*]};do
        if [[ "${hostname}" =~ "^[a-z]{3,4}${i}.*$" ]]; then
            arch="sun4us";
        fi
    done
    if [ "${architecture}" == "unknown" ]; then
        # call function to request manual architecture input
        arch=$(requestSunArch 0);
    fi
    echo "$arch";
}

requestSunArch () {
    local invalid=$1
    local arch=
    if [ $invalid == "0" ]; then
        read -p "Please enter a valid Sun architecture: " arch;
    else
        echo "Sun architecture not valid."
        read -p "Please enter a valid Sun architecture: " arch;
    fi
    if [[ "$(validateSunArch $arch)" != "0" ]]; then
        ip=$(requestSunArch 1);
    fi
    echo "$arch";
}

validateSunArch () {
    local arch=$1
    local stat=1
    for i in ${array_validArchs[*]};do
        if [[ "${arch}" = "$i" ]]; then
            stat=0;
        fi
    done
    echo "$stat";
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

IPLookup () {
    local HostName="$1";
    local IP=
    local request="$2";
    if [ "$(nslookup ${HostName} | grep "** server can\'t find ${HostName}" > /dev/null 2>&1;echo $?)" != "0" ]; then
       IP=$(nslookup ${HostName} | grep -i 'address' | tail -1 | awk '{print $2}');
    else
        if [ "$request" != "0" ];then
            IP=$(requestIP 0);
        fi
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

getLab () {
    local hostname=$1;
    local lab='';
    local prefix="${hostname:0:4}";
    if [ "$prefix" == "sprn" ];then
        lab="nile";
    elif [ "$prefix" == "sprs" ]; then
        lab="sequoia";
    fi
    echo "$lab";
}

getServerIP () {
    # please note, this is currently only applicable to the GSL Springfield Jumpstart server
    local lab=$1;
    local SHORTNAME=$(hostname | awk '{FS="."; print $1}');
    local IP=;
    local PRIMARY_INTERFACE=$(netstat -r | grep -i $SHORTNAME | awk '{print $6}' | uniq | grep -v '^$' | head -n 1)
    if [ "$lab" == "nile" ]; then
        IP=$(IPLookup sprn-syml-jumpstart.spr.spt.<company>.com 0);
    elif [ "$lab" == "sequoia" ]; then
        IP=$(IPLookup sprjumpstart.spr.spt.<company>.com 0);
    else
        IP=$(ifconfig $PRIMARY_INTERFACE | grep inet | awk '{print $2}');
    fi
    echo "$IP";
}

add-client () {
    # if empty; display help for command
    if [ -z $2 ]; then
        display_help add-client;
    else
    local IMAGE="$3";
    # Santize inputted hostname to be lowercase
    local HostName=$(echo "$1" | tr '[:upper:]' '[:lower:]');
    # Sanitize the MAC Address
    local MAC=$(echo "$2" | sed 's/^0:/00:/g' | sed 's/:0:/:00:/g' | sed 's/:\(.\):/:0\1:/g' | tr '[:lower:]' '[:upper:]');
    # IP is sanitized in validateIP function
    local HostIP=$(IPLookup $HostName);
    # Gateway is sanitized in getGateWay function
    local GateWay=$(getGateWay $HostName);
    # subnet is sanitized in validateIP function
    local subnet=$(getSubnet $GateWay);
    # cut off the FQDN from the hostname before using it here
    HostName=$(echo "$HostName" |  awk -F"." '{print $1}');
    # get the appropriate lab (for springfield site) or leave blank
    # in order to leave blank if needed, we'll prepend the "." in the variable name
    local lab=$(getLab $HostName);
    # get ip of the imaging server (spr jumpstart is multi-homed)
    local serverIP=$(getServerIP $lab);
    # Here, we guess the architecture by comparing the hostname, which by GSL Standards,
    # contains the server type, against an array of known servers for an arch type
    local arch=$(sunArchTest $HostName);
    # before we run this command, add the "." to our lab variable, if not null
    if [ -n "${lab}" ]; then
        lab=".$lab";
    fi
    /export/install/${IMAGE}/Solaris_*/Tools/add_install_client -c ${serverIP}:/export/config -p ${serverIP}:/export/config/${IMAGE}${lab} -e ${MAC} ${HostName} ${arch};
    if [ "$?" = "0" ]; then
        echo "host record added to database";
    fi
fi
}

remove-client() {
# if empty; display help for command
    if [ -z $1 ]; then
        display_help remove-client;
    else
        local hostName=$(clientList | grep -i "$1" | awk '{print $1}' | head -n 1);
        if [[ -z "$hostName" ]] && [[ "$3" != "silent" ]];then 
            echo "client not found in records. Exiting";
            exit 1;
        fi
        local IP=;
        if [ -z $2 ]; then
            IP=$(IPLookup ${hostName});
        else
            IP=$2;
        fi
        # backup our ethers file before we edit it
        cp ${ethersFile} ${ethersTemp};
        local editLine1=$(cat ${ethersTemp} | grep "${hostName}");
        if [ -n "${editLine1}" ]; then
            cat ${ethersTemp} | grep -v "${editLine1}" > ${ethersFile};
        fi
        # backup our bootparams file before we edit it
        cp ${bootparamsFile} ${bootparamsTemp};
        local editLine2=$(cat ${bootparamsTemp} | grep "${hostName}");
        if [ -n "${editLine2}" ]; then
            cat ${bootparamsTemp} | grep -v "${editLine2}" > ${bootparamsFile};
        fi
        # run the remove file generated by add_install_client
        local rmFile="/tftpboot/rm.${IP}";
        if [ -e ${rmFile} ];then
            bash ${rmFile} >/dev/null 2>&1;
            rm -rf ${rmFile} >/dev/null 2>&1;
        else
            echo "could not find ${rmFile}.";
        fi
        if [ "$3" != "silent" ]; then
            echo "Client record successfully removed";
        fi
    fi
}

clientList () {
    if [ -z $1 ]; then
        local list=$(comm -12 <(cat ${ethersFile} | awk '{print $2}' | awk -F"." '{print $1}' | grep -v 'jumpstart' | sort | uniq) <(cat ${bootparamsFile} | awk '{print $1}' | awk -F"." '{print $1}' | sort | uniq));
        echo;
        echo -e "Client\nMAC Address\nImage\n--------------\n-----------------\n----------------" | pr -t -3a -;
        for i in ${list}; do
            echo $i;
            cat ${ethersFile} | grep "$i" | awk '{print $1}';
            cat ${bootparamsFile} | grep "$i" | awk '{print $3}' | sed 's|install=.*/||g';
        done | pr -t -3a -;
        echo;
    else
        echo;
        echo -e "Client\nMAC Address\nImage\n--------------\n-----------------\n----------------" | pr -t -3a -;
        clientList | grep -i "$1";
        echo;
    fi
}

imageList () {
    echo
    echo -e "available images:"
    ls ${imagesDir} | grep 'Sol*' | grep -v '\..*$' | pr -t -2a -
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
    "list")
        # Legacy Support
        list_
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
