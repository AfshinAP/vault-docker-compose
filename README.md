
# Vault docker-compose
HashiCorp Vault is a powerful security tool designed to securely manage secrets, credentials, and sensitive data. In this project, we will deploy vault using docker-compose.
## Description

Based on the image below, a vault node needs to be deployed to automate the vault autounseal process.

![vault structure](https://developer.hashicorp.com/_next/image?url=https%3A%2F%2Fcontent.hashicorp.com%2Fapi%2Fassets%3Fproduct%3Dtutorials%26version%3Dmain%26asset%3Dpublic%252Fimg%252Fvault-raft-1.png%26width%3D1104%26height%3D564&w=1200&q=75&dpl=dpl_Gpkis5daodif1XJUkruzJDBVBi2m)

The configuration and docker compose files for transit vault are provided in the `vault_transit` folder.

In the `vault_transit/auto_unseal.sh`, the following processes have been automated:
- Initialization
- Providing the unseal key
- Providing the root token
- Unsealing
- Enabling the transit secret engine
- Providing the transit token base policy
- Enabling the audit log

The worker vault node has been implemented with raft storage to enable clustering through integrated storage.

The configuration and docker compose files for transit vault are provided in the `vault_worker` folder.

In the `vault_worker/auto_init.sh`, the following processes have been automated:
- Initialization
- Providing the root token
- Enabling the audit log


## Deployment

To deploy this docker-compose run

```bash
  docker compose up -d
```

