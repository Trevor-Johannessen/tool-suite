#!/bin/bash

# Check if correct number of arguments is provided
if [ "$#" -ne 2 ]; then
    echo "Usage: $0 <directory> <user/group> <permissions>"
    echo "Example: $0 /path/to/directory u:username:rw"
    echo "Example: $0 /path/to/directory g:groupname:rwx"
    exit 1
fi

# Assign arguments to variables
TARGET_DIR="$1"
ACL_TARGET="$2"  # Format: u:username or g:groupname

# Ensure the directory exists
if [ ! -d "$TARGET_DIR" ]; then
    echo "Error: Directory '$TARGET_DIR' does not exist."
    exit 1
fi

# Set ACL recursively on all files and directories
find "$TARGET_DIR" -type f -exec setfacl -m "$ACL_TARGET" {} \;
find "$TARGET_DIR" -type d -exec setfacl -m "$ACL_TARGET" {} \;

# Set default ACLs for directories so new files inherit permissions
find "$TARGET_DIR" -type d -exec setfacl -d -m "$ACL_TARGET" {} \;

echo "ACLs set successfully for '$TARGET_DIR'."

