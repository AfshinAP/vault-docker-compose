# Start the Vault server in the background using the specified configuration file
vault server -config /vault/config/config.hcl &

# Wait for 3 seconds to allow the Vault server to start
sleep 3

# Define the file path to store transit tokens
TOKENS_FILE="/vault/key/transit_tokens"

# Get the current Vault status in JSON format
status=$(vault status -format=json)

# Extract the "initialized" and "sealed" field values from the status output
initialized=$(echo $status | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}')
sealed=$(echo $status | awk -F'"sealed": ' '{print $2}' | awk -F',' '{print $1}')

# Check if Vault is not initialized
if [ "$initialized" = "false" ]; then
    echo "Initializing Vault..."
    
    # Initialize Vault with a single key share and key threshold
    initstatus=$(vault operator init -key-shares=1 -key-threshold=1 -format=json)
    
    # Check Vault initialization status
    vault operator init -status
    
    # If initialization fails, print an error message and exit
    if [ $? -ne 0 ]; then
        echo "Error Initializing Vault"
        exit -1
    fi

    # Extract the root token and store it in a file
    echo $initstatus | awk -F'"' '/root_token/ {print $(NF-1)}' > /vault/key/token
    
    # Extract the unseal key and store it in a file
    echo $initstatus | awk -F'"unseal_keys_b64": \\[ "' '{print $2}' | awk -F'"' '{print $1}' > /vault/key/unsealKey

    # Secure the token and unseal key files
    chmod 600 /vault/key/token
    chmod 600 /vault/key/unsealKey

    # Update the initialized status after initialization
    initialized=$(vault status -format=json | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}' | xargs)
fi

# If Vault is initialized but still sealed, unseal it
if [ "$initialized" = "true" ] && [ "$sealed" = "true" ]; then
    key=$(cat /vault/key/unsealKey)
    vault operator unseal -format=json $key
    
    # Check if Vault was successfully unsealed
    sealed=$(vault status -format=json | awk -F'"sealed": ' '{print $2}' | awk -F',' '{print $1}' | xargs)
    if [ "$sealed" = "true" ]; then
        echo "Unseal Failed"
        exit -1
    fi
fi

# If Vault is initialized and unsealed, configure Transit Secret Engine
if [ "$initialized" = "true" ] && [ "$sealed" = "false" ]; then
    export VAULT_TOKEN=$(cat /vault/key/token)

    # Check if Transit Secret Engine is enabled
    has_transit=$(vault secrets list -format=json | awk -v RS='},' -F'"transit/": ' '{print $2}' | awk -F'}' '{print $1}' | xargs)
    
    # Enable Transit Secret Engine if not already enabled
    if [ "$has_transit" = "" ]; then
        echo "Enabling Transit Engine"
        vault secrets enable transit
        vault write -f transit/keys/defaultautounseal
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Transit Engine Already Enabled!"
    fi

    # Check if the default key exists in Transit Secret Engine
    has_default=$(vault list -format=json transit/keys | awk -F'"' '/defaultautounseal/ {count++} END {print count}')
    
    # Create the default key if it does not exist
    if [ $has_default = 0 ]; then
        echo "Creating Default Key"
        vault write -f transit/keys/defaultautounseal
    else
        echo "Default Key already exists!"
    fi

    # Check if the policy for default auto-unseal exists
    has_policy=$(vault policy list | grep defaultautounseal | wc -l)
    
    # Create the policy if it does not exist
    if [ $has_policy = 0 ]; then
        echo "Creating Policy"
        vault policy write defaultautounseal /vault/config/autounseal.hcl
    else
        echo "Policy Already Created!"
    fi

    echo "Creating new token"
    
    # Generate a new token with the default auto-unseal policy and store it
    new_transit_token=$(vault token create -policy=defaultautounseal -format=json | awk -F'"' '/client_token/ {token=$4} END {print token}')
    echo ${new_transit_token}

    echo ${new_transit_token} >> ${TOKENS_FILE}
fi

# Check if audit logging is enabled
AUDIT_LOGS=$(vault audit list)

if [[ "$AUDIT_LOGS" == *"No audit devices are enabled."* ]]; then
    echo "No audit logs are defined. Enabling audit log..."

    # Enable file-based audit logging
    vault audit enable file file_path=/vault/logs/vault_audit.log

    # Check if the audit log was enabled successfully
    if [ $? -eq 0 ]; then
        echo "Audit log enabled successfully."
    else
        echo "Failed to enable audit log."
    fi
else
    # If audit logs are already defined, print the existing logs
    echo "Audit logs are already defined:"
    echo "$AUDIT_LOGS"
fi

# Wait for background processes to finish
wait
