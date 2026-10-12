# AWS Infrastructure Runbook and Improvement Plan

*************************************************************************
* SORRY, I HAVE A MAIN QUESTION BUT I STARTED TO WORK ON THIS OVER THE
* WEEKEND PRETTY MUCH.

* CURRENT STATE 
Subnet	CIDR	AZ index	Used by
management (public)	10.1.1.0/24	0	Bastion, NAT
application (private)	10.1.2.0/24	1	ASG (only subnet), ALB
backend (private)	10.1.3.0/24	0	ALB

backend (private)   10.1.3.0/24 0   ALB , it was done on purpose to be able to create ALB
since there is no other application subnet in another AZ. Improvements section in detail.
*************************************************************************

## Runbook-style notes

How would someone else deploy and operate your environment?

1. Create a private/public key with `ssh-keygen`
2. Create an S3 backend
3. Deploy the IaC for the challenge

> Note: Complete one step at a time.

### 1) Create a private/public key used to log in to the Bastion instance

To make sure you get access to the Bastion, use a Linux-based OS to make it easier. Ensure you have created a public and private key.

```bash
ssh-keygen
```

The default path is usually:

- `~/.ssh/id_ed25519`
- `~/.ssh/id_ed25519.pub`

If not using the default names, update the Terraform file with the correct public key file name:

```hcl
modules/workloads/main.tf: public_key = file("~/.ssh/<filename>.pub")
```

### 2) Create the S3 backend

Clone the repository:

```bash
git clone https://github.com/henmo6971/cf.git
cd cf
cd s3
```

Run:

```bash
terraform init
terraform plan
terraform apply
```

### 3) Create the infrastructure

From the main repo directory:

```bash
cd ../
terraform init
terraform plan
terraform apply
```

Terraform plan/apply will prompt you for the IP to allow access to the bastion. You can use `0.0.0.0/0` or your IP such as `x.x.x.x/32`.

### Restore data if the S3 bucket were deleted

You have a couple of options:

- If S3 replication or backup is enabled, you are safe.
- If there is a copy of the latest state file.
- Worst case: rebuild the Terraform state by importing resources.

---

## Navigating through the new environment

Once Terraform creates all resources, navigate to the environment.

```bash
ssh ec2-user@<Public IP BASTION ec2>
```

### Extra checks for the `httpd` configuration

You can also access the EC2 instances in the ASG via SSH, although this is not recommended. For troubleshooting, you may copy your SSH key to the Bastion:

```bash
cp ~/.ssh/id_ed25519 <file>.key
chmod 400 <file>.key
```

Then connect to the private instances:

```bash
ssh -i <file>.key ec2-user@IP
```

### Test the load balancer

To make testing the website easier, the ALB DNS is associated with `app.testcf.com`.

```bash
wget -qO- http://app.testcf.com
```

Sample output:

```html
<body>
  <h1>Amazon Linux 2023</h1>
  <p>Instance private IP: 10.1.2.237</p>
</body>
```

If you run the command again, you should receive a different IP:

```html
<body>
  <h1>Amazon Linux 2023</h1>
  <p>Instance private IP: 10.1.2.222</p>
</body>
```

### Result

Congratulations! The ALB is routing traffic to EC2 instances in the ASG.

---

## Analysis and improvement plan

### 1) Analysis

#### Availability issues

- There is no HA. If AZ `1b` goes down, the website is down.
- The ALB not able to be created since we dont have 2 Application subnets, one on each AZ, Target group is confined to one AZ (`1b`) because the ASG is only in that zone.
- The same issue applies to the NAT gateway and Bastion. If AZ `1a` is lost, access to the Bastion is lost and ASG instances may lose outbound internet access through the NAT gateway.

#### Security gaps

- HTTPS is not enabled for ALB traffic, so it is currently unencrypted.
- `terraform destroy` could easily destroy key resources. For some resources, we should enable deletion protection.
- The Bastion is exposed via SSH key authentication; we can harden it or use SSM instead.
- A firewall could also be implemented, though it may be costly.
- A custom hardened AMI should be built and maintained to enforce baseline security controls (CIS/STIG alignment, patch level consistency, logging configuration, and removal of unnecessary services) to ensure the compute layer complies with FedRAMP Moderate/High standards.

#### Cost optimization opportunities

- The infrastructure already uses the lowest-cost EC2 instances for the ASG and Bastion.

#### Operational shortcomings

- Additional resources should be added, such as CloudWatch monitoring, logging, firewalling, and more operational safeguards.

### 2) Improvement Plan

#### Improvement changes

- Implement Terraform remote backend
  - Although not explicitly required by the challenge, using an S3 backend is essential for maintainability, resilience, and team collaboration.
  - This was already implemented as part of the requested improvements.

- Redesign the network architecture
  - The current layout does not follow a standard AWS multi-tier VPC design.
  - A proper design should include at least six subnets:
    - 2 public management subnets (AZs 1a and 1b)
    - 2 private application subnets (AZs 1a and 1b)
    - 2 private backend subnets (AZs 1a and 1b)
  - This would improve isolation, scalability, and high availability across the environment.
  - It would also address the ASG issue of being placed in a single AZ.

- Deploy a NAT gateway
  - At least one NAT Gateway should exist in a public subnet to allow private instances to access outbound internet resources for updates, package installation, and external APIs.
  - This was already implemented as part of the requested improvements.

- Replace SSH bastion access with SSM Session Manager
  - Session Manager removes the need for public IP addresses, inbound security group rules, and SSH keys.
  - It also provides audit logging via CloudWatch or S3, which significantly improves the security posture.

#### Priority list

1. Terraform backend
2. Re-architect the network
3. Create compliant AMI

## Summary

This runbook documents the deployment process, environment navigation, verification steps, and an analysis of availability, security, cost, and operational shortcomings. It also outlines the recommended improvement plan for building a more resilient and secure AWS architecture.
