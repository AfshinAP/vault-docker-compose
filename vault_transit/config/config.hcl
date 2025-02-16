ui = true
 api_addr = "http://VAULT_IP:8200"
 cluster_addr = "http://VAULT_IP:8201"
 disable_mlock = true
 
 storage "raft" {
   path = "/vault/data"
   node_id = "vault-transmit"
 }
 
 listener "tcp" {
   address = "0.0.0.0:8200"
   tls_disable = "true"
 }
