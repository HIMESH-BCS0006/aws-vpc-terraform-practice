# Product & Coupon Microservices — Custom AWS VPC + Terraform

A small microservices demo (product service + coupon service, backed by MySQL) deployed on a **hand-designed AWS VPC** and fully **managed with Terraform**. Built specifically to move past "it works" and into "I understand why every piece of this network exists."

Previous deployments I'd done relied on AWS's default VPC — open security groups, public IPs, things that worked but that I couldn't fully explain. This project starts from a blank VPC and makes every networking, security, and availability decision explicit and defensible.

## Architecture

- **VPC**: `10.0.0.0/16`, spanning 2 Availability Zones
- **6 subnets**: public / private / data tiers, replicated per AZ
- **Public subnets**: ALB, NAT Gateway (one per AZ — no shared single point of failure)
- **Private subnets**: ECS Fargate tasks (product-app, coupan-app) — no public IPs, reachable only via the ALB
- **Data subnets**: RDS MySQL (Multi-AZ) — no public IP, no internet route at all
- **Service discovery**: ECS Service Connect (Cloud Map) for inter-service calls
- **Routing**: path-based ALB rules — `/products*` → product-app, `/coupons*` → coupan-app

Full request flow and security group chain diagrammed [here](./request-flow-diagram.png).

## Why it's designed this way

| Decision | Reason |
|---|---|
| No public IP on RDS or app services | Removes an entire class of direct-access attacks structurally, not just by policy |
| Security groups reference each other, not CIDR ranges | ALB → app → DB trust chain; nothing trusts an open IP range |
| One NAT Gateway per AZ | A NAT Gateway is AZ-scoped — sharing one reintroduces a single point of failure for "private" subnets in the other AZ |
| Data subnets have no `0.0.0.0/0` route at all | Not blocked by a rule — structurally no path exists |
| Everything in Terraform | Reproducible, reviewable via `plan` before anything touches AWS, destroy/rebuild in minutes |

## What broke, and what I learned from it

This section exists on purpose — the debugging was where most of the real learning happened.

- **`enable_dns_hostnames` / `enable_dns_support` default to `false`/`true`(inconsistently) on a custom VPC.** RDS refused to provision as publicly-inaccessible until DNS resolution was explicitly enabled — the default VPC does this silently, a custom one doesn't.
- **A dangling IAM role reference.** `execution_role_arn` pointed at a role I'd commented out during a refactor. Caught by `terraform plan` before it ever reached AWS — a concrete example of why `plan` matters.
- **The big one: consolidating two security groups into one silently broke inter-service communication.** Both ECS services shared a single SG scoped only to allow traffic from the ALB. Service-to-service calls (via ECS Service Connect) have no matching inbound rule in that setup — a security group doesn't implicitly trust its own members. Symptom was a `504` from Envoy's own sidecar proxy, not an obvious network error. Root-caused via `curl` from inside the container (DNS resolved, TCP connected, then 504 — pointing at an application/proxy-layer rejection, not a routing failure) before finding the missing self-referencing rule. Fixed with one rule: allow inbound from the security group itself.
- **`TargetNotConnectedException` on ECS Exec.** `enable_execute_command` and IAM permission changes only apply to *newly launched* tasks — an already-running task doesn't retroactively gain SSM agent connectivity. Needed a forced fresh deployment.

## Stack

- **Compute**: ECS Fargate
- **Networking**: Custom VPC, ALB, NAT Gateway, Service Connect
- **Data**: RDS MySQL (Multi-AZ)
- **IaC**: Terraform
- **Apps**: Spring Boot (Java), MySQL

## Repo structure

```
.
├── main.tf              # provider config
├── variables.tf          # input variables
├── vpc.tf                 # VPC, subnets, IGW, NAT gateways, route tables
├── security_groups.tf      # ALB / app / DB security group chain
├── rds.tf                   # RDS subnet group + Multi-AZ MySQL instance
├── ecs.tf                    # cluster, task definitions, services, Service Connect
├── alb.tf                     # load balancer, target groups, path-based routing
├── outputs.tf                  # ALB DNS name, VPC ID, RDS endpoint
└── terraform.tfvars.example     # copy to terraform.tfvars, fill in secrets
```

## Running this

```bash
cp terraform.tfvars.example terraform.tfvars   # fill in db_password
terraform init
terraform plan
terraform apply
```

Destroy everything cleanly with `terraform destroy` — the whole environment is reproducible from code, not click-through state.

## Demonstrated in the video

- Path-based routing across two live services
- Killing a running ECS task mid-traffic — ALB reroutes to the healthy AZ, ECS self-heals, zero dropped requests
- The security group bug above, and the fix

---

Built as a hands-on deep dive into AWS VPC design and Terraform, not a production system. Happy to discuss any of the design decisions or debugging above.
