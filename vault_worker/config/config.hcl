ui = true
api_addr = "http://10.1.20.200:8200"
cluster_addr = "http://10.1.20.200:8201"
disable_mlock = true
 
storage "raft" {
  path = "/vault/data"
  node_id = "vault-1"
  retry_join {
      leader_api_addr = "http://10.1.20.201:8200"
  }
  retry_join {
      leader_api_addr = "http://10.1.20.202:8200"
  }
}
 
seal "transit" {
  address = "http://10.1.20.200:8202"
  token = "hvs.CAESIGjxDMOF0gAZY9w_3HMVmoygf3Iu2rDDUbFzoh5GohdCGh4KHGh2cy55Q2RwTmdrczFrZGJWWHNjbG5DQldpTG0"
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
