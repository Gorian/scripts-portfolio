#!/usr/bin/bash
################################################################################
# ZFS root install script
# "Gorian"
#
################################################################################

#######################################
## CONSTANTS
declare -r VERSION="0.0.2";
declare -r __NAME__="ZFS_Install";

declare -A COLORS;
COLORS["RED"]=$(tput setaf 1);
COLORS["GREEN"]=$(tput setaf 2);
COLORS["YELLOW"]=$(tput setaf 3);
COLORS["BLUE"]=$(tput setaf 4);
COLORS["PURPLE"]=$(tput setaf 5);
COLORS["CYAN"]=$(tput setaf 6);
COLORS["NORMAL"]=$(tput sgr0);
declare -r COLORS

declare -A BACKGROUNDS;
BACKGROUNDS["RED"]=$(tput setab 1);
BACKGROUNDS["GREEN"]=$(tput setab 2);
BACKGROUNDS["YELLOW"]=$(tput setab 3);
BACKGROUNDS["BLUE"]=$(tput setab 4);
BACKGROUNDS["PURPLE"]=$(tput setab 5);
BACKGROUNDS["CYAN"]=$(tput setab 6);
BACKGROUNDS["NORMAL"]=$(tput sgr0);
declare -r BACKGROUNDS;

declare -A MSG_STATUS;
MSG_STATUS["OKAY"]="[ OKAY ]";
MSG_STATUS["FAIL"]="[ FAIL ]";
MSG_STATUS["WARN"]="[ WARN ]";
declare -r MSG_STATUS;

declare -A DEFAULT;
DEFAULT["APT_SERVER"]="http://archive.ubuntu.com/ubuntu";
DEFAULT["COLUMNS"]=80;
DEFAULT["TAB"]="    ";
declare -r DEFAULT;

FULL_LINE="$(head -c "${DEFAULT["COLUMNS"]}" < /dev/zero | tr '\0' '#')";
declare -r FULL_LINE;

## END CONSTANTS
#######################################

display_status() {
    local command_exit_value="$1";
    local error_message="$2"
    local line="$3";

    if [[ ${command_exit_value} = "0" ]]; then
        printf '%s%*s%s\n' "${COLORS[GREEN]}" "$(( DEFAULT["COLUMNS"] - ${#line} ))" "${MSG_STATUS[OKAY]}" "${COLORS[NORMAL]}";
    else
        printf "%s%*s%s\\n" "${COLORS[RED]}" "$(( DEFAULT["COLUMNS"] - ${#line} ))" "${MSG_STATUS[FAIL]}" "${COLORS[NORMAL]}";
        printf "\\n%s\\n\\n" "${error_message}";
        exit 2;
    fi
}

ctrl_c() {
    local zpool_name="$1";
    local line;
    local fatal_message;
    local zfs_installed;
    line="Catch SIG-INT..."
    fatal_message="ERROR: Failed to catch SIG-INT.\\n\
        ... you should never see this error...";
    printf "\\b\\b%s" "${line}";
    display_status "0" "${fatal_message}" "${line}";

    line="${DEFAULT["TAB"]}Clearing mounts...";
    fatal_message="ERROR: Failed to clear mounts";
    printf "\\n%s" "${line}"
    mount | grep -v zfs | tac | awk '/\/mnt/ {print $3}' | xargs -i{} umount -lf {};
    display_status "$?" "${fatal_message}" "${line}";

    printf "\\nCleaning up...";
    line="Removing zpool..."
    if [[ $(command -V zfs >&3 2>&1) ]]; then
        zfs_installed=1;
    else 
        zfs_installed=0;
    fi

    if [[ "${zfs_installed}" == "1" ]]; then
        if [[ "$(zpool status "${zpool_name}")" ]]; then
            fatal_message="ERROR: Failed to remove zpool";
            line="${DEFAULT["TAB"]}Destroying zpool: ${zpool_name}...";
            printf "\\n%s" "${line}";
            zpool destroy "${zpool_name}";
            display_status "$?" "${fatal_message}" "${line}";
        fi
    fi
    printf "Exiting...\\n";
    exit;
}

