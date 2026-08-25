#!/bin/bash
# FileOrganizer.command — Sorts files into folders by type 
# Compatible with macOS default bash 3.2+
# Works standalone or wrapped with Platypus

# ─── Folder picker ───────────────────────────────────────────────────────────
if [ $# -ge 1 ] && [ -d "$1" ]; then
    TARGET_DIR="$1"
else
    TARGET_DIR=$(osascript -e '
        tell application "Finder"
            set theFolder to choose folder with prompt "Select a folder to organize:"
            return POSIX path of theFolder
        end tell
    ' 2>/dev/null) || {
        osascript -e 'display dialog "No folder selected. Exiting." buttons {"OK"} default button "OK" with icon stop' 2>/dev/null
        exit 0
    }
fi

# Strip trailing slash
TARGET_DIR="${TARGET_DIR%/}"

if [ ! -d "$TARGET_DIR" ]; then
    osascript -e "display dialog \"Invalid directory.\" buttons {\"OK\"} default button \"OK\" with icon stop" 2>/dev/null
    exit 1
fi

# ─── Category lookup ─────────────────────────────────────────────────────────
# Returns folder name for a given extension (lowercased via tr)
get_category() {
    local ext
    ext=$(echo "$1" | tr '[:upper:]' '[:lower:]')
    case "$ext" in
        jpg|jpeg|png|gif|bmp|svg|webp|tiff|tif|ico|heic|heif|raw|cr2|nef|arw|dng|orf|rw2|psd|ai|eps)
            echo "Images" ;;
        mp4|avi|mov|mkv|wmv|flv|webm|m4v|mpg|mpeg|3gp|ogv|vob|m2ts|m2v|ts)
            echo "Videos" ;;
        mp3|wav|aac|flac|ogg|m4a|wma|aiff|ape|opus|amr|m4b|mid|midi)
            echo "Audio" ;;
        pdf|doc|docx|xls|xlsx|ppt|pptx|odt|ods|odp|rtf|pages|numbers|key|tex|epub|mobi|xps|wpd)
            echo "Documents" ;;
        txt|md|markdown|csv|log|nfo)
            echo "Text Files" ;;
        json|xml|yaml|yml|toml|ini|cfg|conf|properties|env)
            echo "Data Files" ;;
        py|js|jsx|ts|tsx|html|htm|css|scss|sass|less|java|c|cpp|cc|cxx|h|hpp|swift|rb|php|sh|bash|zsh|fish|go|rs|kt|kts|scala|pl|pm|r|m|sql|lua|hs|elm|dart|vbs|ps1|bat|cmd|make|cmake|dockerfile|gradle|vue|svelte|zig|nim)
            echo "Code Files" ;;
        zip|rar|7z|tar|gz|bz2|xz|tgz|tbz2|txz|zst|lz|lzma|cab|cbr|cbz)
            echo "Archives" ;;
        dmg|iso|img|vmdk|vdi|vhd|vhdx|qcow2)
            echo "Disk Images" ;;
        stl|obj|fbx|blend|3ds|dae|gltf|glb|ply|step|stp|iges|igs|dwg|dxf|scad)
            echo "3D Models" ;;
        ttf|otf|woff|woff2|eot|fon)
            echo "Fonts" ;;
        exe|msi|app|pkg|deb|rpm|apk|ipa|aab)
            echo "Executables" ;;
        torrent)
            echo "Torrents" ;;
        db|sqlite|sqlite3|mdb|accdb)
            echo "Databases" ;;
        *)
            echo "Other" ;;
    esac
}

# ─── Main logic ──────────────────────────────────────────────────────────────
moved=0
summary=""

for filepath in "$TARGET_DIR"/*; do
    [ -e "$filepath" ] || continue
    [ -f "$filepath" ] || continue

    filename=$(basename "$filepath")

    # Skip hidden files
    case "$filename" in
        .*) continue ;;
    esac

    # Get extension
    case "$filename" in
        *.*) ext="${filename##*.}" ;;
        *)   ext="" ;;
    esac

    # Determine category
    if [ -z "$ext" ]; then
        category="Other"
    else
        category=$(get_category "$ext")
    fi

    # Create category folder
    category_dir="$TARGET_DIR/$category"
    mkdir -p "$category_dir"

    # Handle filename collisions
    dest="$category_dir/$filename"
    if [ -e "$dest" ]; then
        base="${filename%.*}"
        counter=1
        if [ -z "$ext" ]; then
            while [ -e "$category_dir/${filename}_${counter}" ]; do
                counter=$((counter + 1))
            done
            dest="$category_dir/${filename}_${counter}"
        else
            while [ -e "$category_dir/${base}_${counter}.${ext}" ]; do
                counter=$((counter + 1))
            done
            dest="$category_dir/${base}_${counter}.${ext}"
        fi
    fi

    mv "$filepath" "$dest"
    moved=$((moved + 1))

    # Platypus progress (shown in progress bar if configured)
    echo "Moved: $filename → $category/"
done

# ─── Summary dialog ──────────────────────────────────────────────────────────
if [ "$moved" -eq 0 ]; then
    osascript -e "display dialog \"No files found to organize.\" buttons {\"OK\"} default button \"OK\" with icon note" 2>/dev/null
    exit 0
fi

# Build a clean summary of what was created
summary_lines=""
for dir in "$TARGET_DIR"/*/; do
    [ -d "$dir" ] || continue
    dirname=$(basename "$dir")
    count=$(find "$dir" -maxdepth 1 -type f | wc -l | tr -d ' ')
    if [ "$count" -gt 0 ]; then
        summary_lines="${summary_lines}${dirname}: ${count} file(s)\n"
    fi
done

osascript -e "display dialog \"Organized $moved file(s):\n\n$summary_lines\" buttons {\"Done\"} default button \"Done\" with icon note" 2>/dev/null

exit 0
