#!/bin/bash
# CleanupScheduler.command — GUI setup for scheduling FileOrganizer via cron
# Creates ~/.fileorganizer.conf and installs the cron job
# Compatible with macOS default bash 3.2+

# ─── Locate companion script ─────────────────────────────────────────────────
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FILE_ORGANIZER="$SCRIPT_DIR/FileOrganizer.command"
CONFIG_FILE="$HOME/.fileorganizer.conf"
LOG_FILE="$HOME/.fileorganizer.log"
CRON_MARKER="# FileOrganizer-auto"

# Verify FileOrganizer.command exists alongside this script
if [ ! -f "$FILE_ORGANIZER" ]; then
    osascript -e "display dialog \"FileOrganizer.command was not found in:\n$SCRIPT_DIR\n\nPlace both files in the same folder and try again.\" buttons {\"OK\"} default button \"OK\" with icon stop" 2>/dev/null
    exit 1
fi

# Ensure FileOrganizer is executable
chmod +x "$FILE_ORGANIZER"

# ─── Helper: show a dialog and capture the button ────────────────────────────
show_dialog() {
    osascript -e "display dialog \"$1\" buttons {$2} default button \"$3\" with icon $4" 2>/dev/null
}

show_list() {
    local title="$1"
    local prompt="$2"
    local items="$3"    # AppleScript list literal: {"a", "b", "c"}
    local default="$4"
    osascript -e "choose from list $items with prompt \"$prompt\" with title \"$title\" default items {\"$default\"}" 2>/dev/null
}

# ─── Step 1: Welcome ─────────────────────────────────────────────────────────
# Check if a schedule already exists
existing_cron=""
if crontab -l 2>/dev/null | grep -q "$CRON_MARKER"; then
    existing_cron=$(crontab -l 2>/dev/null | grep "$CRON_MARKER")
fi

if [ -n "$existing_cron" ]; then
    welcome_msg="A scheduled cleanup is already active.\n\nChoose an option:"
    ACTION=$(show_dialog "$welcome_msg" "\"Update\", \"Remove\", \"Cancel\"" "Update" note)
else
    welcome_msg="This tool sets up automatic file organization.\n\n• Choose a folder to clean\n• Pick a schedule\n• A cron job and config file will be created\n\nFiles are sorted into subfolders by type (Images, Videos, Documents, etc.)."
    ACTION=$(show_dialog "$welcome_msg" "\"Set Up\", \"Cancel\"" "Set Up" note)
fi

# Parse button clicked
button=$(echo "$ACTION" | sed 's/.*button returned:\([^,]*\).*/\1/')

case "$button" in
    "Set Up"|"Update") ;;
    "Remove")
        # Remove cron entry
        crontab -l 2>/dev/null | grep -v "$CRON_MARKER" | crontab - 2>/dev/null
        # Remove config file
        if [ -f "$CONFIG_FILE" ]; then
            rm "$CONFIG_FILE"
        fi
        show_dialog "Schedule removed.\n\nThe cron job and config file have been deleted." "\"OK\"" "OK" note >/dev/null
        exit 0
        ;;
    *) exit 0 ;;
esac