#######################################
# Prints message and exits
# Globals:
#     NONE
# Arguments:
#     msg: Messsage to print before exiting
#     exit_code: exit code to return to OS upon program completion
#     status: should we print to stdout or stderror?
# Returns:
#     Terminates program and returns exit code to OS
#######################################
die() {
    # Message to print
    local msg="$1";
    local exit_code="$2";
    local status="$3";

    if [[ -z ${exit_code} ]]; then
        exit_code="2";
    fi

    # default status to ERROR
    if [[ "${status}" = "1" ]]; then
        exec 3>&1;
    else
        exec 3>&2;
    fi

    printf "%s\\n" "${msg}" >&3;

    # close custom file descriptor
    exec 3>&-;

    exit ${exit_code};
}

#######################################
# Prints help
# Globals:
#     __NAME__
# Arguments:
#     NONE
# Returns:
#     NONE
#######################################
show_help(){
    cat <<__EOF__
$(show_version)

Try to connect to a memcached server at a specified server and port

usage: ${__NAME__} [-H <host>] (-P <port>)

Options:
-h, --help
    Print detailed help screen
-V, --version
    Print version information
-i, --interactive
    Use the interactive mode of setup.
    Ignores all other arguments.
-D, --disks="/dev/sd*"
    space delimated list of disk to add to pool.
-H, --hostname=ADDRESS
    What you want the hostname to be.
-p, --pool-name=STRING
    What you want to name the zfs pool.
    (DEFAULT: hostname minus the FQDN)
-P, --packages
    Any extra packages you want the script to install
-a, --apt-server
    Server to use for apt repository
    (DEFAULT: ${DEFAULT["APT_SERVER"]})
-B, --BIOS=(BIOS|UEFI)
    Are you using legacy BIOS or UEFI?
    (DEFAULT: Uses best guess)
--no-splash
    Supress the script "splash"
-d, --debug
    Display debug info. Also enabled -v
-v, --verbose
    Show verbose output
__EOF__
}

#######################################
# Prints program version
# Globals:
#     __NAME__
#     VERSION
# Arguments:
#     NONE
# Returns:
#     NONE
#######################################
show_version(){
    cat <<__EOF__    
${__NAME__}, version ${VERSION}
__EOF__
}

