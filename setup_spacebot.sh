#!/data/data/com.termux/files/usr/bin/bash

echo "[*] Updating Termux and installing Ubuntu via proot-distro..."
pkg update -y && pkg upgrade -y
pkg install proot-distro wget curl nano -y

echo "[*] Installing Ubuntu container..."
proot-distro install ubuntu

echo "[*] Logging into Ubuntu to finish setup..."
proot-distro login ubuntu << 'EOS'
echo "[*] Updating and installing Python 3.11 + system dependencies..."
apt update && apt install -y python3.11 python3.11-venv python3.11-distutils \
build-essential curl wget nano libnss3 libnspr4 libatk1.0-0t64 libatspi2.0-0t64 \
libxcomposite1 libxdamage1 libxext6 libxfixes3 libxrandr2 libgbm1 libxkbcommon0 \
libasound2t64 software-properties-common

echo "[*] Creating Python virtual environment..."
python3.11 -m venv ~/spacebotenv
source ~/spacebotenv/bin/activate

echo "[*] Installing pip and required Python packages..."
curl -sS https://bootstrap.pypa.io/get-pip.py | python
pip install playwright requests pyfiglet aiohttp colorama rich

echo "[*] Installing Playwright browser binaries..."
playwright install

echo "[✅] Setup complete!"
echo ""
echo "🚨 FINAL STEP: In Termux (not Ubuntu), run these commands:"
echo "cp /storage/emulated/0/Download/SpaceAdventure.py ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/root/"
echo "cp /storage/emulated/0/Download/data.txt ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/root/"
echo ""
echo "📦 Then to run the script daily:"
echo "--------------------------------------"
echo "proot-distro login ubuntu"
echo "cd ~"
echo "source spacebotenv/bin/activate"
echo "python SpaceAdventure.py"
echo "--------------------------------------"
exit
EOS
