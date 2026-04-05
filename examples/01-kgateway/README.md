# KGateway

Based on the talk "Gateway API: Bridging the Gap from Ingress to the Future" (Tuesday, 11:15)
Slides can be found here: https://hosted-files.sched.co/kccnceu2026/be/Bridging+the+Gap+from+Ingress+to+the+future.pptx.pdf

Pod > Service > HTTPRoute > Gateway

You can test the example via the following commands:

```
kubectl port-forward deployment/http -n kgateway-system 8080:8080 &

curl localhost:8080 -H "host: www.example2.com:8080"
```