#######################################
# Prints a sort of program splash
# The code is whitespace with changing
# background colors
#
# Prints "ZFS Root Install
#
# Globals:
#     COLORS
# Arguments:
#     NONE
# Returns:
#     NONE
#######################################
splash(){
    local f;
    local b;
    f="$(tput setaf 0) $(tput sgr0)";
    b="$(tput setab 7) $(tput sgr0)";
    local string="ZFS Root Install";
    if (( "$(tput cols)" > 114 )); then
        cat <<__EOF__
┌────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f} │
│${f}${b}${b}${b}${b}${b}${b}${b}${b}${f}${f}${b}${b}${b}${b}${b}${b}${b}${b}${f}${f}${f}${b}${b}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${b}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${b}${f}${f}${f}${b}${b}${b}${f}${f}${f}${f}${b}${b}${b}${f}${f}${f}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${f}${f}${f}${f}${b}${b}${b}${f}${f}${f}${b}${b}${b}${b}${f}${f}${f}${b}${b}${b}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${b}${b}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${b}${b}${b}${b}${f}${f}${f}${f}${b}${b}${b}${b}${b}${f}${f}${b}${b}${b}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${b}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${b}${b}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${f}${b}${b}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${b}${b}${b}${b}${b}${b}${b}${b}${f}${f}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${b}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${f}${b}${b}${f}${f}${f}${f}${b}${b}${f}${f}${f}${b}${b}${b}${f}${f}${f}${f}${b}${b}${b}${f}${f}${f}${f}${b}${b}${b}${f}${f}${f}${f}${f}${f}${f}${b}${b}${b}${b}${f}${f}${b}${b}${f}${b}${b}${f}${f}${f}${b}${b}${b}${f}${f}${f}${f}${b}${b}${b}${f}${f}${f}${b}${b}${b}${b}${f}${f}${b}${b}${f}${f}${b}${b}${f} │
│${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f}${f} │
└────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
__EOF__
        printf "%s" "${COLORS["NORMAL"]}";
    elif (( "$(tput cols)" >= 20)); then
        local cols;
        cols="$(tput cols)";
        local end="$(( cols - 2))"

        ## Line 1
        printf "┌";
        for ((i=1; i<="${end}"; i++)); do
            printf "─";
        done
        printf "┐\\n";

        # line 2
        # set spacing to colums minus beginning and end characters
        local spacing="$(( cols -2 ))"
        # set spacing to spacing minus our string
        spacing="$(( spacing - ${#string} ))";
        # split the spacing in two
        spacing="$(( spacing / 2 ))";

        local line2;
        line2="│";
        for ((i=1; i<="${spacing}"; i++)); do
            line2+=" ";
        done
        line2+="${string}";
        for ((i=1; i<="${spacing}"; i++)); do
             line2+=" ";
        done

        if (( (${#line2} + 1) > cols )); then
            line2="${line2::-1}";
        elif (( (${#line2} + 1) < cols )); then
            line2+=" ";
        fi
        line2+="│";
        printf "%s\\n" "${line2}";

        # line 3
        printf "└";
        for ((i=1; i<="${end}"; i++)); do
            printf "─";
        done
        printf "┘\\n\\n";
    else
        printf "%s" "${string}"
    fi

}

#######################################
# Parse a delimated string, and returns a globally parsable array
# Globals:
#     NONE
# Arguments:
#     $1: delimated string
# Returns:
#     newline delimated string
#######################################
parse_to_array() {
    local string="$1";
    local temp_string;
    local return_array;
    return_array=();

    local regex_comma="\\w,\\s*";
    local regex_colon="\\w\\:[^\\/\\/]\\s*";
    local regex_semicolon="\\w\\;\\s*";

    if [[ "${string}" =~ $regex_comma ]]; then
        # remove whitespace
        temp_string="$(printf "%s" "${string}" | tr -d ' ')"
        IFS="," read -ra return_array <<< "${temp_string}";
    elif [[ "${string}" =~ $regex_colon ]]; then
        # remove whitespace
        temp_string="$(printf "%s" "${string}" | tr -d ' ')"
        IFS=":" read -ra return_array <<< "${temp_string}";
    elif [[ "${string}" =~ $regex_semicolon ]]; then
        # remove whitespace
        temp_string="$(printf "%s" "${string}" | tr -d ' ')"
        IFS=";" read -ra return_array <<< "${temp_string}";
    else
        read -ra return_array <<< "${string}";
    fi

    # bash can't return anything in the normal sense
    # this includes variables, strings, integers, arrays, etc
    # so the best methos is to echo a newline delimated string
    # this is "globally" parsable
    # meaning that we don't have to do anything special to get an array from it
    # I.E. array=("$(parse_to_array "${foo}")")
    printf "%s\\n" "${return_array[@]}";
}

toLower() {
    local string="$1";

    printf "%s" "${string,,}"
}

toUpper() {
    local string="$1";

    printf "%s" "${string^^}"
}


#######################################
# Program Entry Point
# Globals:
#     SERVICE_NAME
# Arguments:
#     $@: All arguments from std.in
# Returns:
#     int: exit code to OS as integer
#######################################
main(){
    local argv=("$@");
    # argc is the count of arguments
    local argc=${#argv[@]};

    # this is important to ensure globbing is active
    shopt -s extglob;

    # Handle compressed short options
    re="(^| )\\-[[:alnum:]]{2,}"; # regex to detect shortoptions
    # we evaluate this as a long string, thus ${argv[*]}, instead of ${argv[@]}
    if [[ "${argv[*]}" =~ $re ]]; then
        local compiled_args=();
        for ((i=0; i<argc; i++)); do
            if [[ "${argv[$i]}" =~ $re ]]; then
                local compressed_args="${argv[$i]#*-}";
                for ((r=0; r<${#compressed_args}; r++)); do
                    compiled_args+=("-${compressed_args:$r:1}");
                done
                shift;
                compiled_args+=("$@");
                ## recurse
                main "${compiled_args[@]}";
                ## we "pass" the exit code back up the recursions to the OS
                exit $?;
            fi
            compiled_args+=("${argv[$i]}");
            shift;
        done
        exit;
    fi

    ############################################################################
    ## Define argument variables

    # What you want to name the host
    local arg_hostname;
    # Disks, as delimited string
    local arg_disks;
    # name of the ZFS pool root
    local arg_pool_root;
    # enable debug
    local arg_debug;
    # enable extra output
    local arg_verbose;
    # list of extra packages to install
    local arg_packages;
    # choose a custom apt server
    local arg_apt_server;
    # turn off the "splash"
    local arg_no_splash;
    # BIOS or UEFI?
    local arg_bios;
    ## END Define argument variables
    ############################################################################
    while :; do
        case $1 in
            "-h"|"-\\?"|"--help")
                show_help;    # Display a usage synopsis.
                exit 0;
                ;;
            "-V"|"--version")
                show_version;
                exit 0;
                ;;
            "-H"|"--hostname")
                arg_hostname="$2";
                shift;
                ;;
            --hostname=?*)
                arg_hostname="${1#*=}";
                ;;
            "-D"|"--disks")
                local arg_disks="$2";
                shift;
                ;;
            --disks=?*)
                arg_disks="${1#*=}";
                ;;
            "-p"|"--pool-root")
                arg_pool_root="$2";
                shift;
                ;;
            --pool-root=?*)
                arg_pool_root="${1#*=}";
                ;;
            "-P"|"--packages")
                arg_packages="$2";
                shift;
                ;;
            --packages=?*)
                arg_packages="${1#*=}";
                ;;
            "-a"|"--apt-server")
                arg_apt_server="$2";
                shift;
                ;;
            --apt-server=?*)
                arg_apt_server="${1#*=}";
                ;;
            "-B"|"--BIOS")
                arg_bios="$(toUpper "$2")";
                shift;
                ;;
            --BIOS=?*)
                arg_bios="$(topUpper "${1#*=}")";
                ;;
            "--no-splash")
                # incrementing isn't needed for this variable
                # but this is at least as clean as alternatives
                # so why not. #commentlongerthanitscodeblock
                ((arg_no_splash++));
                ;;
            "-d"|"--debug")
                # if there is a value as the next arg,
                # instead of another argument
                if [[ "$2" =~ ^[^-] ]]; then
                    arg_debug="$2";
                else
                    ((arg_debug++));
                fi
                ;;
            --debug=?*)
                arg_debug="${1#*=}";
                ;;
            "-v"|"--verbose")
                ((arg_verbose++));
                ;;
            --)              # End of all options.
                shift
                break
                ;;
            -?*)
                printf 'WARN: Unknown option (ignored): %s\n' "$1" >&2
                ;;
            *)        # Default case: No more options, so break out of the loop.
                break
        esac
        
        shift
    done

    ############################################################################
    ## Set defaults
    ## Handle arguments
    # if the user doesn't set arg_pool_root, then default to the shortname
    if [[ -z "${arg_pool_root}" ]]; then
        arg_pool_root=$(printf "%s" "${arg_hostname}" | awk -F"." '{print $1}');
    fi

    trap 'ctrl_c ${arg_pool_root}' INT;

    # file descript 3 is for debug
    if [[ -n ${arg_debug} ]]; then
        exec 3>&1;
        # enabling debug also enables verbose
        ((arg_verbose++));
    else
        exec 3>/dev/null;
    fi
    
    if (( arg_debug > 1 )); then
        set -x;
    fi

    # file descriptor 4 is for verbose
    if [[ -n ${arg_verbose} ]]; then
        exec 4>&1;
    else
        exec 4>/dev/null;
    fi

    if [[ -z "${arg_apt_server}" ]]; then
        arg_apt_server="${DEFAULT["APT_SERVER"]}";
    fi
    # this is used to put our setup script
    # inside the chroot environment
    #local chroot_script="/var/tmp/setup.sh";

    # Default Packages
    local install_packages;
    install_packages=(
        "debootstrap"
        "gdisk"
        "zfsutils-linux"
    );

    mapfile -t disks <<< "$(parse_to_array "${arg_disks}")";



    # Add packages from command line
    if [[ -n "${arg_packages}" ]]; then
        local temp_packages;
        mapfile -t temp_packages <<< "$(parse_to_array "${arg_packages}")";
        install_packages+=("${temp_packages[@]}");
    fi

    if [[ -z "${arg_bios}" ]]; then
        if [[ -d "/sys/firmware/efi" ]]; then
            arg_bios="UEFI";
        else
            arg_debug="BIOS";
        fi
    fi

    ## End Section
    ############################################################################

    local line;
    local error_message;
    local regex;

    tput sgr0; # reset all colours
    if [[ -z "${arg_no_splash}" ]]; then
        splash # display the ascii splash
    fi

    
    printf "\\n%s\\n## DEBUG ARGUMENTS ##\\n" "${FULL_LINE}" >&3;

    printf "\\n";
    local set_args;
    #regex="declare -a";
    local sub_array;
    set_args="$( (set -o posix; set) | grep "^arg_" | awk -F"=" '{print $1}')";
    mapfile -t set_args <<< "${set_args}"
    printf "\\nArguments:\\n" >&3;
    for ((i=0; i <= "${#set_args[@]}"; i++)); do
        if [[ -n "${!set_args[${i}]}" ]]; then
            printf "%s- %s:\\n" "${DEFAULT["TAB"]}" "${set_args[${i}]}" >&3;
            sub_array="$(parse_to_array "${!set_args[${i}]}")"
            mapfile -t sub_array <<<"${sub_array}"
            for r in "${sub_array[@]}"; do
                printf "%s%s- %s\\n" "${DEFAULT["TAB"]}" "${DEFAULT["TAB"]}" "${r}" >&3;
            done
        fi
    done

    printf "\\n## END DEBUG ARGUMENTS ##\\n%s\\n\\n" "${FULL_LINE}" >&3;

    ############################################################################
    ## Get Disk IDs
    # /dev/sd* devices are dynamic, they depend on the hardware order of the 
    # devices. If you have an array of /dev/sd* devices, when you move cables 
    # around you break the array. The first thing we do is get the
    # /dev/disk/by-id for the passed disks, and use the IDs for the rest of the 
    # script.
    local disks_by_id=();
    for device in "${disks[@]}"; do
        line="Getting disk ID for ${device}...";
        error_message="ERROR: Failed to get disk id for ${device}";
        local temp_exit_code=0;
        printf "%s" "${line}";
        for id in /dev/disk/by-id/*; do
            temp=$(printf "%s " "${id}"; readlink -f "${id}");
            local disk_temp;
            disk_temp=$(printf "%s\\n" "${temp}" \
                | grep "${device}\$" | awk '{print $1}');
            if [[ -n "${disk_temp}" ]] &&
               [[ ! "$(basename "${disk_temp}")" =~ ^wwn.* ]]; then
                disk_id=$disk_temp;
            else
                unset disk_id;
            fi
        done
        disks_by_id+=("${disk_id}");
        if [[ -z "${disk_id}" ]]; then
            temp_exit_code=1;
        fi
        display_status "${temp_exit_code}" "${error_message}" "${line}";
        printf "%sThe disk ID of  %s is:\\n%s%s%s%s\\n" \
        "${DEFAULT["TAB"]}" "${device}" "${DEFAULT["TAB"]}" \
        "${COLORS["CYAN"]}" "${disk_temp}" "${COLORS["NORMAL"]}">&4;
    done
    ## END Get Disk IDs
    ############################################################################

    ############################################################################
    ## Install Packages

    # don't update unless they specify they want to - it's needlessly long

    # if arg; then 
    # apt update;

    printf "\\n";
    line="Installing required packages...";
    printf "%s" "${line}";

    error_message="FATAL ERROR: installing packages failed. Exiting.";

    line="${DEFAULT["TAB"]}- Ensuring universe repository is enabled...";
    printf "\\n%s" "${line}" \
    | sed "s/universe/${BACKGROUNDS["BLUE"]}universe${COLORS["NORMAL"]}/";
    #apt-add-repository universe > /dev/null 2>&1; # suppresses message if already enabled
    true; # set for debugging so we don't run apt-add-repository
    display_status "$?" "${error_message}" "${line}";

    line="${DEFAULT["TAB"]}- Updating existing packages..."
    printf "%s" "${line}";
    #apt update > /dev/null 2>&1
    true;
    display_status "$?" "${error_message}" "${line}";

    line="${DEFAULT["TAB"]}- Installing Packages...";
    printf "%s" "${line}";
    #apt install --yes debootstrap gdisk zfsutils-linux > /dev/null 2>&1;
    # We loop over to easily display messages and catch errors
    printf "\\n";
    for i in "${install_packages[@]}"; do
        line="$(printf "%s" "${DEFAULT["TAB"]}"{,})- Installing ${i}...";
        error_message="ERROR: Failed to install ${I}";
        printf "%s" "${line}";
        # apt-get install --yes ${i}
        true;
        display_status "$?" "${error_message}" "${line}";
    done
    line="Package Installation..."
    printf "%s" "${line}"
    display_status "0" "" "${line}"

    ## END Install Packages
    ############################################################################


    exit
}

# only run the main script if it's executed directly.
# main() won't run if this script is sourced 
if [[ "${BASH_SOURCE[0]}" = "$0" ]]; then
    main "$@"
fi
