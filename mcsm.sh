#!/bin/sh
# Minecraft Server Manager v0.0.1

# Set print levels
error=1
standard=2
verbose=3

# Set global parameters
print_level=2
initalized=1
LOCAL_FILES="/var/lib/mcsm"
JAVA_PATH="/usr/java/jdk-21/bin/java"

# Functions

mcsm_print(){ # (level, message)
	if [ $print_level -ge $1 ]; then
		echo $2
	fi
}

mcsm_check_initalized(){
	if [ $initalized -ne 1 ]; then
		exit 1
	fi
}

mcsm_install(){
	mkdir "$LOCAL_FILES"
	mkdir "$LOCAL_FILES/server_versions"
	sqlite3 "$LOCAL_FILES/servers.db" "CREATE TABLE IF NOT EXISTS servers (name TEXT UNIQUE, filepath TEXT, last_start DATETIME, total_starts INT, exclusions TEXT);"
	chmod 777 "$LOCAL_FILES"
	chmod 766 "$LOCAL_FILES/servers.db"
}

mcsm_help(){
	echo "
COMMANDS:
	install - Installs the neccesary components for the manager. 
	start {server_name} - Starts a server.
	stop {server_name} - Stops a server.
	register {server_name} {filepath} - Registers an existing server with the manager.
	deregister {server_name} - Deregisters a server from the manager, but does not delete any files.
	create {server_name} - Creates a new server.
	delete {server_name} - Deletes a server and its files.
	list - Lists all registered servers.
	command {server_name} {command} - Runs a command on a given server
	kick {server_name} {player} - Kicks a player from a running server
	ban {server_name} {player} - Bans a player from a running server
	pardon {server_name} {player} - Pardons a player from a running server
	mute {server_name} {player} - Mutes a player on a given server
	unmute {server_name} {player} - Unmutes a player on a given server
	whitelist {server_name} {player} - Adds a player to the server's whitelist.
	blacklist {server_name} {player} - Removed a player from a server's whitelist.
	render {server_name} {world} {radius} {x} {z} - Renders a circle around the given coordinates for the given world.
	
	help - Prints the help menu.
	ping - pong!
	"
}

print_headers(){
	echo "Name|Filepath|Last Start|Total Starts|Exclusions"
}

server_run_command(){
	# Verify the server exists
	server_verify $1
        if [ $? -ne 2 ]; then
        	return 1
        fi
	
	# Find the server and print it's attributes
	server=$(sq	lite3 "$LOCAL_FILES/servers.db" "SELECT * FROM servers WHERE name = '$1';")
	
	# Get screen the given server is running on

	# Send command to found screen

}

server_running(){
	# Check if the provided server (name in $1) is running
	if screen -list | grep -q "$1"; then
		return 1
	fi
	return 0	
}

