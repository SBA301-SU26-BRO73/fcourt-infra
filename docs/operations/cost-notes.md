# Cost notes

Moved from the old README.


Prices below are rough estimates from memory (Singapore, 4-hour demo), not quotes. Check the AWS pricing pages.

- Node group is `SPOT`, min/desired/max `2/2/3`, all nodes in a single AZ (`node_subnet_count = 1`, so a replaced Spot node cannot strand an EBS volume in another AZ), 20 GiB gp3 root, IMDSv2. Six interchangeable 2 vCPU/8 GiB types (`t3.large`, `t3a.large`, `m5.large`, `m6i.large`, `m6a.large`, `m7i.large`) improve Spot availability. Spot can be reclaimed at any time; use On-Demand if a demo must not be interrupted. One 8 GiB node is not enough for 12 services, Eureka, the gateway and data.
- `nodes_in_public_subnets = true` puts nodes in public subnets and skips the NAT gateway (about $0.06/h saved). Nodes get public IPs but security groups allow no inbound traffic and the API is limited to `cluster_public_access_cidrs`. Use for short demos only.
- Control-plane logging, VPC flow logs, interface endpoints and KMS secrets encryption are off by default.
- Budget alert (in `envs/shared`, excludes credits and refunds): `monthly_budget_usd = 20`, emails at 5, 10 and 15 USD actual and 100% forecast. Alerts do not stop spending.
- Rough cost while running: EKS control plane ~$0.10/h, one Spot node ~$0.05-0.15/h, ALB ~$0.02-0.03/h. That is roughly $1-2 for a 4-hour demo.

**Shut down after the demo** (`sh scripts/down.sh`). Things that still cost money after destroy if forgotten: leftover EBS volumes (PVCs), ALBs created by Ingress, old state bucket versions, active SNS resources.

Sizing: request memory is about 8 GiB for everything; two 8 GiB nodes is the minimum. If pods stay `Pending` or are `OOMKilled`, check `kubectl top nodes/pods`.

