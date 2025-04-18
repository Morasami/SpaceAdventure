#!/data/data/com.termux/files/usr/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

echo "[*] Welcome to the SpaceBot Setup!"
echo "[*] This script will install Ubuntu, Python, Playwright, and required files."
echo "[!] IMPORTANT: Termux may ask for Storage Permission. Please GRANT it."
sleep 3

# Request storage permission if not already granted (best effort)
# Note: This command just enables the possibility; the user still needs to grant it via the Android popup.
termux-setup-storage
echo "[*] Continuing setup... (If you weren't asked for permission, it might already be granted)"
sleep 2

echo "[*] Updating Termux and installing base dependencies..."
pkg update -y && pkg upgrade -y
pkg install proot-distro wget curl nano -y

echo "[*] Installing Ubuntu container (using default version, likely 24.04 - this might take a while)..."
# This will install the latest stable Ubuntu supported by proot-distro
proot-distro install ubuntu

echo "[*] Logging into Ubuntu to install Python, dependencies, and Playwright..."
# Use DEBIAN_FRONTEND to avoid interactive prompts from apt
proot-distro login ubuntu -- bash -c '
set -e # Also exit on error inside the container shell

echo "[Ubuntu] Updating package lists..."
apt update

echo "[Ubuntu] Installing default Python 3 (likely 3.12) and system dependencies..."
export DEBIAN_FRONTEND=noninteractive
# Use python3, python3-venv, python3-pip for default Python in Ubuntu 24.04+
apt install -y python3 python3-venv python3-pip \
build-essential curl wget nano libnss3 libnspr4 libatk1.0-0t64 libatspi2.0-0t64 \
libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libxkbcommon0 \
libasound2t64 software-properties-common || { echo "[!!!] Failed to install system dependencies via apt"; exit 1; }

echo "[Ubuntu] Creating Python virtual environment..."
# Use python3 command
python3 -m venv ~/spacebotenv || { echo "[!] Failed to create Python venv"; exit 1; }

echo "[Ubuntu] Activating virtual environment..."
source ~/spacebotenv/bin/activate

echo "[Ubuntu] Upgrading pip..."
# Upgrade pip within the virtual environment
pip install --upgrade pip || { echo "[!] Failed to upgrade pip"; exit 1; }

echo "[Ubuntu] Installing Python packages (Playwright, Requests, etc.)..."
pip install playwright requests pyfiglet aiohttp colorama rich || { echo "[!] Failed to install Python packages"; exit 1; }

echo "[Ubuntu] Installing Playwright browsers (THIS CAN TAKE A LONG TIME depending on network speed)..."
playwright install || { echo "[!] Failed to install Playwright browsers"; exit 1; }

echo "[✅] Ubuntu + Python + Playwright setup complete inside the container."
exit 0
' || { echo "[!!!] Ubuntu setup script failed!"; exit 1; } # Check if the proot-distro command block failed


# --- Back in Termux ---
echo "[*] Checking for required files in Downloads..."
UBUNTU_ROOTFS_PATH="$PREFIX/var/lib/proot-distro/installed-rootfs/ubuntu/root"
DOWNLOADS_PATH="/storage/emulated/0/Download"
SCRIPT_FILE="SpaceAdventure_obf.py" # Define script filename
DATA_FILE="data.txt"              # Define data filename

if [[ -f "$DOWNLOADS_PATH/$SCRIPT_FILE" ]]; then
  if cp "$DOWNLOADS_PATH/$SCRIPT_FILE" "$UBUNTU_ROOTFS_PATH/"; then
    echo "[✓] Copied $SCRIPT_FILE to Ubuntu container."
  else
    echo "[!] Failed to copy $SCRIPT_FILE! Check Termux storage permissions and if the file exists."
    # Exit if script file is critical and copy failed
    exit 1
  fi
else
  echo "[!] $SCRIPT_FILE not found in $DOWNLOADS_PATH! Please download it first."
  # Exit if script file is critical and not found
  exit 1
fi

if [[ -f "$DOWNLOADS_PATH/$DATA_FILE" ]]; then
  if cp "$DOWNLOADS_PATH/$DATA_FILE" "$UBUNTU_ROOTFS_PATH/"; then
    echo "[✓] Copied $DATA_FILE to Ubuntu container."
  else
    echo "[!] Failed to copy $DATA_FILE! Check Termux storage permissions and if the file exists."
    # Decide if this warrants exiting: exit 1
  fi
else
  echo "[!] $DATA_FILE not found in $DOWNLOADS_PATH! The bot might need this file to run correctly."
  # Decide if this warrants exiting: exit 1
fi

echo "[*] Creating 'spacebot' launcher alias in ~/.bashrc..."
# Ensure the alias uses the correct script filename
BASHRC_ALIAS='alias spacebot='\''proot-distro login ubuntu -- bash -c "cd ~ && source spacebotenv/bin/activate && python '$SCRIPT_FILE'"'\'''
if ! grep -q 'alias spacebot=' ~/.bashrc; then
  echo "$BASHRC_ALIAS" >> ~/.bashrc
  echo "[✓] Alias added. Restart Termux or run 'source ~/.bashrc', then run: spacebot"
else
  echo "[i] Alias 'spacebot' already exists."
fi

# Sourcing here only affects the *current* script session, not the user's main Termux session.
# source ~/.bashrc

echo
echo "----------------------------------------------"
echo "✅ All done! Setup script finished."
echo "   To run the bot:"
echo "   1. Close and reopen Termux (or run 'source ~/.bashrc')."
echo "   2. Type the command: spacebot"
echo "----------------------------------------------"
echo "🎉 Script, environment, and launcher should be ready!"
echo "(If you encounter issues, copy the error message and seek help)"

exit 0
