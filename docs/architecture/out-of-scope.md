# Out of scope

Moved from the old README.

No WAF, VPN, bastion, Helm releases, Kubernetes namespaces/secrets, SQL migrations, Kafka topics/ACLs, managed databases (RDS, MSK, ElastiCache) or monitoring stack. Those belong to `fcourt-gitops` or later work. (DNS, ACM and CloudFront for the web are in `envs/shared`, see [bootstrap-and-shared.md](../operations/bootstrap-and-shared.md).) The Firebase credential is stored in Terraform state through the SNS platform application, so restrict access to state.