# ─── Step 2: Choose folder ───────────────────────────────────────────────────
TARGET_DIR=$(osascript -e '
    tell application "Finder"
        set theFolder to choose folder with prompt "Select the folder to automatically organize:"
        return POSIX path of theFolder
    end tell
' 2>/dev/null) || exit 0

TARGET_DIR="${TARGET_DIR%/}"

if [ ! -d "$TARGET_DIR" ]; then
    show_dialog "Invalid folder selected." "\"OK\"" "OK" stop >/dev/null
    exit 1
fi

# ─── Step 3: Choose frequency ────────────────────────────────────────────────
FREQ=$(show_list "Schedule" "How often should files be organized?" \
    '{"Every hour", "Every 6 hours", "Every 12 hours", "Daily", "Weekly"}' \
    "Daily")

if [ -z "$FREQ" ] || [ "$FREQ" = "false" ]; then
    exit 0
fi

# ─── Step 4: Choose time (for Daily and Weekly) ─────────────────────────────
TIME_HOUR=18  # default 6 PM
TIME_CHOICE=""

if [ "$FREQ" = "Daily" ] || [ "$FREQ" = "Weekly" ]; then
    TIME_CHOICE=$(show_list "Time" "What time of day?" \
        '{"6:00 AM", "7:00 AM", "8:00 AM", "9:00 AM", "10:00 AM", "11:00 AM", "12:00 PM", "1:00 PM", "2:00 PM", "3:00 PM", "4:00 PM", "5:00 PM", "6:00 PM", "7:00 PM", "8:00 PM", "9:00 PM"}' \
        "6:00 PM")

    if [ -z "$TIME_CHOICE" ] || [ "$TIME_CHOICE" = "false" ]; then
        exit 0
    fi

    # Convert time string to 24-hour format
    time_hour="${TIME_CHOICE%%:*}"
    time_ampm="${TIME_CHOICE##* }"
    # Remove leading zero for arithmetic
    time_hour=$((10#$time_hour))
    if [ "$time_ampm" = "PM" ] && [ "$time_hour" -lt 12 ]; then
        TIME_HOUR=$((time_hour + 12))
    elif [ "$time_ampm" = "AM" ] && [ "$time_hour" -eq 12 ]; then
        TIME_HOUR=0
    else
        TIME_HOUR=$time_hour
    fi
fi

# ─── Step 5: Choose day (for Weekly) ─────────────────────────────────────────
DAY_CRON="*"
DAY_CHOICE=""

if [ "$FREQ" = "Weekly" ]; then
    DAY_CHOICE=$(show_list "Day" "Which day of the week?" \
        '{"Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"}' \
        "Sunday")

    if [ -z "$DAY_CHOICE" ] || [ "$DAY_CHOICE" = "false" ]; then
        exit 0
    fi

    case "$DAY_CHOICE" in
        Sunday)    DAY_CRON=0 ;;
        Monday)    DAY_CRON=1 ;;
        Tuesday)   DAY_CRON=2 ;;
        Wednesday) DAY_CRON=3 ;;
        Thursday)  DAY_CRON=4 ;;
        Friday)    DAY_CRON=5 ;;
        Saturday)  DAY_CRON=6 ;;
    esac
fi

# ─── Build cron expression ───────────────────────────────────────────────────
# Use minute 17 to avoid the :00 stampede
case "$FREQ" in
    "Every hour")
        CRON_EXPR="17 * * * *"
        SCHEDULE_DESC="Every hour"
        ;;
    "Every 6 hours")
        CRON_EXPR="17 */6 * * *"
        SCHEDULE_DESC="Every 6 hours"
        ;;
    "Every 12 hours")
        CRON_EXPR="17 */12 * * *"
        SCHEDULE_DESC="Every 12 hours"
        ;;
    "Daily")
        CRON_EXPR="17 $TIME_HOUR * * *"
        SCHEDULE_DESC="Daily at $TIME_CHOICE"
        ;;
    "Weekly")
        CRON_EXPR="17 $TIME_HOUR * * $DAY_CRON"
        SCHEDULE_DESC="Weekly on $DAY_CHOICE at $TIME_CHOICE"
        ;;
esac

# ─── Write config file ───────────────────────────────────────────────────────
cat > "$CONFIG_FILE" << EOF
# FileOrganizer configuration
# Generated by CleanupScheduler on $(date '+%Y-%m-%d %H:%M:%S')
DIRECTORY=$TARGET_DIR
SILENT=true
LOG_FILE=$LOG_FILE
EOF

# ─── Install cron job ────────────────────────────────────────────────────────
# Read existing crontab, remove any old FileOrganizer entry, add new one
{
    crontab -l 2>/dev/null | grep -v "$CRON_MARKER"
    echo "$CRON_EXPR ORGANIZE_DIR=\"$TARGET_DIR\" \"$FILE_ORGANIZER\" $CRON_MARKER"
} | crontab -

# ─── Confirmation ────────────────────────────────────────────────────────────
confirm_msg="Schedule is active!\n\n"
confirm_msg="${confirm_msg}Folder: $TARGET_DIR\n"
confirm_msg="${confirm_msg}Schedule: $SCHEDULE_DESC\n"
confirm_msg="${confirm_msg}Cron: $CRON_EXPR\n\n"
confirm_msg="${confirm_msg}Config: $CONFIG_FILE\n"
confirm_msg="${confirm_msg}Log: $LOG_FILE\n\n"
confirm_msg="${confirm_msg}Files will be sorted into subfolders by type."

show_dialog "$confirm_msg" "\"Done\"" "Done" note >/dev/null

exit 0