server_verify(){
	# Search server file for server
	matches=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT * FROM servers WHERE name = '$1';")
	
	# If the server cannot be found, print error message and exit
	if [ -z "$matches" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi
}

server_describe(){
	# Verify the server exists
	server_verify $1
        if [ $? -ne 0 ]; then
        	return 1
        fi
	
	# Find the server and print it's attributes
	server=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT * FROM servers WHERE name = '$1';")
	print_headers
	echo $server
}

server_backup(){
	echo "Backing up $1 to $2"
	cwd=$(pwd)
	exclusions=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT exclusions FROM servers WHERE name = '$1';")
	filepath=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1'")	
	cd $filepath
	tar --exclude='$exclusions' -czf "$2" ./
	#cd $cwd
}

server_start(){
	echo "Trying to start $1"

	# Check if server exists
	server_verify $1
	if [ $? -ne 0 ]; then
		return 1
	fi

	echo "$1 verified."

	# Check if server is running
	server_running $1
	if [ $? -ne 0 ]; then
		echo "Cannot start server: Server is already running..."
		return 1
	fi

	echo "$1 not running"

	# Get the file location of the server
	filepath=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1'")

	echo "filepath = $filepath"

	# Start the server
	if [ $print_level -ge 2 ]; then
		mcsm_print $standard "Starting $1."
	fi
	screen -dmS $1 bash -c "cd '$filepath'; $JAVA_PATH -Xmx16G -jar ./server.jar"
	if [ $? -ne 0 ]; then
		echo "Could not start server: Screen failed."
		return 1
	fi

	# Update the last started property
	sqlite3 "$LOCAL_FILES/servers.db" "UPDATE servers SET last_start = datetime('now'), total_starts = total_starts + 1 WHERE name = '$1';"
}

server_stop(){
	# Check if server exists
	server_verify $1
	if [ $? -ne 0 ]; then
		return 1
	fi

	# Check if the server is running
	server_running $1
	if [ $? -eq 0 ]; then                                           	
        	echo "Cannot stop server: Server is already stopped..."
        	return 1
        fi

	# Stop the server
	if [ $print_level -ge 1 ]; then
		mcsm_print $standard "Stopping $1."
	fi
	screen -S "sa" -X stuff "stop$(printf \\r)"	
}

server_list(){ # print all known servers, their running status, their file location, their last start time date, etc. 
	# Print header
	mcsm_print $standard "Server : File Path : Last Start"

	# Get list of server
	servers=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT * FROM servers")

	print_headers
	echo $servers
}

server_restart(){
	if [ $print_level -ge 2 ]; then
		mcsm_print $standard "Restarting $2."
	fi
	server_stop $1
	sleep 30
	server_start $1
}

server_register(){ # (name, path)
	# Check that the given directory exists
	if [ ! -d $2 ]; then
		mcsm_print $error "Could not find the '$2' directory."
		exit 1
	fi

	# Check that server.jar exists
	if [ ! -e "$2/server.jar" ]; then
		mcsm_print $error "The given directory does not contain a runnable server. (Is the .jar named server.jar?)"
		exit 1
	fi

	# Get server directory
	server_path=$(realpath "$2")

	# Create the record in the table
	sqlite3 "$LOCAL_FILES/servers.db" "INSERT INTO servers VALUES ('$1', '$server_path', 0, 0, '')"
	return $?
}

server_deregister(){ # (name)
	# Create the record in the table
	sqlite3 "$LOCAL_FILES/servers.db" "DELETE FROM servers WHERE name = '$1'"
	error_code=$?
	if [ $error_code -ne 0 ]; then
		mcsm_print $error "Could not deregister $1. ($error_code)"
	fi
	mcsm_print $verbose "Deregistered $1."
	return $error_code
}

server_create(){ # (name, version, [path])
	# Check if server version provided is available
	if ! find "$LOCAL_FILES/server_versions" -maxdepth 1 -name "$2" | grep -q .; then
		mcsm_print $error "Could not find server $2."
		exit 1
	fi

	# Check if location was provided (if not use cwd)
	if [ $# -eq 3 ]; then
		path=$3
	else
		path=$(pwd)
	fi

	# create the server
	mkdir "$path"
	cp "$LOCAL_FILES/server_versions/$2" "$path/server.jar"

	# register the new server
	server_register "$1" "$path"
	if [ $? -ne 0 ]; then
		rm "$path/server.jar"
		rmdir "$path"
		exit 1
	fi
}

server_delete(){ # (name) 
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi
	mcsm_print $verbose "$1 is located at $server_location."

	# Deregister Server
	server_deregister $1
	if [ $? -ne 0 ]; then
		exit 1
	fi

	# Delete files recursively
	rm -rf "$server_location"
	mcsm_print $verbose "Removed server files."
	mcsm_print $verbose "$1 deleted."
}

command_kick(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_ban(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}


command_pardon(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_mute(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}


command_unmute(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_render(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_say(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_whitelist(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}

command_blacklist(){
	# Get server file location
	server_location=$(sqlite3 "$LOCAL_FILES/servers.db" "SELECT filepath FROM servers WHERE name = '$1';")	
	if [ "$server_location" = "" ]; then
		mcsm_print $error "Could not find server $1."
		exit 1
	fi



}



# Check if sqlite3 exists and has the correct database setup
if [ ! -d "$LOCAL_FILES" ]; then
	mcsm_print $error "The minecraft server manager directory has not been created. Try running mcsm install."
	initalized=0
fi
if [ ! -e "$LOCAL_FILES/servers.db" ]; then
	mcsm_print $error "The minecraft server manager database has not been created. Try running mcsm install."
	initalized=0
fi
if [ ! -d "$LOCAL_FILES/server_versions" ]; then
	mcsm_print $error "The minecraft server manager server repository has not been created. Try running mcsm install."
	initalized=0
fi

# Parse flags
while getopts "vs" opt; do
	case $opt in
		v)
			print_level=3
			;;
		s)
			print_level=0
			;;
	esac
done

if [ $# -eq 0 ]; then
	exit 0
fi

# Shift arguments
shift $((OPTIND - 1))

# Run given command (should be first argument)
command=$1
shift 1
case $command in
	# Installs the needed database and directories
	"install")
		mcsm_install
		;;
	# Creates and registers a new server
	"create")
		mcsm_check_initalized
		server_create $1 $2 $3
		;;
	# Deregisters and deletes a server
	"delete")
		mcsm_check_initalized
		server_delete $1
		;;
	# Registers an existing server
	"register")
		mcsm_check_initalized
		server_register $1 $2
		;;
	# Deregisters a server without removing the files
	"deregister")
		mcsm_check_initalized
		server_deregister $1
		;;
	# Starts a server
	"start") 
		mcsm_check_initalized
		server_start $1
		;;
	# Restarts a server
	"restart")
		mcsm_check_initalized
		server_restart $1
		;;
	# Stops a server
	"stop")
		mcsm_check_initalized
		server_stop $1
		;;
	# Lists all known servers
	"list")
		mcsm_check_initalized
		server_list
		;;
	"describe")
		mcsm_check_initalized
		server_describe $1
		;;
	"help")
		mcsm_help
		;;
	"backup")
		server_backup $1 $2
		;;
	"mute")
		command_mute $1 $2
		;;
	"unmute")
		command_unmute $1 $2
		;;
	"ban")
		command_ban $1 $2
		;;
	"pardon")
		command_pardon $1 $2
		;;
	"whitelist")
		command_whitelist $1 $2
		;;
	"blacklist")
		command_blacklist $1 $2
		;;
	"say")
		command_say $1 $2
		;;
	"render")
		command_render $1 $2
		;;
	# Testing command
	"ping")
		mcsm_print $standard "pong"
	;;
esac
exit $?
