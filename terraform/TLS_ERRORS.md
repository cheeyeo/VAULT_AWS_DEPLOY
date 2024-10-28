ct 28 16:07:44 ip-10-0-2-191.eu-west-2.compute.internal vault[3491]: 2024-10-28T16:07:44.801Z [ERROR] core: failed to get raft challenge: leader_addr=https://10.0.1.184:8200 error="error during raft bootstrap init call: Put \"https://10.0.1.184:8200/v1/sys/storage/raft/bootstrap/challenge\": tls: failed to verify certificate: x509: cannot validate certificate for 10.0.1.184 because it doesn't contain any IP SANs"




Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: 2024-10-28T16:47:36.936Z [ERROR] core: failed to get raft challenge: leader_addr=https://10.0.1.50:8200
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: error=
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: | error during raft bootstrap init call: Error making API request.
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: |
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: | URL: PUT https://10.0.1.50:8200/v1/sys/storage/raft/bootstrap/challenge
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: | Code: 503. Errors:
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: |
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: | * Vault is sealed
Oct 28 16:47:36 ip-10-0-1-50.eu-west-2.compute.internal vault[3478]: 2024-10-28T16:47:36.941Z [ERROR] core: failed to get raft challenge: leader_addr=https://10.0.2.100:8200