# 06-policy-engines

The policies are enforced in their own namespace, you can test them using the test scripts and check it in
a non-enforced namespace as well. Test code:

## ValidatingAdmissionPolicy

```
kubectl apply -f test-vap-privileged-pod.yml -n 06-policy-engines-vap             # will fail
kubectl apply -f test-vap-privileged-pod.yml -n 06-policy-engines-no-policies     # will not fail

kubectl apply -f test-vap-owner-label-no-label.yml -n 06-policy-engines-vap
kubectl get pod test-no-owner-label -n 06-policy-engines-vap -o yaml              # label owner: example.com

kubectl apply -f test-vap-owner-label-with-label.yml -n 06-policy-engines-vap
kubectl get pod test-pod-with-owner -n 06-policy-engines-vap -o yaml              # label owner: conclusionxforce.cloud
```

## Kyverno

```
kubectl apply -f test-kyverno-pod-without-team.yml -n 06-policy-engines-kyverno       # will fail
kubectl apply -f test-kyverno-pod-without-team.yml -n 06-policy-engines-no-policies   # will not fail

kubectl apply -f test-kyverno-pod-without-resources -n 06-policy-engines-kyverno
kubectl get pod test-pod-no-resources -n 06-policy-engines-kyverno -o yaml            # 
```

# Gatekeeper

```
kubectl apply -f test-gatekeeper-pod-without-team.yml -n 06-policy-engines-gatekeeper    # will fail
kubectl apply -f test-gatekeeper-pod-without-team.yml -n 06-policy-engines-no-policies   # will not fail
kubectl apply -f test-gatekeeper-pod-with-team.yml -n 06-policy-engines-gatekeeper       # will not fail
```
