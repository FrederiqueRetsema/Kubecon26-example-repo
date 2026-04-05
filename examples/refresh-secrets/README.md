# Refresh secrets

Talk name: "GitOps and Secrets: State of the Union - Kostis Kapelonis, Octopus Deploy"
Repo: https://github.com/kostis-codefresh/external-secrets-gitops-example

Idea is that you should not store secrets in ArgoCD. Store them somewhere outside
Kubernetes, using the external-secrets-operator.

The deployment is not very stable. Sometimes it works, sometimes it doesn't. Upgrading
to the newest versions of external-secrets-operator (via helm, not via argocd) and vault
worked partly.

After installation, you might see errors in the logs of the pods in the 
external-secrets deployment:

```
kubernetes@control:~$ kubectl get pods -n external-secrets
NAME                                               READY   STATUS    RESTARTS   AGE
external-secrets-79fbd8ddfc-7rzhm                  1/1     Running   0          5m25s
external-secrets-cert-controller-b6d69f9b5-kqqnb   1/1     Running   0          14m
external-secrets-webhook-5d7f66549-d2zvk           1/1     Running   0          14m

kubernetes@control:~$ kubectl logs -n external-secrets external-secrets-79fbd8ddfc-7rzhm

<<errors about 404's, permission denies, etc>>
```

## Workaround:

When you configure the authentication again and then stop the external-secrets pod,
then in general the connection is made.

```
kubernetes@control:~$ kubectl exec -it vault-0 -n vault -- sh
vault write auth/kubernetes/config \
    kubernetes_host=https://$KUBERNETES_SERVICE_HOST:$KUBERNETES_SERVICE_PORT
exit

kubernetes@control:~$ kubectl delete pod -n external-secrets external-secrets-79fbd8ddfc-7rzhm
```
