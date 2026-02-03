#!/bin/bash

# macOS Artifact Collection Script
# Collects forensic artifacts for security investigation

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}macOS Artifact Collection Script${NC}"
echo -e "${GREEN}========================================${NC}"

# Create timestamped output directory
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
OUTPUT_DIR="$HOME/artifacts_$TIMESTAMP"
mkdir -p "$OUTPUT_DIR"

echo -e "${YELLOW}[*] Output directory: $OUTPUT_DIR${NC}"

# Function to safely run commands and capture output
safe_run() {
    local output_file="$1"
    shift
    echo -e "${YELLOW}[*] Collecting: $output_file${NC}"
    "$@" > "$OUTPUT_DIR/$output_file" 2>&1 || echo "Error running command" >> "$OUTPUT_DIR/$output_file"
}

# Function to safely copy files
safe_copy() {
    local src="$1"
    local dest="$2"
    if [ -e "$src" ]; then
        cp -R "$src" "$OUTPUT_DIR/$dest" 2>/dev/null || echo "Could not copy $src"
    fi
}

# ========================================
# 1. SYSTEM INFORMATION
# ========================================
echo -e "${GREEN}[+] Collecting System Information${NC}"
mkdir -p "$OUTPUT_DIR/system_info"

safe_run "system_info/hostname.txt" hostname
safe_run "system_info/date.txt" date
safe_run "system_info/uptime.txt" uptime
safe_run "system_info/sw_vers.txt" sw_vers
safe_run "system_info/uname.txt" uname -a
safe_run "system_info/system_profiler.txt" system_profiler SPSoftwareDataType SPHardwareDataType
safe_run "system_info/diskutil.txt" diskutil list
safe_run "system_info/df.txt" df -h
safe_run "system_info/mount.txt" mount

# ========================================
# 2. PROCESS & NETWORK DATA
# ========================================
echo -e "${GREEN}[+] Collecting Process & Network Data${NC}"
mkdir -p "$OUTPUT_DIR/processes_network"

safe_run "processes_network/ps_aux.txt" ps aux
safe_run "processes_network/top_snapshot.txt" top -l 1 -n 20
safe_run "processes_network/netstat_all.txt" netstat -an
safe_run "processes_network/netstat_routing.txt" netstat -rn
safe_run "processes_network/lsof_network.txt" lsof -i
safe_run "processes_network/lsof_all.txt" lsof
safe_run "processes_network/ifconfig.txt" ifconfig -a
safe_run "processes_network/arp.txt" arp -a
safe_run "processes_network/dns_cache.txt" dscacheutil -cachedump -entries Host

# ========================================
# 3. USER & AUTHENTICATION DATA
# ========================================
echo -e "${GREEN}[+] Collecting User & Authentication Data${NC}"
mkdir -p "$OUTPUT_DIR/users_auth"

safe_run "users_auth/users.txt" dscl . list /Users
safe_run "users_auth/groups.txt" dscl . list /Groups
safe_run "users_auth/current_user.txt" whoami
safe_run "users_auth/logged_in_users.txt" who
safe_run "users_auth/last_logins.txt" last
safe_run "users_auth/sudo_users.txt" dscl . -read /Groups/admin GroupMembership

