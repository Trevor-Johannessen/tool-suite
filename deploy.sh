#!/bin/bash

# Check if /bin exists and is writable
if [ ! -d "/bin" ] || [ ! -w "/bin" ]; then
    echo "Error: /bin does not exist or is not writable."
    exit 1
fi

# Move and rename all .sh files
for file in *.sh; do
    if [ -f "$file" ]; then
        cp "$file" "/bin/${file%.sh}"
        echo "Copied $file to /bin/${file%.sh}"
    fi
done

echo "All .sh files deployed successfully."

