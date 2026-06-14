# 06-policy-engines

The policies are enforced in their own namespace, you can test them using the test scripts and check it in
a non-enforced namespace as well. Code:

## ValidatingAdmissionPolicy

```
kubectl apply -f test-vap-privileged-pod.yml -n 06-policy-engines-vap             # will fail
kubectl apply -f test-vap-privileged-pod.yml -n 06-policy-engines-no-policies     # will not fail

kubectl apply -f test-vap-owner-label-no-label -n 06-policy-engines-vap
kubectl get pod test-no-owner-label -n 06-policy-engines-vap -o yaml              # label owner: example.com

kubectl apply -f test-vap-owner-label-with-label -n 06-policy-engines-vap
kubectl get pod test-pod-with-owner -n 06-policy-engines-vap -o yaml              # label owner: conclusionxforce.cloud
```
