# Start the Vault server in the background using the specified configuration file
vault server -config /vault/config/config.hcl &

# Wait for 5 seconds to allow the Vault server to start properly
sleep 5

# Get the current Vault status in JSON format
status=$(vault status -format=json)

# Extract the "initialized" field value from the status output
initialized=$(echo $status | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}')

# Check if Vault is not initialized
if [ "$initialized" = "false" ]; then
    echo "Initializing Vault..."
    
    # Initialize Vault and store the output in initstatus
    initstatus=$(vault operator init -format=json)
    
    # Check Vault initialization status
    vault operator init -status
    
    # If initialization fails, print an error message and exit
    if [ $? -ne 0 ]; then
        echo "Error Initializing Vault"
        exit -1
    fi

    # Extract the root token from the initialization output and save it to a file
    echo $initstatus | awk -F'"' '/root_token/ {print $(NF-1)}' > /vault/key/token
    
    # Secure the token file by setting appropriate permissions
    chmod 600 /vault/key/token

    # Re-check Vault initialization status
    initialized=$(vault status -format=json | awk -F'"initialized": ' '{print $2}' | awk -F',' '{print $1}' | xargs)
fi

# Set the VAULT_TOKEN environment variable using the stored root token
export VAULT_TOKEN=$(cat /vault/key/token)

# Retrieve the list of enabled audit logs
AUDIT_LOGS=$(vault audit list)

# Check if audit logging is enabled
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
