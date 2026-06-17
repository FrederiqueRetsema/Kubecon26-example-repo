#!/bin/bash

# Test TLSRoute with TLS passthrough mode
# The gateway does NOT terminate TLS — it passes encrypted traffic directly to the backend
# The backend's certificate should be visible to the client

echo "=== Testing TLSRoute with TLS Passthrough mode ==="
echo ""

# Get the gateway service ClusterIP
GATEWAY_IP=$(kubectl get svc -n kgateway-system tlsroute-passthrough-gateway -o jsonpath='{.spec.clusterIP}' 2>/dev/null)

if [ -z "$GATEWAY_IP" ]; then
  echo "Gateway service not found."
  echo "Make sure the gateway is deployed and the service exists:"
  echo "  kubectl get svc -n kgateway-system"
  exit 1
fi

echo "Gateway IP: $GATEWAY_IP"
echo ""

# Test 1: Verify the BACKEND certificate is presented (not a gateway cert)
echo "--- Test 1: Verify the backend certificate is presented (passthrough) ---"
openssl s_client -connect $GATEWAY_IP:443 -servername www.example.com </dev/null 2>/dev/null | openssl x509 -noout -subject -issuer -dates
echo ""

# Test 2: Make a request through the passthrough gateway
echo "--- Test 2: Make a request through the passthrough gateway ---"
curl -k --resolve www.example.com:443:$GATEWAY_IP https://www.example.com:443 2>/dev/null
echo ""

# Test 3: Show TLS connection details (should show backend's cert info)
echo "--- Test 3: TLS connection details ---"
openssl s_client -connect $GATEWAY_IP:443 -servername www.example.com </dev/null 2>&1 | grep -E "Protocol|Cipher|subject|issuer"
echo ""

echo "=== Done ==="
echo ""
echo "Key difference from Terminate mode:"
echo "  - In Terminate mode, the GATEWAY's certificate is presented to the client"
echo "  - In Passthrough mode, the BACKEND's certificate is presented to the client"
