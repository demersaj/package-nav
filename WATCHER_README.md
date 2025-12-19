# Navigator Version Watcher

This directory includes an automated watcher system that monitors for new Navigator versions and automatically creates packages when a new version is published.

## Components

- **`watch_navigator.sh`** - The main watcher script that checks for new versions
- **`com.navigator.watcher.plist`** - Launchd configuration file for scheduling
- **`setup_watcher.sh`** - Helper script to install/uninstall the watcher

## How It Works

1. The watcher periodically checks the JSON endpoint (defined in `.env` as `JSON_URL`)
2. It compares the latest version with the last processed version (stored in `.last_version`)
3. If a new version is detected, it automatically runs `pkg_nav.sh` to create a new package
4. All activity is logged to `watch.log`

## Setup Instructions

### 1. Ensure your `.env` file is configured

Make sure your `.env` file contains all required variables:
```bash
COMPANY_NAME="My Company Name"
TEAM_ID="My Team Id"
NOTARY_PROFILE="SavedNotaryProfile"
JSON_URL="https://downloads.example.com.json"
```

### 2. Install the watcher

Run the setup script to install the watcher as a launchd service:

```bash
./setup_watcher.sh install
```

This will:
- Copy the plist file to `~/Library/LaunchAgents/`
- Update paths to match your current directory
- Load the service to start watching immediately

### 3. Verify installation

Check if the watcher is running:

```bash
./setup_watcher.sh status
```

### 4. Test the watcher manually

You can test the watcher without waiting for the scheduled run:

```bash
./setup_watcher.sh test
```

## Configuration

### Check Interval

By default, the watcher checks for new versions every hour (3600 seconds). To change this:

1. Edit `com.navigator.watcher.plist`
2. Modify the `<integer>` value in the `<key>StartInterval</key>` section
3. Reinstall the watcher: `./setup_watcher.sh uninstall && ./setup_watcher.sh install`

### Example intervals:
- Every 30 minutes: `<integer>1800</integer>`
- Every 2 hours: `<integer>7200</integer>`
- Every 6 hours: `<integer>21600</integer>`
- Every 24 hours: `<integer>86400</integer>`

## Monitoring

### View logs

The watcher creates several log files:

```bash
# Main watcher log
tail -f watch.log

# Launchd stdout
tail -f watch_stdout.log

# Launchd stderr
tail -f watch_stderr.log
```

### Check service status

```bash
# Using the setup script
./setup_watcher.sh status

# Or directly with launchctl
launchctl list | grep navigator
```

## Management

### Uninstall the watcher

```bash
./setup_watcher.sh uninstall
```

### Manually trigger a check

```bash
./setup_watcher.sh test
```

### Restart the watcher

```bash
./setup_watcher.sh uninstall
./setup_watcher.sh install
```

## Troubleshooting

### Watcher not running

1. Check if the service is loaded:
   ```bash
   launchctl list | grep navigator
   ```

2. Check for errors in the log files:
   ```bash
   cat watch_stderr.log
   ```

3. Verify the plist file paths are correct:
   ```bash
   cat ~/Library/LaunchAgents/com.navigator.watcher.plist
   ```

### Package creation fails

The watcher will log any errors from `pkg_nav.sh`. Check `watch.log` for details:

```bash
tail -n 50 watch.log
```

### Version not updating

If the watcher isn't detecting new versions:

1. Check if `.last_version` exists and contains the current version
2. Manually delete `.last_version` to force a re-check:
   ```bash
   rm .last_version
   ./setup_watcher.sh test
   ```

## Alternative: Manual Cron Setup

If you prefer using cron instead of launchd, you can add this to your crontab:

```bash
crontab -e
```

Add this line (checks every hour):
```
0 * * * * /Users/huxley-47/dev/package-nav/watch_navigator.sh >> /Users/huxley-47/dev/package-nav/watch.log 2>&1
```

## Notes

- The watcher will only create a package if a **new** version is detected
- If you want to force a package creation, delete the `.last_version` file
- The watcher runs in the background and won't interrupt your work
- Packages are created in the same directory as the script

