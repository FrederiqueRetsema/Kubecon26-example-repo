#!/bin/bash

# Test TLSRoute with TLS termination at the gateway
# The gateway terminates TLS and forwards plain HTTP to the backend

echo "=== Testing TLSRoute with TLS Terminate mode ==="
echo ""

# Get the gateway pod IP
GATEWAY_IP=$(kubectl get svc -n kgateway-system my-tls-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [ -z "$GATEWAY_IP" ]; then
  echo "Gateway service not found. Trying port-forward instead..."
  echo "Run: kubectl port-forward svc/my-tls-gateway -n kgateway-system 8443:443"
  echo "Then: curl -k --resolve www.example.com:8443:127.0.0.1 https://www.example.com:8443"
  exit 1
fi

echo "Gateway IP: $GATEWAY_IP"
echo ""

# Test 1: Connect with TLS and verify the self-signed certificate
echo "--- Test 1: Verify the self-signed certificate is presented ---"
echo | openssl s_client -connect $GATEWAY_IP:443 -servername www.example.com 2>/dev/null | openssl x509 -noout -subject -issuer -dates
echo ""

# Test 2: Make a request through the TLS gateway (skip cert verification for self-signed)
echo "--- Test 2: Make a request through the TLS-terminated gateway ---"
curl -k --resolve www.example.com:443:$GATEWAY_IP https://www.example.com:443 2>/dev/null | head -5
echo ""

# Test 3: Verify TLS is actually terminated (backend receives plain HTTP)
echo "--- Test 3: Confirm connection uses TLS ---"
echo | openssl s_client -connect $GATEWAY_IP:443 -servername www.example.com 2>&1 | grep -E "Protocol|Cipher|Verify"
echo ""

echo "=== Done ==="
