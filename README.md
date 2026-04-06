# Kubecon26-example-repo

In this repository I created a vanilla three node Kubernetes cluster in AWS, I tried to replay the examples that I saw on Kubecon 2026

There's still work in progress.

## The idea

The idea behind this repository is that I learn a lot from the Kubecon sessions, but that I also think "I'd love to play with the ideas that I get from the sessions". I think you might learn more from talks when you implement the ideas yourself.

For every session that I liked you will find a seperate directory. All the examples are deployed in the Kubernetes environment.

## How to deploy this repository in your own environment

You can go to the aws-deployment directory and copy the setenv.template.sh file to setenv.sh. Please look at the remarks in this directory before you deploy anything. When you configured the shell script setenv.sh, this file is used by the three other shell scripts in that directory. You can simply use the following commands to deploy the CloudFormation template to your own environment:

```
. ./login.sh
. ./start.sh
```

When you looked around and played with this, you can delete the environment using:

```
. ./stop.sh
```

## Port numbers

The following portnumbers are used:

| Port number | Used for                                  |
| ----------- | ----------------------------------------- |
| 30001       | 02-refresh-secrets                        |
| 30002       | 03-refresh-secrets-aws, AWS secretsmanager|
| 30003       | 03-refresh-secrets-aws, SSM Parameters    |
| 30007       | ArgoCD                                    |
| 30008       | Keyvault (used in 02-refresh-secrets)     |