# Copy user account data
for user_dir in /Users/*; do
    if [ -d "$user_dir" ]; then
        username=$(basename "$user_dir")
        safe_run "users_auth/user_${username}_info.txt" dscl . -read "/Users/$username"
    fi
done

# ========================================
# 4. SSH DATA
# ========================================
echo -e "${GREEN}[+] Collecting SSH Data${NC}"
mkdir -p "$OUTPUT_DIR/ssh_data"

# System-wide SSH
safe_copy "/etc/ssh/sshd_config" "ssh_data/sshd_config"
safe_copy "/etc/ssh/ssh_config" "ssh_data/ssh_config"

# User SSH data
for user_dir in /Users/*; do
    if [ -d "$user_dir/.ssh" ]; then
        username=$(basename "$user_dir")
        mkdir -p "$OUTPUT_DIR/ssh_data/$username"
        safe_copy "$user_dir/.ssh/config" "ssh_data/$username/config"
        safe_copy "$user_dir/.ssh/known_hosts" "ssh_data/$username/known_hosts"
        safe_copy "$user_dir/.ssh/authorized_keys" "ssh_data/$username/authorized_keys"
        # List SSH keys (don't copy private keys)
        ls -la "$user_dir/.ssh/" > "$OUTPUT_DIR/ssh_data/$username/ssh_keys_list.txt" 2>&1
    fi
done

# ========================================
# 5. BROWSER DATA
# ========================================
echo -e "${GREEN}[+] Collecting Browser Data${NC}"
mkdir -p "$OUTPUT_DIR/browser_data"

for user_dir in /Users/*; do
    username=$(basename "$user_dir")

    # Safari
    if [ -d "$user_dir/Library/Safari" ]; then
        mkdir -p "$OUTPUT_DIR/browser_data/$username/Safari"
        safe_copy "$user_dir/Library/Safari/History.db" "browser_data/$username/Safari/History.db"
        safe_copy "$user_dir/Library/Safari/Downloads.plist" "browser_data/$username/Safari/Downloads.plist"
        safe_copy "$user_dir/Library/Safari/Bookmarks.plist" "browser_data/$username/Safari/Bookmarks.plist"
        safe_copy "$user_dir/Library/Safari/TopSites.plist" "browser_data/$username/Safari/TopSites.plist"
    fi

    # Chrome
    if [ -d "$user_dir/Library/Application Support/Google/Chrome" ]; then
        mkdir -p "$OUTPUT_DIR/browser_data/$username/Chrome"
        safe_copy "$user_dir/Library/Application Support/Google/Chrome/Default/History" "browser_data/$username/Chrome/History"
        safe_copy "$user_dir/Library/Application Support/Google/Chrome/Default/Cookies" "browser_data/$username/Chrome/Cookies"
        safe_copy "$user_dir/Library/Application Support/Google/Chrome/Default/Bookmarks" "browser_data/$username/Chrome/Bookmarks"
    fi

    # Firefox
    if [ -d "$user_dir/Library/Application Support/Firefox/Profiles" ]; then
        mkdir -p "$OUTPUT_DIR/browser_data/$username/Firefox"
        safe_copy "$user_dir/Library/Application Support/Firefox/Profiles" "browser_data/$username/Firefox/Profiles"
    fi
done

# ========================================
# 6. FILE SYSTEM ARTIFACTS
# ========================================
echo -e "${GREEN}[+] Collecting File System Artifacts${NC}"
mkdir -p "$OUTPUT_DIR/filesystem"

# Recent files and downloads
for user_dir in /Users/*; do
    username=$(basename "$user_dir")

    # List Downloads folder
    if [ -d "$user_dir/Downloads" ]; then
        ls -lhR "$user_dir/Downloads" > "$OUTPUT_DIR/filesystem/${username}_downloads.txt" 2>&1
    fi

    # List Desktop
    if [ -d "$user_dir/Desktop" ]; then
        ls -lhR "$user_dir/Desktop" > "$OUTPUT_DIR/filesystem/${username}_desktop.txt" 2>&1
    fi

    # List Documents
    if [ -d "$user_dir/Documents" ]; then
        ls -lhR "$user_dir/Documents" > "$OUTPUT_DIR/filesystem/${username}_documents.txt" 2>&1
    fi

    # Recent files (modified in last 7 days)
    find "$user_dir" -type f -mtime -7 -ls > "$OUTPUT_DIR/filesystem/${username}_recent_files.txt" 2>&1
done

# Temporary files
ls -lhR /tmp > "$OUTPUT_DIR/filesystem/tmp_files.txt" 2>&1
ls -lhR /var/tmp > "$OUTPUT_DIR/filesystem/var_tmp_files.txt" 2>&1

# Trash
for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    if [ -d "$user_dir/.Trash" ]; then
        ls -lhR "$user_dir/.Trash" > "$OUTPUT_DIR/filesystem/${username}_trash.txt" 2>&1
    fi
done

# ========================================
# 7. INSTALLED APPLICATIONS
# ========================================
echo -e "${GREEN}[+] Collecting Installed Applications${NC}"
mkdir -p "$OUTPUT_DIR/applications"

# Applications folder
ls -lh /Applications > "$OUTPUT_DIR/applications/applications_list.txt" 2>&1
system_profiler SPApplicationsDataType > "$OUTPUT_DIR/applications/all_applications.txt" 2>&1

# Homebrew packages
if command -v brew &> /dev/null; then
    safe_run "applications/brew_list.txt" brew list
    safe_run "applications/brew_services.txt" brew services list
fi

# Python packages
if command -v pip3 &> /dev/null; then
    safe_run "applications/pip3_list.txt" pip3 list
fi

if command -v pip &> /dev/null; then
    safe_run "applications/pip_list.txt" pip list
fi

# Node packages
if command -v npm &> /dev/null; then
    safe_run "applications/npm_global.txt" npm list -g --depth=0
fi

# Gem packages
if command -v gem &> /dev/null; then
    safe_run "applications/gem_list.txt" gem list
fi

# ========================================
# 8. LOGS
# ========================================
echo -e "${GREEN}[+] Collecting Logs${NC}"
mkdir -p "$OUTPUT_DIR/logs"

# System logs
safe_copy "/var/log/system.log" "logs/system.log"
safe_copy "/var/log/install.log" "logs/install.log"

# Copy recent logs
find /var/log -type f -mtime -7 -exec cp {} "$OUTPUT_DIR/logs/" \; 2>/dev/null

# User logs
for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    if [ -d "$user_dir/Library/Logs" ]; then
        mkdir -p "$OUTPUT_DIR/logs/$username"
        cp -R "$user_dir/Library/Logs/"* "$OUTPUT_DIR/logs/$username/" 2>/dev/null
    fi
done

# Console logs using log command (last 24 hours)
log show --predicate 'eventMessage contains "error" OR eventMessage contains "failed"' --info --last 24h > "$OUTPUT_DIR/logs/console_errors_24h.txt" 2>&1

# Auth logs
log show --predicate 'process == "sudo" OR process == "su" OR process == "login"' --info --last 7d > "$OUTPUT_DIR/logs/auth_logs_7d.txt" 2>&1

# ========================================
# 9. MALICIOUS BEHAVIOR INDICATORS
# ========================================
echo -e "${GREEN}[+] Collecting Malicious Behavior Indicators${NC}"
mkdir -p "$OUTPUT_DIR/malicious_indicators"

# Shell history for all users
for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    safe_copy "$user_dir/.bash_history" "malicious_indicators/${username}_bash_history"
    safe_copy "$user_dir/.zsh_history" "malicious_indicators/${username}_zsh_history"
    safe_copy "$user_dir/.sh_history" "malicious_indicators/${username}_sh_history"
done

# Profile and startup scripts
for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    safe_copy "$user_dir/.bashrc" "malicious_indicators/${username}_bashrc"
    safe_copy "$user_dir/.bash_profile" "malicious_indicators/${username}_bash_profile"
    safe_copy "$user_dir/.zshrc" "malicious_indicators/${username}_zshrc"
    safe_copy "$user_dir/.profile" "malicious_indicators/${username}_profile"
done

# Cron jobs
crontab -l > "$OUTPUT_DIR/malicious_indicators/user_crontab.txt" 2>&1
safe_copy "/etc/crontab" "malicious_indicators/system_crontab"
ls -la /etc/cron.d/ > "$OUTPUT_DIR/malicious_indicators/cron_d_list.txt" 2>&1

# Launch Agents and Daemons
mkdir -p "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons"
ls -lhR /Library/LaunchAgents > "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/library_launchagents.txt" 2>&1
ls -lhR /Library/LaunchDaemons > "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/library_launchdaemons.txt" 2>&1
ls -lhR /System/Library/LaunchAgents > "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/system_launchagents.txt" 2>&1
ls -lhR /System/Library/LaunchDaemons > "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/system_launchdaemons.txt" 2>&1

for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    if [ -d "$user_dir/Library/LaunchAgents" ]; then
        ls -lhR "$user_dir/Library/LaunchAgents" > "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/${username}_launchagents.txt" 2>&1
    fi
done

# Copy actual launch agent/daemon plists (recent or modified)
find /Library/LaunchAgents /Library/LaunchDaemons -type f -name "*.plist" -mtime -30 -exec cp {} "$OUTPUT_DIR/malicious_indicators/launch_agents_daemons/" \; 2>/dev/null

# Kernel extensions
safe_run "malicious_indicators/kextstat.txt" kextstat

# Running services
safe_run "malicious_indicators/launchctl_services.txt" launchctl list

# Environment variables
safe_run "malicious_indicators/environment.txt" env

# Hosts file
safe_copy "/etc/hosts" "malicious_indicators/hosts"

# Installed profiles
safe_run "malicious_indicators/profiles.txt" profiles -P -v

# Quarantine events (downloads)
for user_dir in /Users/*; do
    username=$(basename "$user_dir")
    if [ -f "$user_dir/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2" ]; then
        safe_copy "$user_dir/Library/Preferences/com.apple.LaunchServices.QuarantineEventsV2" "malicious_indicators/${username}_quarantine_events.db"
    fi
done

# ========================================
# COMPRESSION
# ========================================
echo -e "${GREEN}[+] Creating compressed archive${NC}"
cd "$HOME"
tar -czf "artifacts_$TIMESTAMP.tar.gz" "artifacts_$TIMESTAMP" 2>&1
ARCHIVE_SIZE=$(du -h "artifacts_$TIMESTAMP.tar.gz" | cut -f1)

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}[✓] Artifact collection complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo -e "${YELLOW}Output directory: $OUTPUT_DIR${NC}"
echo -e "${YELLOW}Compressed archive: $HOME/artifacts_$TIMESTAMP.tar.gz ($ARCHIVE_SIZE)${NC}"
echo -e "${GREEN}========================================${NC}"