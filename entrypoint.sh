#!/bin/bash

set -e

if [ -v PASSWORD_FILE ]; then
    PASSWORD="$(< $PASSWORD_FILE)"
fi

: ${HOST:=${DB_PORT_5432_TCP_ADDR:='db'}}
: ${PORT:=${DB_PORT_5432_TCP_PORT:=5432}}
: ${USER:=${DB_ENV_POSTGRES_USER:=${POSTGRES_USER:='odoo'}}}
: ${PASSWORD:=${DB_ENV_POSTGRES_PASSWORD:=${POSTGRES_PASSWORD:='odoo'}}}
: ${ADMIN_PASSWD:='admin_password'}  # Set the default admin password
: ${ADDONS_PATH:='/mnt/extra-addons'}  # Set the default addons path
: ${DATA_DIR:='/etc/odoo'}  # Set the default data directory

# Set or update the admin password directly in the Odoo configuration file
ODOO_RC="/etc/odoo/odoo.conf"

# if [ -f "$ODOO_RC" ]; then
#     if ! grep -q -E "^\s*\[options\]\s*$" "$ODOO_RC"; then
#         echo "[options]" > "$ODOO_RC"
#     fi
# else
#     echo "File $ODOO_RC not found."
# fi

if ! grep -q -E "^\s*\[options\]\s*$" "$ODOO_RC"; then
    echo "[options]" > "$ODOO_RC"
fi

if grep -q -E "^\s*\badmin_passwd\b\s*=" "$ODOO_RC"; then
    # Admin password already exists in the configuration file, update it
    sed -i "s/^\s*\badmin_passwd\b\s*=.*/admin_passwd = ${ADMIN_PASSWD}/" "$ODOO_RC"
else
    # Admin password does not exist, add it to the configuration file
    echo "admin_passwd = ${ADMIN_PASSWD}" >> "$ODOO_RC"
fi

# Set or update addons_path in the Odoo configuration file
if grep -q -E "^\s*\baddons_path\b\s*=" "$ODOO_RC"; then
    # addons_path already exists in the configuration file, update it
    sed -i "s#^\s*\baddons_path\b\s*=.*#addons_path = ${ADDONS_PATH}#" "$ODOO_RC"
else
    # addons_path does not exist, add it to the configuration file
    echo "addons_path = ${ADDONS_PATH}" >> "$ODOO_RC"
fi

# Set or update data_dir in the Odoo configuration file
if grep -q -E "^\s*\bdata_dir\b\s*=" "$ODOO_RC"; then
    # data_dir already exists in the configuration file, update it
    sed -i "s#^\s*\bdata_dir\b\s*=.*#data_dir = ${DATA_DIR}#" "$ODOO_RC"
else
    # data_dir does not exist, add it to the configuration file
    echo "data_dir = ${DATA_DIR}" >> "$ODOO_RC"
fi

DB_ARGS=()
function check_config() {
    param="$1"
    value="$2"
    if grep -q -E "^\s*\b${param}\b\s*=" "$ODOO_RC"; then       
        value=$(grep -E "^\s*\b${param}\b\s*=" "$ODOO_RC" | cut -d " " -f3 | sed 's/["\n\r]//g')
    fi;
    DB_ARGS+=("--${param}")
    DB_ARGS+=("${value}")
}
check_config "db_host" "$HOST"
check_config "db_port" "$PORT"
check_config "db_user" "$USER"
check_config "db_password" "$PASSWORD"

case "$1" in
    -- | odoo)
        shift
        if [[ "$1" == "scaffold" ]] ; then
            exec odoo "$@"
        else
            wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
            exec odoo "$@" "${DB_ARGS[@]}"
        fi
        ;;
    -*)
        wait-for-psql.py "${DB_ARGS[@]}" --timeout=30
        exec odoo "$@" "${DB_ARGS[@]}"
        ;;
    *)
        exec "$@"
esac

exit 1