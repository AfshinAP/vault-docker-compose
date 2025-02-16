vault server -config /vault/config/config.hcl &

sleep 10

status=`vault status -format=json`
initialized=`echo $status | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}'`

if [ "$initialized" = "false" ]; then
    echo "Initializing"
    initstatus=`vault operator init -format=json`
    vault operator init -status
    if [ $? -ne 0 ]; then
        echo "Error Initializing"
        exit -1
    fi
    echo $initstatus | awk -F'"' '/root_token/ {print $(NF-1)}' > /vault/key/token
    chmod 600 /vault/key/token
    initialized=`vault status -format=json | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}' | xargs`
fi

export VAULT_TOKEN=`cat /vault/key/token`
AUDIT_LOGS=$(vault audit list)

if [[ "$AUDIT_LOGS" == *"No audit devices are enabled."* ]]; then
    echo "No audit logs are defined. Enabling audit log..."

    vault audit enable file file_path=/vault/logs/vault_audit.log

    if [ $? -eq 0 ]; then
        echo "Audit log enabled successfully."
    else
        echo "Failed to enable audit log."
    fi
else
    echo "Audit logs are already defined:"
    echo "$AUDIT_LOGS"
fi

wait
