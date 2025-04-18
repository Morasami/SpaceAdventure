#!/data/data/com.termux/files/usr/bin/bash


set -e


SCRIPT_FILE="SpaceAdventure_obf.py" 
DATA_FILE="data.txt"
PYTHON_VENV_DIR="spacebotenv"
UBUNTU_DISTRO_NAME="ubuntu" 


log_info() { echo "[*] $1"; }
log_success() { echo "[✓] $1"; }
log_warning() { echo "[!] $1"; }
log_error() { echo "[✗] $1"; }
log_fatal() { echo "[🔥] $1"; exit 1; }


log_info "Welcome to the SpaceBot Automated Setup!"

log_info "Checking Termux storage setup..."

if [ -L "$HOME/storage/shared" ] || [ -d "$HOME/storage/shared" ]; then
    log_info "Storage appears to be already set up."
else
    log_warning "Storage not detected or link missing."
    log_info "Requesting Storage Permission (Grant if prompted)..."

    termux-setup-storage || log_warning "termux-setup-storage command finished (may have aborted if already configured, this is usually OK)."
    sleep 3 

    if [ ! -L "$HOME/storage/shared" ] && [ ! -d "$HOME/storage/shared" ]; then
         log_error "Storage setup failed or permission was denied. File operations may fail."


    else
         log_success "Storage setup confirmed/requested."
    fi
fi


log_info "Updating Termux and installing base dependencies..."

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


proot-distro login "$UBUNTU_DISTRO_NAME" --user root --shared-tmp -- bash -c '
# Exit on error inside the container too
set -e
export DEBIAN_FRONTEND=noninteractive

# Define logging functions inside the container scope
log_info_ubuntu() { echo "[Ubuntu] [*] $1"; }
log_success_ubuntu() { echo "[Ubuntu] [✓] $1"; }
log_warning_ubuntu() { echo "[Ubuntu] [!] $1"; }
log_error_ubuntu() { echo "[Ubuntu] [✗] $1"; }
log_fatal_ubuntu() { echo "[Ubuntu] [🔥] $1"; exit 1; }

log_info_ubuntu "Updating package lists..."
apt-get update -y || log_warning_ubuntu "apt-get update failed, continuing..."

log_info_ubuntu "Installing Python 3, venv, pip, build tools, and Playwright system dependencies..."
# Use default python3 packages for the installed Ubuntu version
# Added --no-install-recommends to potentially speed up and reduce size
apt-get install -y --no-install-recommends python3 python3-venv python3-pip \
    build-essential curl wget nano \
    libnss3 libnspr4 libatk1.0-0t64 libatspi2.0-0t64 \
    libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 \
    libxkbcommon0 libasound2t64 \
    software-properties-common || log_fatal_ubuntu "Failed to install Python or system dependencies via apt."
log_success_ubuntu "System dependencies installed."

VENV_PATH=~/'"$PYTHON_VENV_DIR"' # Get venv path relative to user home inside container

if [ -d "$VENV_PATH" ]; then
    log_info_ubuntu "Virtual environment '$PYTHON_VENV_DIR' already exists."
else
    log_info_ubuntu "Creating Python virtual environment '$PYTHON_VENV_DIR'..."
    python3 -m venv "$VENV_PATH" || log_fatal_ubuntu "Failed to create Python virtual environment."
    log_success_ubuntu "Virtual environment created."
fi

log_info_ubuntu "Activating virtual environment and upgrading pip..."
source "$VENV_PATH/bin/activate"
# Use python -m pip for consistency
python -m pip install --upgrade pip || log_warning_ubuntu "Failed to upgrade pip."
log_success_ubuntu "Pip ready."

log_info_ubuntu "Installing Python packages (Playwright, requests, etc.)..."
# --no-cache-dir can help on low-storage devices
pip install --no-cache-dir playwright requests pyfiglet aiohttp colorama rich || log_fatal_ubuntu "Failed to install Python packages via pip."
log_success_ubuntu "Python packages installed."

log_info_ubuntu "Installing Playwright browser binaries & dependencies (this can take a long time)..."
# Use --with-deps to attempt automatic dependency installation first
playwright install --with-deps || log_fatal_ubuntu "Failed to install Playwright browsers. Check network and storage."
log_success_ubuntu "Playwright browsers installed."

log_success_ubuntu "Ubuntu environment setup complete."
exit 0
' || log_fatal "Ubuntu setup script block failed!" 


UBUNTU_ROOT_DIR="$PREFIX/var/lib/proot-distro/installed-rootfs/$UBUNTU_DISTRO_NAME/root"
DOWNLOADS_DIR="/storage/emulated/0/Download"

log_info "Checking for script file '$SCRIPT_FILE' in Downloads..."
if [[ -f "$DOWNLOADS_DIR/$SCRIPT_FILE" ]]; then
  if cp "$DOWNLOADS_DIR/$SCRIPT_FILE" "$UBUNTU_ROOT_DIR/"; then
    log_success "Copied $SCRIPT_FILE to Ubuntu container."
  else
    log_error "Failed to copy $SCRIPT_FILE! Check Termux storage permissions."
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
BASHRC_FILE="$HOME/.bashrc"
ALIAS_NAME="spacebot"


ALIAS_ENTRY="alias $ALIAS_NAME='proot-distro login $UBUNTU_DISTRO_NAME --user root --shared-tmp -- bash -c \"cd \\\$HOME && source $PYTHON_VENV_DIR/bin/activate && python $SCRIPT_FILE\"'"


touch "$BASHRC_FILE" || log_warning "Could not create $BASHRC_FILE"


if grep -Fq "alias ${ALIAS_NAME}='proot-distro login" "$BASHRC_FILE"; then
    log_info "Alias '$ALIAS_NAME' seems to already exist in $BASHRC_FILE."


else
    log_info "Adding alias '$ALIAS_NAME' to $BASHRC_FILE..."

    echo "$ALIAS_ENTRY" >> "$BASHRC_FILE" || log_error "Failed to add alias to $BASHRC_FILE!"
    log_success "Alias '$ALIAS_NAME' added."
fi
log_info "You MUST restart Termux or run 'source $BASHRC_FILE' for the alias to work."



echo
log_success "----------------------------------------------"
log_success "✅ All done! Setup script finished."
log_success "   To run the bot:"
log_success "   1. Ensure '$SCRIPT_FILE' and '$DATA_FILE' are in the Ubuntu home directory (~/)."
log_success "   2. Close and reopen Termux (or run 'source ~/.bashrc')."
log_success "   3. Type the command: spacebot"
log_success "----------------------------------------------"
log_info "(If setup failed, scroll up to see [✗] or [🔥] errors)"

exit 0
