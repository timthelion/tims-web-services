#!/bin/bash
# Custom patches applied at container startup
# https://docker-mailserver.github.io/docker-mailserver/latest/config/advanced/override-defaults/user-patches/

# Configure postfix to use hobbs.cz as the mail domain
postconf -e "myhostname = mail.hobbs.cz"
postconf -e "mydomain = hobbs.cz"

# Ensure proper TLS configuration
postconf -e "smtpd_tls_cert_file = /etc/letsencrypt/live/imap.hobbs.cz/fullchain.pem"
postconf -e "smtpd_tls_key_file = /etc/letsencrypt/live/imap.hobbs.cz/privkey.pem"

# Shorter milter timeouts to prevent hanging if opendkim is slow
postconf -e "milter_connect_timeout = 5s"
postconf -e "milter_command_timeout = 5s"
postconf -e "milter_content_timeout = 30s"
