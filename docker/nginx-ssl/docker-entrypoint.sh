#!/usr/bin/env bash
export PS4='+ ${BASH_SOURCE}:${LINENO}: '
set -ex # Debug

export DOMAINS=$(echo "$SSL_DOMAINS" | tr -s ';')
export SSL_SERVER="$SSL_SERVER"
export EMAIL="$EMAIL"
export SSL_DIR="/etc/nginx/ssl"
export RELOAD_CMD="nginx -s reload"

if [ -z "$EMAIL" ]; then
    echo "[$(date)] Empty env var mail, set mail=\"email@example.com\""
    mail="email@example.com"
fi

if [ -z "$DOMAINS" ]; then
    echo "[$(date)] Empty env var SSL_DOMAINS"
fi

function CreateDefault() {
    # true if the file exists and is not empty
    if [ -s "${SSL_DIR}/fullchain.pem" ]; then
        echo "[$(date)] default cert exists in :${SSL_DIR}"
    else
        echo "[$(date)] create default cert to :${SSL_DIR}"
        openssl req -x509 -newkey rsa:4096 -nodes -days 365 \
            -subj "/C=CA/ST=QC/O=Company Inc/CN=example.com" \
            -out ${SSL_DIR}/default_fullchain.pem \
            -keyout ${SSL_DIR}/default_key.pem
        chmod +w ${SSL_DIR}/*
    fi
}

function StartAcmesh() {
    echo "[$(date)] sleep 5 second to start Acme.sh..."
    sleep 5
    echo "[$(date)] Start Acme.sh..."
    echo "[$(date)] DOMAINS :${DOMAINS}"
    echo "[$(date)] SSL_DIR :${SSL_DIR}"
    echo "[$(date)] EMAIL :${EMAIL}"
    echo "[$(date)] RELOAD_CMD :${RELOAD_CMD}"

    IFS=';'
    read -ra list <<<"$DOMAINS"

    ACME_OPTIONS=()
    ACME_DOMAIN_OPTION=()
    ACME_DOMAIN_OPTION_FIRST=()

    if [[ -n "$DNS" ]]; then
	      ACME_OPTIONS+=(--dns "$DNS")
            echo "[$(date)] Use dns plugin: $DNS"
        if [[ "$DNS" == "dns_gandi_livedns" ]]; then
            export GANDI_LIVEDNS_TOKEN=$API_KEY
        fi
    fi

    for i in "${!list[@]}"; do
	      ACME_DOMAIN_OPTION+=("-d" "${list[$i]}")
	      if [[ $i == 0 ]]; then
	  	      ACME_DOMAIN_OPTION_FIRST+=("-d" "${list[$i]}")
	      fi
    done

    echo "[$(date)] Issue the cert: $DOMAINS with options: $ACME_OPTIONS, $ACME_DOMAIN_OPTION"

    if [[ -n "$SSL_SERVER" ]]; then
        # Test env https://acme-staging-v02.api.letsencrypt.org/directory
        echo "Set Server"
        /root/.acme.sh/acme.sh --set-default-ca --server $SSL_SERVER
    fi

    echo "[$(date)] 1、acme.sh register .."
    /root/.acme.sh/acme.sh --register-account -m $EMAIL

    echo "[$(date)] 2、acme.sh issue .."
    echo "Parameters: ACME_OPTIONS=${ACME_OPTIONS[@]} ACME_DOMAIN_OPTION=${ACME_DOMAIN_OPTION[@]}"
    /root/.acme.sh/acme.sh --issue ${ACME_OPTIONS[@]} ${ACME_DOMAIN_OPTION[@]} --renew-hook "${RELOAD_CMD}" -k 4096
    /root/.acme.sh/acme.sh --issue ${ACME_OPTIONS[@]} ${ACME_DOMAIN_OPTION[@]} --renew-hook "${RELOAD_CMD}" -k ec-384
    /root/.acme.sh/acme.sh --list

    echo "[$(date)] 3、acme.sh install-cert .."

    /root/.acme.sh/acme.sh --install-cert ${ACME_DOMAIN_OPTION_FIRST[@]} \
        --fullchain-file ${SSL_DIR}/fullchain.pem \
        --cert-file "${SSL_DIR}/cert.pem" \
        --key-file "${SSL_DIR}/key.pem" \
        --ca-file "${SSL_DIR}/chain.pem" \
        --reloadcmd "${RELOAD_CMD}"

    /root/.acme.sh/acme.sh --install-cert ${ACME_DOMAIN_OPTION_FIRST[@]} --ecc \
        --fullchain-file ${SSL_DIR}/ecc/fullchain.pem \
        --cert-file "${SSL_DIR}/ecc/cert.pem" \
        --key-file "${SSL_DIR}/ecc/key.pem" \
        --ca-file "${SSL_DIR}/ecc/chain.pem" \
        --reloadcmd "${RELOAD_CMD}"

    echo "[$(date)] Start acme.sh crond "
    crond
}

# For Develop
function RunAcmesh() {
    echo "[$(date)] sleep 5 second to run Acme.sh..."
    sleep 5
    echo "[$(date)] Run Acme.sh..."
    echo "[$(date)] SSL_DOMAINS: ${SSL_DOMAINS}"
    echo "[$(date)] SSL_SERVER: ${SSL_SERVER}"
    echo "[$(date)] SSL_DIR: ${SSL_DIR}"
    echo "[$(date)] EMAIL: ${EMAIL}"
    echo "[$(date)] DNS: ${DNS}"
    echo "[$(date)] API_KEY: ${API_KEY}"
    echo "[$(date)] RELOAD_CMD: ${RELOAD_CMD}"
    echo "[$(date)] DOMAINS: ${DOMAINS}"

    IFS=';'
    read -ra list <<<"$DOMAINS"

    ACME_DOMAIN_OPTION=()
    ACME_DOMAIN_OPTION_FIRST=()
    for i in "${!list[@]}"; do
        ACME_DOMAIN_OPTION+=("-d" "${list[$i]}")
        if [[ $i == 0 ]]; then
            ACME_DOMAIN_OPTION_FIRST+=(-d "${list[$i]}")
        fi
    done

    echo ${ACME_DOMAIN_OPTION[@]}
    echo ${ACME_DOMAIN_OPTION_FIRST[@]}
}

if [[ -n "$DOMAINS" ]]; then
    echo "[$(date)] Create defualt cert."
    CreateDefault

    # export -f RunAcmesh
    # nohup bash -c RunAcmesh "${SSL_DIR}" "${RELOAD_CMD}" &

    export -f StartAcmesh
    nohup bash -c StartAcmesh "${SSL_DIR}" "${RELOAD_CMD}" &
fi

echo "[$(date)] Start nginx"
nginx -g "daemon off;"
