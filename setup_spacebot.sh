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

echo "[*] Installing Ubuntu container (this might take a while)..."
proot-distro install ubuntu

echo "[*] Logging into Ubuntu to install Python, dependencies, and Playwright..."
# Use DEBIAN_FRONTEND to avoid interactive prompts from apt
proot-distro login ubuntu -- bash -c '
set -e # Also exit on error inside the container shell

echo "[Ubuntu] Updating package lists..."
apt update

echo "[Ubuntu] Installing Python 3.11 and system dependencies (this might take a while)..."
export DEBIAN_FRONTEND=noninteractive
apt install -y python3.11 python3.11-venv python3.11-distutils \
build-essential curl wget nano libnss3 libnspr4 libatk1.0-0t64 libatspi2.0-0t64 \
libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libxkbcommon0 \
libasound2t64 software-properties-common

echo "[Ubuntu] Creating Python virtual environment..."
python3.11 -m venv ~/spacebotenv || { echo "[!] Failed to create Python venv"; exit 1; }

echo "[Ubuntu] Activating virtual environment and installing pip..."
source ~/spacebotenv/bin/activate
curl -sS https://bootstrap.pypa.io/get-pip.py | python

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

if [[ -f "$DOWNLOADS_PATH/SpaceAdventure_obf.py" ]]; then
  if cp "$DOWNLOADS_PATH/SpaceAdventure_obf.py" "$UBUNTU_ROOTFS_PATH/"; then
    echo "[✓] Copied SpaceAdventure_obf.py to Ubuntu container."
  else
    echo "[!] Failed to copy SpaceAdventure_obf.py! Check Termux storage permissions."
    # Optionally exit here if the file is critical: exit 1
  fi
else
  echo "[!] SpaceAdventure_obf.py not found in $DOWNLOADS_PATH!"
  # Optionally exit here: exit 1
fi

if [[ -f "$DOWNLOADS_PATH/data.txt" ]]; then
  if cp "$DOWNLOADS_PATH/data.txt" "$UBUNTU_ROOTFS_PATH/"; then
    echo "[✓] Copied data.txt to Ubuntu container."
  else
    echo "[!] Failed to copy data.txt! Check Termux storage permissions."
    # Optionally exit here: exit 1
  fi
else
  echo "[!] data.txt not found in $DOWNLOADS_PATH!"
  # Optionally exit here: exit 1
fi

echo "[*] Creating 'spacebot' launcher alias in ~/.bashrc..."
BASHRC_ALIAS='alias spacebot='\''proot-distro login ubuntu -- bash -c "cd ~ && source spacebotenv/bin/activate && python SpaceAdventure_obf.py"'\'''
if ! grep -q 'alias spacebot=' ~/.bashrc; then
  echo "$BASHRC_ALIAS" >> ~/.bashrc
  echo "[✓] Alias added. Restart Termux or run 'source ~/.bashrc', then run: spacebot"
else
  echo "[i] Alias 'spacebot' already exists."
fi

# source ~/.bashrc # Sourcing here only affects the *current* script session, not the user's main Termux session.

echo
echo "----------------------------------------------"
echo "✅ All done! Setup script finished."
echo "   To run the bot:"
echo "   1. Close and reopen Termux (or run 'source ~/.bashrc')."
echo "   2. Type the command: spacebot"
echo "----------------------------------------------"
echo "🎉 Script, environment, and launcher should be ready!"
echo "(If you encounter issues, try running the setup steps manually)"
