# This script is a wrapper to any backup script. It takes in a command to run, a directory to search for outdated backups, a naming scheme of the backup to monitor, and an count of how many backups to keep (If this number is zero or undefined do not delete any backups).
#
# Usage:
#	smart-backup [-dmn] {Backup Command}
#	-d : The directory to search
#	-m : The string to match file names to
#	-n : The number of files to preserve
# Example:
#	smart-backup -d /foo/bar -m "backup-*-version.tar.gz" -n 10 "backup-files -xyz '/foo/bar'"
#	
#	This runs the backup-files command with its given parameters. Then it searches the /foo/bar directory for files that match the backup-*-version.tar.gz naming scheme. It deletes the oldest files matching that scheme until 10 files remain.
#
# Returns:
#	0 if successful
#	1 if no backup command was provided.
#	# The error code of the given backup command
#

while getopts "d:m:n:" opt; do
    case $opt in
        d) directory="$OPTARG" ;;
        m) match_string="$OPTARG" ;;
        n) num_files="$OPTARG" ;;
        \?) echo "Invalid option: -$OPTARG" >&2; exit 1 ;;
        :) echo "Option -$OPTARG requires an argument." >&2; exit 1 ;;
    esac
done

# Check if a backup command is provided
shift $((OPTIND -1))
if [ $# -eq 0 ]; then
    echo "No backup command provided."
    exit 1
fi
backup_command="$@"

# Check that the backup directory exists
if [ ! -d "$directory" ]; then
    echo "The specified directory does not exist: $directory"
    exit 1
fi

# Run the backup 
$backup_command

# Delete excess backups
backups=$(find "$directory" -maxdepth 1 -name "$match_string" -type f | wc -l)
echo "There are currently $backups backups"
if [ "$backups" -gt "$num_files" ]; then
    files_to_delete=$((backups - num_files))
    echo "$files_to_delete files to delete"
    if [ "$files_to_delete" -lt 0 ]; then
        files_to_delete=0
    fi
    find "$directory" -maxdepth 1 -name "$match_string" -type f -printf "%T@ %p\n"  | sort -k1,1nr | cut -d' ' -f2- | tail -n "$files_to_delete" | while read -r file; do
        rm $file
    done
fi

