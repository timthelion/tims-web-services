# Mail Server Migration Guide

This document describes how to migrate from the existing exim4/dovecot setup to docker-mailserver.

## Pre-Migration Checklist

- [ ] Backup existing mail data
- [ ] Backup existing configuration
- [ ] Test the new setup on a staging environment if possible
- [ ] Plan a maintenance window (email will be unavailable during migration)

## Migration Steps

### 1. Prepare the Server

```bash
# Create required directories on the server
ssh root@hobbs.cz "mkdir -p /root/mail-data /root/mail-state /root/mail-logs"

# Copy the updated tims-web-services repo to the server
# (from your local machine)
rsync -avz /home/timothy/pr/personal/tims-web-services/ root@hobbs.cz:/root/tims-web-services/
```

### 2. Copy DKIM Private Key

The existing DKIM key needs to be copied to the new location:

```bash
ssh root@hobbs.cz "mkdir -p /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz && \
  cp /etc/exim4/dkim.private.key /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz/29022016.private && \
  chmod 600 /root/tims-web-services/mail-config/config/opendkim/keys/hobbs.cz/29022016.private"
```

### 3. Create User Passwords

Generate proper password hashes for the mail accounts:

```bash
ssh root@hobbs.cz

# Pull the docker-mailserver image first
docker pull ghcr.io/docker-mailserver/docker-mailserver:latest

# Add users with passwords (you'll be prompted for passwords)
docker run --rm -it \
  -v /root/tims-web-services/mail-config/config/:/tmp/docker-mailserver/ \
  ghcr.io/docker-mailserver/docker-mailserver setup email add timothy@hobbs.cz

docker run --rm -it \
  -v /root/tims-web-services/mail-config/config/:/tmp/docker-mailserver/ \
  ghcr.io/docker-mailserver/docker-mailserver setup email add denisa@hobbs.cz
```

### 4. Convert Mail from mbox to Maildir

The current setup uses mbox format, but docker-mailserver uses Maildir. You need to convert:

```bash
ssh root@hobbs.cz

# Install mb2md if not present
apt-get install mb2md

# Convert timothy's mail
mkdir -p /root/mail-data/hobbs.cz/timothy/
mb2md -s /var/mail/timothy -d /root/mail-data/hobbs.cz/timothy/

# Convert timothy's folders
for folder in /home/timothy/mail/*; do
  name=$(basename "$folder")
  mb2md -s "$folder" -d "/root/mail-data/hobbs.cz/timothy/.$name/"
done

# Convert denisa's mail
mkdir -p /root/mail-data/hobbs.cz/denisa/
mb2md -s /var/mail/denisa -d /root/mail-data/hobbs.cz/denisa/

# Convert denisa's folders
for folder in /home/denisa/mail/*; do
  name=$(basename "$folder")
  mb2md -s "$folder" -d "/root/mail-data/hobbs.cz/denisa/.$name/"
done

# Fix permissions
chown -R 5000:5000 /root/mail-data/
```

### 5. Stop Existing Services

```bash
ssh root@hobbs.cz "systemctl stop exim4 dovecot && systemctl disable exim4 dovecot"
```

### 6. Start docker-mailserver

```bash
ssh root@hobbs.cz "cd /root/tims-web-services && docker compose up -d mailserver"
```

### 7. Verify the Setup

```bash
# Check container logs
docker logs mailserver

# Test SMTP
telnet mail.hobbs.cz 25

# Test IMAP
openssl s_client -connect mail.hobbs.cz:993

# Send a test email
docker exec -ti mailserver setup email debug send test@example.com
```

### 8. DNS Verification

Ensure DNS records are correct:

- **MX Record**: `hobbs.cz` -> `mail.hobbs.cz` (or existing record)
- **A Record**: `mail.hobbs.cz` -> server IP
- **SPF**: `v=spf1 mx a ~all` (or your existing SPF)
- **DKIM**: The existing DKIM record should work since we're using the same key
- **DMARC**: Optional, e.g., `v=DMARC1; p=none; rua=mailto:postmaster@hobbs.cz`

## Rollback Plan

If something goes wrong:

```bash
# Stop the container
docker compose down mailserver

# Re-enable and start the old services
systemctl enable exim4 dovecot
systemctl start exim4 dovecot
```

## Ports Used

- **25**: SMTP (for receiving mail)
- **143**: IMAP (unencrypted, STARTTLS)
- **465**: SMTPS (implicit TLS)
- **587**: Submission (STARTTLS)
- **993**: IMAPS (implicit TLS)
- **4190**: ManageSieve

## Troubleshooting

### View Logs
```bash
docker logs -f mailserver
# Or specific service logs
docker exec -ti mailserver cat /var/log/mail/mail.log
```

### Test Email Delivery
```bash
docker exec -ti mailserver setup email test timothy@hobbs.cz
```

### Regenerate DKIM Keys (if needed)
```bash
docker exec -ti mailserver setup config dkim
# Then update DNS with the new key
```

### Check Configuration
```bash
docker exec -ti mailserver setup check
```
