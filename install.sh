#!/usr/bin/env bash

#############################################
#
#       Quickstart Agent Installer
#       Author: Stephen Hynes
#       Version: 1.0
#
#############################################

# Need root to run this script
if [ "$(id -u)" != "0" ]; then
    echo "Please run this  script as root."
    echo "Usage: sudo ./install.sh"
    exit 1
fi

TMP_DIR=$(mktemp -d -t logentries.XXXXX)
trap "rm -rf "$TMP_DIR"" EXIT

FILES="le.py backports.py utils.py __init__.py metrics.py formats.py"
LE_PARENT="https://raw.githubusercontent.com/logentries/le/master/src/"
CURL="/usr/bin/env curl -O"

INSTALL_DIR="/usr/share/logentries"
LOGGER_CMD="logger -t LogentriesTest Test Message Sent By LogentriesAgent"
DAEMON="com.logentries.agent.plist"
DAEMON_DL_LOC="https://raw.githubusercontent.com/logentries/le/master/install/mac/$DAEMON"
DAEMON_PATH="/Library/LaunchDaemons/"

INSTALL_PATH="/usr/bin/le"
REGISTER_CMD="$INSTALL_PATH register"
LE_FOLLOW="$INSTALL_PATH follow"

printf "Welcome to the Logentries Install Script\n"

printf "Downloading dependencies...\n"

cd "$TMP_DIR"
for file in $FILES ; do
  $CURL $LE_PARENT/$file
done

$CURL $DAEMON_DL_LOC
sed -i -e 's/python2/python/' *.py

printf "Copying files...\n"
mkdir -p "$INSTALL_DIR"/logentries || true
mv *.py "$INSTALL_DIR"/logentries
chown -R root:wheel "$INSTALL_DIR"
chmod +x "$INSTALL_DIR"/logentries/le.py
chown root:wheel $DAEMON
mv $DAEMON $DAEMON_PATH
rm -f "$INSTALL_PATH" || true
ln -s "$INSTALL_DIR"/logentries/le.py "$INSTALL_PATH" 2>/dev/null || true

$REGISTER_CMD
$LE_FOLLOW "/var/log/system.log"

printf "\n**** Install Complete! ****\n\n"
printf "If you would like to monitor more files, simply run this command as root, 'le follow filepath', e.g. 'le follow /var/log/mylog.log'\n\n"
printf "And be sure to restart the agent service for new files to take effect, you can do this with the following two commands.\n"
printf "launchctl unload ${DAEMON_PATH}\n"
printf "launchctl load ${DAEMON_PATH}\n"
printf "For a full list of commands, run 'le --help' in the terminal.\n\n"

launchctl unload $DAEMON_PATH$DAEMON
launchctl load $DAEMON_PATH$DAEMON

printf "Starting agent"
i="0"
while [ $i -lt 40 ]
do
    sleep 0.05
    printf "."
    i=$[$i+1]
done

printf "DONE\n"

exit 0
