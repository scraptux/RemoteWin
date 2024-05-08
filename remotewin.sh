#!/bin/bash

cmd_connect () {
  echo "CONNECTING...";
  xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /drive:home,$HOME /drive:root,/ /dynamic-resolution;
  #-wallpaper +auto-reconnect +home-drive
}

cmd_check () {
  echo "TESTING CONNECTION...";
  output=$(xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /cert:ignore /auth-only 2>&1);
  exit_status=$(echo "$output" | grep -o 'exit status [^0][0-9]*' | awk '{print $NF}');

  # Check if exit status is found
  if [ -z "$exit_status" ]; then
      echo "RDP Connection was successfully established."; exit 0;
  else
      echo "RDP Connection could not be established. Exit status: $exit_status"; exit $exit_status;
  fi;
}

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


  echo "${modified_args[@]}";
  xfreerdp /v:"$HOSTADDRESS" /u:"$USERNAME" /p:"$PASSWORD" /drive:home,$HOME /drive:root,/ /app:"${POSITIONAL_ARGS[0]}" /app-cmd:"${modified_args[@]}";
}

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

print_help_launch () {
  cat << EOF
Usage: remotewin -c [CONFIGURATION] launch [CMD LAUNCH COMMAND]
EOF
}

print_version () {
  cat << EOF
RemoteWin Version 0.1.0
EOF
}

# List of required commands
required_commands=("xfreerdp" "awk" "grep" "sed")

# Function to check if a command is installed
check_command() {
  command_name=$1
  if ! command -v "$command_name" &>/dev/null; then
    echo "Error: The required command '$command_name' is not installed. Please install it and try again."
    exit 1
  fi
}

# Check all required commands
for cmd in "${required_commands[@]}"; do
  check_command "$cmd"
done


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

if [ -z $COMMAND ]; then
  echo "Error: No command specified"; exit 1;
fi;

case $COMMAND in
  connect)
    cmd_connect;;
  check)
    cmd_check;;
  launch)
    cmd_launch;;
esac
