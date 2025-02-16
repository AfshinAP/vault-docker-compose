ui = true
api_addr = "http://VAULT_IP:8200"
cluster_addr = "http://VAULT_IP:8201"
disable_mlock = true
 
storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
  retry_join {
      leader_api_addr = "http://ANOTHER_VAULT_IP:8200"
  }
}
 
seal "transit" {
  address = "http://TRANSIT_VAULT_IP:8200"
  token = "AUTOUNSEAL_TOKEN"
  disable_renewal = "false"
  key_name = "defaultautounseal"
  mount_path = "transit/"
  tls_skip_verify = "true"
}
 
listener "tcp" {
  address = "0.0.0.0:8200"
  cluster_address = "0.0.0.0:8201"
  tls_disable = "true"
}
