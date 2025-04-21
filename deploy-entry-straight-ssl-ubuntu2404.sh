#!/bin/bash
set -e

SUDO_PASS="$1"
DOMAIN="$2"
DOMAIN_A="$3"
DOMAIN_EMAIL="$4"
GANDI_LIVEDNS_TOKEN="$5"

echo "$SUDO_PASS" | sudo -S apt-get -y update
echo "$SUDO_PASS" | sudo -S apt-get -y dist-upgrade
echo "$SUDO_PASS" | sudo -S apt-get -y autoclean
echo "$SUDO_PASS" | sudo -S apt-get -y autoremove

# --- Nginx 1 ---

echo "$SUDO_PASS" | sudo -S apt-get -y install git nginx

# --- acme.sh ---

if [ -d "/tmp/acme.sh" ]; then
    echo "Directory exists. Deleting..."
    rm -rf /tmp/acme.sh
fi

git clone https://github.com/acmesh-official/acme.sh.git /tmp/acme.sh
pushd /tmp/acme.sh
./acme.sh --install -m $DOMAIN_EMAIL
source ~/.bashrc
popd

# Only for remote
export PATH="$HOME/.acme.sh:$PATH"

acme.sh --set-default-ca --server letsencrypt
export GANDI_LIVEDNS_TOKEN=$GANDI_LIVEDNS_TOKEN

if acme.sh --list | grep -q "$DOMAIN" && acme.sh --list | grep -q "\*\.$DOMAIN"; then
    echo "The $DOMAIN, *.$DOMAIN exited, skip"
else
    acme.sh --issue --dns dns_gandi_livedns --server letsencrypt -d $DOMAIN -d *.$DOMAIN -k 4096
    acme.sh --issue --dns dns_gandi_livedns --server letsencrypt -d $DOMAIN -d *.$DOMAIN -k ec-384
fi

acme.sh --list
sudo mkdir -p /etc/letsencrypt/cert/$DOMAIN
sudo mkdir -p /etc/letsencrypt/cert/$DOMAIN/ecc

acme.sh --install-cert -d $DOMAIN \
--cert-file /etc/letsencrypt/cert/$DOMAIN/cert.pem \
--key-file /etc/letsencrypt/cert/$DOMAIN/private.key \
--fullchain-file /etc/letsencrypt/cert/$DOMAIN/fullchain.pem \
--ca-file /etc/letsencrypt/cert/$DOMAIN/chain.pem \
--reloadcmd "sudo systemctl reload nginx.service"

acme.sh --install-cert -d $DOMAIN --ecc \
--cert-file /etc/letsencrypt/cert/$DOMAIN/ecc/cert.pem \
--key-file /etc/letsencrypt/cert/$DOMAIN/ecc/private.key \
--fullchain-file /etc/letsencrypt/cert/$DOMAIN/ecc/fullchain.pem \
--reloadcmd "sudo systemctl reload nginx.service"

acme.sh --upgrade --auto-upgrade

# --- Nginx 2 ---

if [ -L "/etc/nginx/sites-enabled/default" ]; then
    echo "The default sites-enabled exists. Deleting..."
    rm -f /etc/nginx/sites-enabled/default
fi
if [ -f "/etc/nginx/sites-available/default" ]; then
    echo "The default sites-available exists. Deleting..."
    rm -f /etc/nginx/sites-available/default
fi

NGINX_CONFIG=hawkbit-ssl.nginx
echo "Checking: /etc/nginx/sites-enabled/$NGINX_CONFIG"
ls -l "/etc/nginx/sites-enabled/$NGINX_CONFIG"
if [ -L "/etc/nginx/sites-enabled/$NGINX_CONFIG" ]; then
    echo "The $NGINX_CONFIG sites-enabled exists. Deleting..."
    rm -f /etc/nginx/sites-enabled/$NGINX_CONFIG
fi
echo "Checking: /etc/nginx/sites-available/$NGINX_CONFIG"
ls -l "/etc/nginx/sites-available/$NGINX_CONFIG"
if [ -f "/etc/nginx/sites-available/$NGINX_CONFIG" ]; then
    echo "The $NGINX_CONFIG sites-available exists. Deleting..."
    rm -f /etc/nginx/sites-available/$NGINX_CONFIG
fi
sudo tee /etc/nginx/sites-available/$NGINX_CONFIG > /dev/null <<EOF
server
{
    listen 80;
    listen [::]:80;
    server_name $DOMAIN_A.$DOMAIN;
    return 301 https://$DOMAIN_A.$DOMAIN\$request_uri;
}

server
{
    listen 443 ssl http2;
    listen [::]:443 ssl http2;
    server_name $DOMAIN_A.$DOMAIN;

    location /
    {
        proxy_set_header Host \$host;
        proxy_set_header X-Forwarded-For \$remote_addr;
        proxy_set_header X-Forwarded-Proto https;

        proxy_connect_timeout 60s;
        proxy_send_timeout 600s;
        proxy_read_timeout 600s;
        send_timeout 600s;

        proxy_pass http://127.0.0.1:8080/;
    }

    #RSA
    ssl_certificate /etc/letsencrypt/cert/$DOMAIN/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/cert/$DOMAIN/private.key;
    #ECC/ECDSA
    ssl_certificate /etc/letsencrypt/cert/$DOMAIN/ecc/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/cert/$DOMAIN/ecc/private.key;
    ssl_ecdh_curve X25519:secp384r1;
    ssl_session_cache shared:SSL:50m;
    ssl_session_timeout 1440m;
    ssl_session_tickets off;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers TLS13-AES-256-GCM-SHA384:TLS13-CHACHA20-POLY1305-SHA256:TLS13-AES-128-GCM-SHA256:TLS13-AES-128-CCM-8-SHA256:TLS13-AES-128-CCM-SHA256:EECDH+CHACHA20:EECDH+CHACHA20-draft:EECDH+ECDSA+AES128:EECDH+aRSA+AES128:RSA+AES128:EECDH+ECDSA+AES256:EECDH+aRSA+AES256:RSA+AES256:EECDH+ECDSA+3DES:EECDH+aRSA+3DES:RSA+3DES:!MD5;
    ssl_prefer_server_ciphers on;
    ssl_stapling on;
    ssl_stapling_verify on;
    ssl_trusted_certificate /etc/letsencrypt/cert/$DOMAIN/chain.pem;
    add_header Strict-Transport-Security "max-age=31536000; preload";
}
EOF

sudo ln -s /etc/nginx/sites-available/$NGINX_CONFIG /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx

sudo reboot
