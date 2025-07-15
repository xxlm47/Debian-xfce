#!/data/data/com.termux/files/usr/bin/bash

set -e

echo
echo "==== Termux Debian XFCE Automated Installer (X11 Only) ===="
echo

# 1. Update Termux and install dependencies
pkg update -y
pkg install -y proot-distro wget tar

# 2. Ask for username
read -p "Enter your desired Debian username: " debuser

# 3. Install Debian via proot-distro if not already installed
if [ ! -d "$PREFIX/var/lib/proot-distro/installed-rootfs/debian" ]; then
    proot-distro install debian
fi

# 4. Create setup script for debian
cat > $PREFIX/var/lib/proot-distro/installed-rootfs/debian/root/setup-xfce.sh <<'EOF'
#!/bin/bash

set -e
export DEBIAN_FRONTEND=noninteractive

# Add user if not exists
USERNAME="__REPLACE_USERNAME__"
id -u $USERNAME 2>/dev/null || useradd -m -s /bin/bash $USERNAME

# Update and install X11, XFCE4, sudo, nano, wget, dbus-x11, x11-apps
apt-get update
apt-get install -y xfce4 xfce4-terminal dbus-x11 sudo nano wget x11-apps

# Allow user to sudo without password
echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/$USERNAME

# App installer script (for inside Debian)
cat > /home/$USERNAME/app-installer.sh <<'EOL'
#!/bin/bash
set -e
while true; do
    echo "===== App Installer Menu ====="
    echo "1) Firefox"
    echo "2) GIMP"
    echo "3) LibreOffice"
    echo "4) VSCode"
    echo "5) Return"
    read -p "Choose an app to install [1-5]: " ch
    case "$ch" in
        1) sudo apt-get update && sudo apt-get install -y firefox-esr ;;
        2) sudo apt-get update && sudo apt-get install -y gimp ;;
        3) sudo apt-get update && sudo apt-get install -y libreoffice ;;
        4) sudo apt-get update && sudo apt-get install -y code ;;
        5) break ;;
        *) echo "Invalid option";;
    esac
done
EOL
chmod +x /home/$USERNAME/app-installer.sh
chown $USERNAME:$USERNAME /home/$USERNAME/app-installer.sh

# Set up XFCE4 start script for X11
cat > /home/$USERNAME/startxfce-x11.sh <<'EOL'
#!/bin/bash
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
dbus-launch startxfce4
EOL
chmod +x /home/$USERNAME/startxfce-x11.sh
chown $USERNAME:$USERNAME /home/$USERNAME/startxfce-x11.sh

echo
echo "== SETUP COMPLETE! =="
echo "To start XFCE4 with X11, run: ./startxfce-x11.sh"
echo "Make sure your X11 server (like XSDL or Termux X11) is running first."
echo
EOF

# Replace username placeholder in setup-xfce.sh
sed -i "s/__REPLACE_USERNAME__/$debuser/g" $PREFIX/var/lib/proot-distro/installed-rootfs/debian/root/setup-xfce.sh

# 5. Run the setup-xfce.sh inside Debian
proot-distro login debian --root -- bash /root/setup-xfce.sh

# 6. Create a start script in Termux for easy launch
cat > $PREFIX/bin/startdebian-xfce <<EOL
#!/data/data/com.termux/files/usr/bin/bash
proot-distro login debian --user $debuser --shared-tmp -- bash -c '
export DISPLAY=:0
export PULSE_SERVER=127.0.0.1
echo "If using XSDL or Termux X11, ensure it is running before continuing."
echo "To start XFCE desktop: ./startxfce-x11.sh"
echo "To install apps: ./app-installer.sh"
bash
'
EOL
chmod +x $PREFIX/bin/startdebian-xfce

echo
echo "==== INSTALLATION DONE ===="
echo "To start Debian XFCE4 desktop, run: startdebian-xfce"
echo "Inside Debian, run: ./startxfce-x11.sh to launch the desktop"
echo "Inside Debian, run: ./app-installer.sh to install GUI apps"
echo