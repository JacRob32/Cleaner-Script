# File Organizer for macOS

Sorts files in a folder into subfolders by type — images, videos, documents, code files, archives, and so on. Runs as a plain shell script with no dependencies.

## What's in here

| File | Purpose |
|---|---|
| `FileOrganizer.command` | The core script. Sorts files into categorized subfolders. Can be run manually, via cron, or through the scheduler. |
| `CleanupScheduler.command` | GUI setup tool. Lets you pick a folder and schedule, then writes a config file and installs the cron job for you. |
| `Fileorganizeronetime.command` | One-shot organizer. Run it, pick a folder, done. No config, no scheduling. |

## Installation

```
git clone https://github.com/your-username/file-organizer.git
cd file-organizer
```

That's it. No build step, no dependencies. The scripts use bash and `osascript`, both of which ship with macOS.

## macOS will probably block it the first time

Apple's Gatekeeper flags scripts downloaded from the internet. When you double-click any of the `.command` files, you'll likely see something like:

> "FileOrganizer.command" cannot be opened because it is from an unidentified developer.

To fix this:

1. Open **System Settings** (or System Preferences)
2. Go to **Privacy & Security**
3. Scroll down — you'll see a message about the blocked script
4. Click **Open Anyway**
5. Confirm when prompted

You only need to do this once per file. After that, it'll run normally.

Alternatively, you can clear the quarantine flag from the terminal:

```
xattr -d com.apple.quarantine FileOrganizer.command
xattr -d com.apple.quarantine CleanupScheduler.command
xattr -d com.apple.quarantine Fileorganizeronetime.command
```

## Using Fileorganizeronetime.command

For a one-off cleanup. Double-click it, pick a folder from the Finder dialog, and it sorts everything in that folder into subfolders by type. No setup, no config files.

## Using CleanupScheduler.command

For recurring automatic cleanup. Double-click it and follow the dialogs:

1. Pick the folder you want to keep organized
2. Choose how often it should run (hourly, every 6 hours, every 12 hours, daily, or weekly)
3. If daily or weekly, pick a time and day

It writes a config file to `~/.fileorganizer.conf` and installs a cron job. Run it again anytime to update the schedule or remove it entirely.

## Using FileOrganizer.command directly

It accepts a directory in three ways, checked in this order:

```
# Environment variable
ORGANIZE_DIR=~/Downloads ./FileOrganizer.command

# Command-line argument
./FileOrganizer.command ~/Downloads

# Config file (reads DIRECTORY from ~/.fileorganizer.conf)
./FileOrganizer.command
```

If none of those are set, it opens a folder picker dialog.

## Config file

The scheduler creates this automatically, but you can also write it by hand:

```
DIRECTORY=/Users/you/Downloads
SILENT=true
LOG_FILE=/Users/you/.fileorganizer.log
```

- `DIRECTORY` — the folder to organize
- `SILENT` — set to `true` to skip all dialogs and log results to a file instead. Useful for cron jobs.
- `LOG_FILE` — where to write the log when silent mode is on

## What gets sorted where

| Folder | Extensions |
|---|---|
| Images | jpg, jpeg, png, gif, bmp, svg, webp, tiff, heic, psd, raw, cr2, and more |
| Videos | mp4, mov, mkv, avi, webm, flv, wmv, and more |
| Audio | mp3, wav, flac, aac, ogg, m4a, and more |
| Documents | pdf, docx, xlsx, pptx, epub, rtf, pages, and more |
| Text Files | txt, md, csv, log |
| Data Files | json, xml, yaml, toml, ini, env |
| Code Files | py, js, ts, html, css, swift, go, rust, ruby, php, sh, and more |
| Archives | zip, rar, 7z, tar, gz, bz2, xz |
| Disk Images | dmg, iso, img |
| 3D Models | stl, obj, fbx, blend, gltf, glb |
| Fonts | ttf, otf, woff, woff2 |
| Executables | exe, msi, pkg, deb, apk |
| Torrents | torrent |
| Databases | db, sqlite, mdb |
| Other | anything not recognized |

## Notes

- Only top-level files in the target folder are moved. Subfolders are left alone.
- Hidden files (starting with `.`) are skipped.
- If a file with the same name already exists in the destination folder, a number is appended (`file_1.txt`, `file_2.txt`, etc.) — nothing gets overwritten.
- The cron job uses minute 17 past the hour to avoid the `:00` stampede on shared systems.
