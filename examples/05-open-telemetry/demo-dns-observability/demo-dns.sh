#!/bin/bash

# The Go-based DNS client runs continuously in the almalinux pod.
# It makes HTTP requests to nginx-service every 5 seconds,
# which triggers DNS lookups that are captured by OBI.
#
# View the client logs:
kubectl logs almalinux -n 05-opentelemetry --tail=20

# To see the DNS lookups in Grafana, open the "DNS Requests (eBPF)" dashboard.
