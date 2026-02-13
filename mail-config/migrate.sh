#!/bin/bash
# Migration script for exim4/dovecot to docker-mailserver
# Run this script on the server (hobbs.cz) as root

set -e

echo "=== Mail Server Migration Script ==="
echo ""

# Check if running as root
if [ "$EUID" -ne 0 ]; then
  echo "Please run as root"
  exit 1
fi

# Create directories
echo "[1/7] Creating directories..."
mkdir -p /root/mail-data /root/mail-state /root/mail-logs
mkdir -p /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz

# Copy DKIM key
echo "[2/7] Copying DKIM private key..."
if [ -f /etc/exim4/dkim.private.key ]; then
  cp /etc/exim4/dkim.private.key /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz/29022016.private
  chmod 600 /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz/29022016.private
  echo "  DKIM key copied successfully"
else
  echo "  WARNING: DKIM key not found at /etc/exim4/dkim.private.key"
fi

# Pull docker image
echo "[3/7] Pulling docker-mailserver image..."
docker pull ghcr.io/docker-mailserver/docker-mailserver:latest

# Install mb2md if needed
echo "[4/7] Installing mb2md for mail conversion..."
apt-get update -qq && apt-get install -y -qq mb2md

# Convert mail
echo "[5/7] Converting mail from mbox to Maildir..."
for user in timothy denisa; do
  echo "  Converting $user's mail..."
  domain_dir="/root/mail-data/hobbs.cz/$user"
  mkdir -p "$domain_dir"

  # Convert INBOX
  if [ -f "/var/mail/$user" ]; then
    mb2md -s "/var/mail/$user" -d "$domain_dir/"
    echo "    INBOX converted"
  fi

  # Convert folders
  if [ -d "/home/$user/mail" ]; then
    for folder in /home/$user/mail/*; do
      if [ -f "$folder" ]; then
        name=$(basename "$folder")
        mb2md -s "$folder" -d "$domain_dir/.$name/"
        echo "    Folder $name converted"
      fi
    done
  fi
done

# Fix permissions (docker-mailserver uses uid 5000)
echo "[6/7] Setting permissions..."
chown -R 5000:5000 /root/mail-data/

echo "[7/7] Migration preparation complete!"
echo ""
echo "=== Next Steps ==="
echo "1. Create user passwords:"
echo "   docker run --rm -it -v /root/tims-web-services/mail-config/config/:/tmp/docker-mailserver/ ghcr.io/docker-mailserver/docker-mailserver setup email add timothy@hobbs.cz"
echo "   docker run --rm -it -v /root/tims-web-services/mail-config/config/:/tmp/docker-mailserver/ ghcr.io/docker-mailserver/docker-mailserver setup email add denisa@hobbs.cz"
echo ""
echo "2. Stop old services:"
echo "   systemctl stop exim4 dovecot && systemctl disable exim4 dovecot"
echo ""
echo "3. Start docker-mailserver:"
echo "   cd /root/tims-web-services && docker compose up -d mailserver"
echo ""
echo "4. Check logs:"
echo "   docker logs -f mailserver"
