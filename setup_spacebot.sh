#!/data/data/com.termux/files/usr/bin/bash

# Exit immediately if a command exits with a non-zero status.
set -e

# --- Configuration ---
SCRIPT_FILE="SpaceAdventure_obf.py" # Or SpaceAdventure.py if you rename it back
DATA_FILE="data.txt"
PYTHON_VENV_DIR="spacebotenv"
UBUNTU_DISTRO_NAME="ubuntu" # Or e.g., ubuntu-22.04 if you specifically need an older one

# --- Helper Function for Logging ---
log_info() { echo "[*] $1"; }
log_success() { echo "[✓] $1"; }
log_warning() { echo "[!] $1"; }
log_error() { echo "[✗] $1"; }
log_fatal() { echo "[🔥] $1"; exit 1; }

# --- Main Setup Logic ---
log_info "Welcome to the SpaceBot Automated Setup!"
log_info "Requesting Storage Permission (Grant if prompted)..."
termux-setup-storage
sleep 3 # Give time for the popup

log_info "Updating Termux and installing base dependencies..."
# Force non-interactive and keep existing config files on conflict
export DEBIAN_FRONTEND=noninteractive
pkg update -y -o Dpkg::Options::="--force-confold" || log_warning "pkg update failed, continuing..."
pkg upgrade -y -o Dpkg::Options::="--force-confold" || log_warning "pkg upgrade failed, continuing..."
pkg install proot-distro wget curl nano -y -o Dpkg::Options::="--force-confold" || log_fatal "Failed to install base Termux packages."
log_success "Termux dependencies installed."

log_info "Checking if Ubuntu ($UBUNTU_DISTRO_NAME) container exists..."
if ! proot-distro list | grep -q "$UBUNTU_DISTRO_NAME"; then
    log_info "Installing Ubuntu ($UBUNTU_DISTRO_NAME) container (this might take a while)..."
    proot-distro install "$UBUNTU_DISTRO_NAME" || log_fatal "Failed to install Ubuntu container."
    log_success "Ubuntu container installed."
else
    log_info "Ubuntu ($UBUNTU_DISTRO_NAME) container already installed."
fi

log_info "Setting up Python environment inside Ubuntu..."
# Execute the setup commands within the Ubuntu container
proot-distro login "$UBUNTU_DISTRO_NAME" -- bash -c '
# Exit on error inside the container too
set -e
export DEBIAN_FRONTEND=noninteractive

log_info_ubuntu() { echo "[Ubuntu] [*] $1"; }
log_success_ubuntu() { echo "[Ubuntu] [✓] $1"; }
log_warning_ubuntu() { echo "[Ubuntu] [!] $1"; }
log_error_ubuntu() { echo "[Ubuntu] [✗] $1"; }
log_fatal_ubuntu() { echo "[Ubuntu] [🔥] $1"; exit 1; }

log_info_ubuntu "Updating package lists..."
apt-get update -y || log_warning_ubuntu "apt-get update failed, continuing..."

log_info_ubuntu "Installing Python 3, venv, pip, build tools, and Playwright system dependencies..."
# Use default python3 packages for the installed Ubuntu version
apt-get install -y python3 python3-venv python3-pip \
    build-essential curl wget nano \
    libnss3 libnspr4 libatk1.0-0t64 libatspi2.0-0t64 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 \
    libxkbcommon0 libasound2t64 \
    software-properties-common || log_fatal_ubuntu "Failed to install Python or system dependencies via apt."
log_success_ubuntu "System dependencies installed."

VENV_PATH=~/'"$PYTHON_VENV_DIR"' # Pass variable from outer script

if [ -d "$VENV_PATH" ]; then
    log_info_ubuntu "Virtual environment '$PYTHON_VENV_DIR' already exists."
else
    log_info_ubuntu "Creating Python virtual environment '$PYTHON_VENV_DIR'..."
    python3 -m venv "$VENV_PATH" || log_fatal_ubuntu "Failed to create Python virtual environment."
    log_success_ubuntu "Virtual environment created."
