vault server -config /vault/config/config.hcl &

sleep 3

TOKENS_FILE="/vault/key/transit_tokens"

status=`vault status -format=json`
initialized=`echo $status | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}'`
sealed=`echo $status | awk -F'"sealed": ' '{print $2}' | awk -F',' '{print $1}'`

if [ "$initialized" = "false" ]; then
    echo "Initializing"
    initstatus=`vault operator init -key-shares=1 -key-threshold=1 -format=json`
    vault operator init -status
    if [ $? -ne 0 ]; then
        echo "Error Initializing"
        exit -1
    fi
    echo $initstatus | awk -F'"' '/root_token/ {print $(NF-1)}' > /vault/key/token
    echo $initstatus | awk -F'"unseal_keys_b64": \\[ "' '{print $2}' | awk -F'"' '{print $1}' > /vault/key/unsealKey
    chmod 600 /vault/key/token
    chmod 600 /vault/key/unsealKey
    initialized=`vault status -format=json | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}' | xargs`
fi

if [ "$initialized" = "true" ] && [ "$sealed" = "true" ]; then
    key=`cat /vault/key/unsealKey`
    vault operator unseal -format=json $key
    sealed=`vault status -format=json | awk -F'"sealed": ' '{print $2}' | awk -F',' '{print $1}' | xargs`
    if [ "$sealed" = "true" ]; then
        echo "Unseal Failed"
        exit -1
    fi
fi

if [ "$initialized" = "true" ] && [ "$sealed" = "false" ]; then
    export VAULT_TOKEN=`cat /vault/key/token`
    has_transit=`vault secrets list -format=json | awk -v RS='},' -F'"transit/": ' '{print $2}' | awk -F'}' '{print $1}' | xargs`
    if [ "$has_transit" = "" ]; then
        echo "Enabling Transit Engine"
        vault secrets enable transit
        vault write -f transit/keys/defaultautounseal
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Transit Engine Already Enabled!"
    fi

    has_default=`vault list -format=json transit/keys | awk -F'"' '/defaultautounseal/ {count++} END {print count}'`
    if [ $has_default = 0 ]; then
        echo "Creating Default Key"
        vault write -f transit/keys/defaultautounseal
    else
        echo "Default Key already exist!"
    fi

    has_policy=`vault policy list | grep defaultautounseal | wc -l`
    if [ $has_policy = 0 ]; then
        echo "Creating Policy"
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Polocy Already created!"
    fi

    if [[ -f ${TOKENS_FILE} ]]; then
        num_tokens=`wc -l ${TOKENS_FILE} | awk '{print $1}'`
        echo "Tokens file already exist and so far we have created: ${num_tokens} tokens"
    else
        echo "Tokens file is new"
    fi

    echo "Creating new token"
    
    new_transit_token=`vault token create -policy=defaultautounseal -format=json | awk -F'"' '/client_token/ {token=$4} END {print token}'`
    echo ${new_transit_token}

    echo ${new_transit_token} >> ${TOKENS_FILE}
fi

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