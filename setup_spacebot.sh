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
playwright install

echo "[✅] Ubuntu + Python + Playwright setup complete."
exit
EOS

echo "[*] Checking for SpaceAdventure_obf.py and data.txt in Downloads..."
if [[ -f /storage/emulated/0/Download/SpaceAdventure_obf.py ]]; then
  cp /storage/emulated/0/Download/SpaceAdventure_obf.py ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/root/
  echo "[✓] Moved SpaceAdventure_obf.py"
else
  echo "[!] SpaceAdventure_obf.py not found in Downloads!"
fi

if [[ -f /storage/emulated/0/Download/data.txt ]]; then
  cp /storage/emulated/0/Download/data.txt ~/../usr/var/lib/proot-distro/installed-rootfs/ubuntu/root/
  echo "[✓] Moved data.txt"
else
  echo "[!] data.txt not found in Downloads!"
fi

echo "[*] Creating spacebot launcher alias in ~/.bashrc"
if ! grep -q 'alias spacebot=' ~/.bashrc; then
  echo "alias spacebot='proot-distro login ubuntu -- bash -c \"cd ~ && source spacebotenv/bin/activate && python SpaceAdventure_obf.py\"'" >> ~/.bashrc
  echo "[✓] Alias added. You can now run: spacebot"
else
  echo "[i] Alias already exists."
fi

source ~/.bashrc

echo
echo "✅ All done! To run the bot anytime, just type:"
echo "----------------------------------------------"
echo "spacebot"
echo "----------------------------------------------"
echo "🎉 Script, environment, and launcher are ready!"
