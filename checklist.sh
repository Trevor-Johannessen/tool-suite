#!/bin/bash

# Checklist
#
# This program provides a simple terminal accessible checklist that can be added to a profile to keep track of tasks.
#
# Author: Trevor Johannessen
#
# Version History:
# v0.0.1 Created the first draft of the checklist. 


DB_PATH="/etc/checklist/test.db"
DB_DIR="/etc/checklist"

# Create database directory if it doesn't exist
if [ ! -d "$DB_DIR" ]; then
    echo "Sudo is needed to create the /etc/checklist directory."
    sudo mkdir -p "$DB_DIR"
    sudo chmod 777 "$DB_DIR"
fi

# Create database and table if they don't exist
init_db() {
    if [ ! -f "$DB_PATH" ]; then
        sqlite3 "$DB_PATH" "
        CREATE TABLE tasks (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            priority INTEGER DEFAULT 1,
            desc TEXT NOT NULL,
            status INTEGER DEFAULT 0,
            created INTEGER,
            completed INTEGER DEFAULT 0,
            staged INTEGER DEFAULT 0,
            owner_id INTEGER NOT NULL
        );"
    fi
}

# Helper function to format task display
format_task() {
    local id=$1
    local status=$2
    local desc=$3
    local status_display="[ ]"
    if [ "$status" -eq 1 ]; then
        status_display="[X]"
    fi
    echo "$id | $status_display | $desc"
}

# Get current user's UID
CURRENT_USER=$(id -u)

# Check ownership of task
check_ownership() {
    local task_id=$1
    local owner_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM tasks WHERE id=$task_id AND owner_id=$CURRENT_USER;")
    if [ "$owner_count" -eq 0 ]; then
        echo "Error: Task $task_id does not belong to current user"
        exit 1
    fi
}

# Command implementations
list_tasks() {
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER AND status=0;" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

list_checked() {
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER AND status=1;" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

list_all() {
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER;" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

check_task() {
    local task_id=$1
    check_ownership "$task_id"
    local timestamp=$(date +%s)
    sqlite3 "$DB_PATH" "UPDATE tasks SET status=1, completed=$timestamp WHERE id=$task_id;"
}

uncheck_task() {
    local task_id=$1
    check_ownership "$task_id"
    sqlite3 "$DB_PATH" "UPDATE tasks SET status=0, completed=0 WHERE id=$task_id;"
}

new_task() {
    local desc="$1"
    local timestamp=$(date +%s)
    sqlite3 "$DB_PATH" "INSERT INTO tasks (desc, created, owner_id) VALUES ('$desc', $timestamp, $CURRENT_USER);"
}

delete_task() {
    local task_id=$1
    check_ownership "$task_id"
    sqlite3 "$DB_PATH" "DELETE FROM tasks WHERE id=$task_id;"
}

list_next() {
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER AND status=0 AND priority=(SELECT MIN(priority) FROM tasks WHERE owner_id=$CURRENT_USER AND status=0);" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

stage_task() {
    local task_id=$1
    check_ownership "$task_id"
    sqlite3 "$DB_PATH" "UPDATE tasks SET staged=1 WHERE id=$task_id;"
}

unstage_task() {
    local task_id=$1
    check_ownership "$task_id"
    sqlite3 "$DB_PATH" "UPDATE tasks SET staged=0 WHERE id=$task_id;"
}

list_staged() {
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER AND staged=1;" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

find_tasks() {
    local pattern="$1"
    sqlite3 "$DB_PATH" "SELECT id, status, desc FROM tasks WHERE owner_id=$CURRENT_USER AND desc LIKE '%$pattern%';" | while IFS='|' read -r id status desc; do
        format_task "$id" "$status" "$desc"
    done
}

print_help() {
    echo "HELP:
    -h --help -> Displays the help menu.
    -c --check -> Marks a given task as checked. This sets its status value to 1. This takes in an argument which is the task ID of the task to be checked. The completed attribute should be set to the current unix timestamp.
    -u --uncheck -> Marks a given task as unchecked. This sets its status value to 0. This takes in an argument which is the task ID of the task to be unchecked.
    -n --new -> Creates a new task. This takes in an argument which is the description of the task to be created. The task is then inserted into the database. The created attribute should be the current unix timestamp.
    -d --delete -> Deleted a given task. This takes in an argument which is the task ID of the task to be deleted.
    -s --stage -> Sets a given task as staged. This sets its staged attribute to 0. This takes in an argument which is the task ID of the task to be staged.
    -u --unstage -> Sets a given task as unstaged. This sets its staged sttribute to 0. This takes in an argument which is the task ID of the task to be unstaged.
    -f --find -> lists all tasks that belong to the current user and contain the given string. This attribute takes in a string to find.
    -L --list -> lists all uncompleted tasks for the current user.
    -C --list-checked -> list all tasks that are marked as completed for the current user.
    -A --list-all -> list all tasks, both completed and uncompleted, for the current user.
    -N --list-next -> Checks all uncompleted tasks assigned to the user and finds the lowest priority. It then displays all tasks of that priority. 
    -S --list-staged -> lists all tasks marked as staged for the current user.
    "
}

# Initialize database
init_db

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -L|--list) list_tasks; exit 0 ;;
        -C|--list-checked) list_checked; exit 0 ;;
        -A|--list-all) list_all; exit 0 ;;
        -c|--check) check_task "$2"; exit 0 ;;
        -u|--uncheck) uncheck_task "$2"; exit 0 ;;
        -n|--new) new_task "$2"; exit 0 ;;
        -d|--delete) delete_task "$2"; exit 0 ;;
        -N|--list-next) list_next; exit 0 ;;
        -s|--stage) stage_task "$2"; exit 0 ;;
        --unstage) unstage_task "$2"; exit 0 ;;
        -S|--list-staged) list_staged; exit 0 ;;
        -f|--find) find_tasks "$2"; exit 0 ;;
        -h|--help) print_help; exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done