fi

log_info_ubuntu "Activating virtual environment and upgrading pip..."
source "$VENV_PATH/bin/activate"
python -m pip install --upgrade pip || log_warning_ubuntu "Failed to upgrade pip."
log_success_ubuntu "Pip ready."

log_info_ubuntu "Installing Python packages (Playwright, requests, etc.)..."
pip install --no-cache-dir playwright requests pyfiglet aiohttp colorama rich || log_fatal_ubuntu "Failed to install Python packages via pip."
log_success_ubuntu "Python packages installed."

log_info_ubuntu "Installing Playwright browser binaries (this can take a long time)..."
playwright install --with-deps || log_fatal_ubuntu "Failed to install Playwright browsers. Check network and storage."
log_success_ubuntu "Playwright browsers installed."

log_success_ubuntu "Ubuntu environment setup complete."
exit 0
' || log_fatal "Ubuntu setup script block failed!" # Check if the proot-distro command block succeeded

# --- Back in Termux ---
UBUNTU_ROOT_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/$UBUNTU_DISTRO_NAME/root"
DOWNLOADS_DIR="/storage/emulated/0/Download"

log_info "Checking for script file '$SCRIPT_FILE' in Downloads..."
if [[ -f "$DOWNLOADS_DIR/$SCRIPT_FILE" ]]; then
  if cp "$DOWNLOADS_DIR/$SCRIPT_FILE" "$UBUNTU_ROOT_DIR/"; then
    log_success "Copied $SCRIPT_FILE to Ubuntu container."
  else
    log_error "Failed to copy $SCRIPT_FILE! Check Termux storage permissions."
    # Decide if this is fatal or just a warning
    log_warning "Script may not run correctly without $SCRIPT_FILE."
  fi
else
  log_warning "$SCRIPT_FILE not found in $DOWNLOADS_DIR! Please download it first."
  log_warning "Script will likely fail without $SCRIPT_FILE."
fi

log_info "Checking for data file '$DATA_FILE' in Downloads..."
if [[ -f "$DOWNLOADS_DIR/$DATA_FILE" ]]; then
  if cp "$DOWNLOADS_DIR/$DATA_FILE" "$UBUNTU_ROOT_DIR/"; then
    log_success "Copied $DATA_FILE to Ubuntu container."
  else
    log_error "Failed to copy $DATA_FILE! Check Termux storage permissions."
    log_warning "Script may not run correctly without $DATA_FILE."
  fi
else
  log_warning "$DATA_FILE not found in $DOWNLOADS_DIR! The bot might need this file."
fi

log_info "Creating 'spacebot' launcher alias in ~/.bashrc..."
# Use single quotes for the alias value to prevent premature expansion
# Escape inner single quotes needed for the bash -c command
ALIAS_CMD="proot-distro login '$UBUNTU_DISTRO_NAME' --user root --shared-tmp -- bash -c 'cd ~ && source \"$PYTHON_VENV_DIR/bin/activate\" && python \"$SCRIPT_FILE\"'"
ALIAS_ENTRY="alias spacebot='$ALIAS_CMD'"

# Remove old alias if exists, then add new one
sed -i '/alias spacebot=/d' ~/.bashrc
echo "$ALIAS_ENTRY" >> ~/.bashrc
log_success "Alias 'spacebot' added/updated in ~/.bashrc."
log_info "You MUST restart Termux or run 'source ~/.bashrc' for the alias to work."

echo
log_success "----------------------------------------------"
log_success "✅ All done! Setup script finished."
log_success "   To run the bot:"
log_success "   1. Ensure '$SCRIPT_FILE' and '$DATA_FILE' are in '$UBUNTU_ROOT_DIR'."
log_success "   2. Close and reopen Termux (or run 'source ~/.bashrc')."
log_success "   3. Type the command: spacebot"
log_success "----------------------------------------------"
log_info "(If setup failed, scroll up to see [✗] or [🔥] errors)"

exit 0
