#!/bin/bash

# Function to check if a command is installed
__check_command() {
  command_name=$1
  if ! command -v "$command_name" &>/dev/null; then
    echo "Error: The required command '$command_name' is not installed. Please install it and try again."
    exit 1
  fi
}

# Function to parse host configuration
__parse_host () {
  case $HOSTTYPE in
    remote)
      # IP address is already specified
      ;;
    virsh)
      __check_command "virsh";
      HOST=$HOSTADDRESS;
      # Hostname of vm managed by virsh provided
      if [[ $(virsh list --all) != *"$HOST"* ]]; then
        echo "Specified virtual machine with the name $HOST not found"; exit 1;
      fi;
      # Check if machine is not running
      if [[ $(virsh list --state-running) != *"$HOST"* ]]; then
        echo "Machine currently not running";
        # Wait till machine is ready to start
        SECONDS=0
        until [[ $(virsh list --state-shutoff) != *"$HOST"* ]] || [[ $(virsh list --state-paused) != *"$HOST"* ]]; do
          if (( SECONDS > 60 )); then
            echo "Waited 60 seconds. Exiting...";
            exit 1;
          fi;
          echo "Machine is not shutdown or paused. Waiting on state change...";
          sleep 5;
        done;
        # Start machine
        echo "Starting machine $HOST...";
        notify-send -a "RemoteWin" "Starting Virtual Machine" "Virtual machine '$HOST' was not active";
        virsh start "$HOST" &> /dev/null;
      fi;
      # Get IP address
      IP=$(virsh domifaddr "$HOST" | awk '/ipv4/ {print $4}' | cut -d'/' -f1);
      # Wait until machine is pingable
      SECONDS=0
      until ping -c 1 $IP &> /dev/null; do
        if (( SECONDS > 60 )); then
          echo "Waited 60 seconds. Exiting...";
          exit 1;
        fi;
        echo "Machine is not pingable. Waiting on change...";
        sleep 1;
      done;
      HOSTADDRESS=$IP;
      ;;
    *)
      echo "Error: Host-Address not specified"; exit 1;;
  esac
}

# Function to execute command 'connect'
cmd_connect () {
  echo "CONNECTING...";
  xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /drive:home,$HOME /drive:root,/ /dynamic-resolution;
  #-wallpaper +auto-reconnect +home-drive
}

# Function to execute command 'check'
cmd_check () {
  echo "TESTING CONNECTION...";
  output=$(xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /cert:ignore /auth-only 2>&1);
  exit_status=$(echo "$output" | grep -o 'exit status [^0][0-9]*' | awk '{print $NF}');

  # Check if exit status is found
  if [ -z "$exit_status" ]; then
      echo "RDP Connection was successfully established.";
  else
      echo "RDP Connection could not be established. Exit status: $exit_status"; exit $exit_status;
  fi;
}

# Function to execute command 'launch'
cmd_launch () {
  if [ -z $POSITIONAL_ARGS ]; then
    echo "Error: No launch command specified"; echo ""; print_help_launch; exit 1;
  fi;
  echo "LAUNCHING...";

  modified_args=();
  # Change paths to remote drive for windows
  for arg in "${POSITIONAL_ARGS[@]:1}"; do
    # Check if the argument is a file or directory
    if ([ -f "$arg" ] || [ -d "$arg" ]); then
      if [ "${arg:0:1}" = '/' ]; then
        # absolute path
        arg="$(echo "//tsclient/root${arg}" | sed 's/\//\\/g')";
      else
        # relative path
        arg="$(echo "//tsclient/root${PWD}/${arg}" | sed 's/\//\\/g')";
      fi;
    fi;
    modified_args+=("$arg");
  done;

  xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /drive:home,$HOME /drive:root,/ /app:"${POSITIONAL_ARGS[0]}" /app-cmd:"${modified_args[@]}";
}

# Function to output help information
print_help () {
  cat << EOF
Usage: remotewin [OPTIONS] [COMMAND]

Commands:
  connect  Connect to the host.
  check    Check if connection to RDP-Host can be established.
  launch   Connect to an application on the host.

Options:
  -c, --config <config>      Specifies the path to the config file
  -h, --help                 Print help
  -v, --version              Print version
EOF
}

# Function to output help information for the launch command
print_help_launch () {
  cat << EOF
Usage: remotewin -c [CONFIGURATION] launch [CMD LAUNCH COMMAND]
EOF
}

# Function to output application version
print_version () {
  cat << EOF
RemoteWin Version 0.1.0
EOF
}

# List of required commands
required_commands=("xfreerdp" "awk" "grep" "sed")

# Check all required commands
for cmd in "${required_commands[@]}"; do
  __check_command "$cmd"
done

# Parse CLI arguments
POSITIONAL_ARGS=()
while [[ $# -gt 0 ]]; do
  case $1 in
    connect)
      COMMAND="connect"; shift 1;;
    launch)
      COMMAND="launch"; shift 1;;
    check)
      COMMAND="check"; shift 1;;
    -c|--config)
      if [ -z "$2" ]; then
        echo "Error: Missing argument for $1 option"; exit 1;
      fi
      HOSTTYPE=$(awk '/^type/{print $3}' "$2");
      HOSTADDRESS=$(awk '/^host/{print $3}' "$2");
      USERNAME=$(awk '/^username/{print $3}' "$2");
      PASSWORD=$(awk '/^password/{print $3}' "$2");
      shift 2;;
    -h|--help)
      print_help; exit 1;;
    -v|--version)
      print_version; exit 1;;
    -*|--*)
      echo "Error: Unknown option $1"; exit 1;;
    *)
      POSITIONAL_ARGS+=("$1"); shift 1;;
  esac
done
set -- "${POSITIONAL_ARGS[@]}" # restore positional parameters

# Check if all necessary configuration parameters are set
if [ -z $HOSTTYPE ]; then
  echo "Error: Host-Type not specified"; exit 1;
fi;
if [ -z $HOSTADDRESS ]; then
  echo "Error: Host-Address not specified"; exit 1;
fi;
if [ -z $USERNAME ]; then
  echo "Error: Username not specified"; exit 1;
fi;
if [ -z $PASSWORD ]; then
  echo "Error: Password not specified"; exit 1;
fi;

# Check if a command is specified
if [ -z $COMMAND ]; then
  echo "Error: No command specified"; exit 1;
fi;

# Handle specified command
case $COMMAND in
  connect)
    __parse_host;
    cmd_connect;;
  check)
    __parse_host;
    cmd_check;;
  launch)
    __parse_host;
    cmd_launch;;
esac
