# 06-policy-engines

The policies are enforced in their own namespace, you can test them using the test scripts and check it in
a non-enforced namespace as well. Code:

## ValidatingAdmissionPolicy

```
kubectl apply -f test-vap.yml -n 06-policy-engines-vap
kubectl apply -f test-vap.yml -n 06-policy-engines-no-policies
```
