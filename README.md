# ECS Workshop Infrastructure

A comprehensive AWS infrastructure setup for deploying a 2-tier microservice application using Amazon ECS (Elastic Container Service) with Fargate, Application Load Balancer, and supporting AWS services.

## 📚 Learning Resources

This project is part of the [**Learn Amazon ECS over a Weekend**](https://shorturl.at/y8ys4) course, which provides comprehensive hands-on experience with containerized applications on AWS.

## Architecture Overview

This infrastructure creates a highly available, scalable, and secure environment for containerized applications across multiple availability zones.

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                                  Internet                                        │
└─────────────────────────────┬───────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                         Internet Gateway                                        │
└─────────────────────────────┬───────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                    VPC (10.0.0.0/16) - ecs-vpc                                 │
│                                                                                 │
│  ┌─────────────────────────┐              ┌─────────────────────────┐          │
│  │   Public Subnet 1       │              │   Public Subnet 2       │          │
│  │   (10.0.1.0/24)         │              │   (10.0.2.0/24)         │          │
│  │   AZ-1                  │              │   AZ-2                  │          │
│  │                         │              │                         │          │
│  │  ┌─────────────────┐    │              │  ┌─────────────────┐    │          │
│  │  │  NAT Gateway    │    │              │  │                 │    │          │
│  │  │  (EIP)          │    │              │  │                 │    │          │
│  │  └─────────────────┘    │              │  └─────────────────┘    │          │
│  └─────────────────────────┘              └─────────────────────────┘          │
│                              │                          │                       │
│                              └──────────┬───────────────┘                       │
│                                         │                                       │
│                              ┌─────────────────────────┐                       │
│                              │  Application Load       │                       │
│                              │  Balancer (ALB)         │                       │
│                              │  Port 80                │                       │
│                              │  Routes: / → Frontend   │                       │
│                              │         /api* → Backend │                       │
│                              └─────────────────────────┘                       │
│                                         │                                       │
│  ┌─────────────────────────┐              ┌─────────────────────────┐          │
│  │   Private Subnet 1      │              │   Private Subnet 2      │          │
│  │   (10.0.3.0/24)         │              │   (10.0.4.0/24)         │          │
│  │   AZ-1                  │              │   AZ-2                  │          │
│  │                         │              │                         │          │
│  │  ┌─────────────────┐    │              │  ┌─────────────────┐    │          │
│  │  │ ECS Tasks       │    │              │  │ ECS Tasks       │    │          │
│  │  │ Frontend:80     │    │              │  │ Frontend:80     │    │          │
│  │  │ Backend:3000    │    │              │  │ Backend:3000    │    │          │
│  │  │ (Fargate)       │    │              │  │ (Fargate)       │    │          │
│  │  └─────────────────┘    │              │  └─────────────────┘    │          │
│  └─────────────────────────┘              └─────────────────────────┘          │
│                                                                                 │
└─────────────────────────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────────────────────────┐
│                            Supporting Services                                   │
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │ ECR Repository  │  │ CloudWatch Logs │  │ Service         │                │
│  │ my-app-repo     │  │ /ecs/frontend   │  │ Discovery       │                │
│  │ - frontend:tag  │  │ /ecs/backend    │  │ ecsworkshop.    │                │
│  │ - backend:tag   │  │                 │  │ local           │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
│                                                                                 │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐                │
│  │ ECS Cluster     │  │ IAM Roles       │  │ Security Groups │                │
│  │ my-ecs-cluster  │  │ - Task Exec     │  │ - ALB (Port 80) │                │
│  │ - Frontend Svc  │  │ - Service Role  │  │ - ECS (80,3000) │                │
│  │ - Backend Svc   │  │                 │  │                 │                │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘                │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

### Network Layer (network-stack.cf.yml)
- **VPC**: Custom Virtual Private Cloud (10.0.0.0/16)
- **Public Subnets**: 2 subnets across different AZs for high availability
  - Public Subnet 1: 10.0.1.0/24 (hosts ALB and NAT Gateway)
  - Public Subnet 2: 10.0.2.0/24 (hosts ALB for redundancy)
- **Private Subnets**: 2 subnets for ECS tasks
  - Private Subnet 1: 10.0.3.0/24 (ECS tasks)
  - Private Subnet 2: 10.0.4.0/24 (ECS tasks)
- **Internet Gateway**: Enables internet access for public subnets
- **NAT Gateway**: Provides outbound internet access for private subnets
- **Route Tables**: Proper routing for public and private traffic

### Application Layer (ecs-stack.cf.yml)
- **ECS Cluster**: Container orchestration platform (my-ecs-cluster)
- **Application Load Balancer**: Routes traffic between frontend and backend
  - Default route (/) → Frontend service
  - API routes (/api*) → Backend service
- **ECS Services**: Manages container deployment and scaling
  - Frontend Service: Runs on port 80
  - Backend Service: Runs on port 3000
- **Task Definitions**: Container specifications using Fargate
- **ECR Repository**: Stores Docker images for both services
- **Service Discovery**: Enables service-to-service communication
- **Security Groups**: Network access control
- **CloudWatch Logs**: Centralized logging with 7-day retention
- **IAM Roles**: Secure access permissions for ECS tasks and services

## Key Features

- **High Availability**: Multi-AZ deployment across 2 availability zones
- **Security**: Private subnets for application workloads, security groups for network isolation
- **Scalability**: ECS Fargate for serverless container management
- **Monitoring**: CloudWatch integration for logs and metrics
- **Service Discovery**: Internal DNS for service communication
- **Load Balancing**: Application Load Balancer with path-based routing
- **Container Registry**: ECR for secure image storage with vulnerability scanning

## Deployment

### Prerequisites
- AWS CLI configured with appropriate permissions
- Terraform >= 1.10

### Bootstrap (one-time setup)

This creates the S3 state bucket, GitHub OIDC provider, and IAM role. Run this manually before the CI pipeline can operate.

```bash
cd bootstrap

terraform init
terraform apply \
  -var="github_org=YOUR_GITHUB_ORG" \
  -var="github_repo=YOUR_REPO_NAME"
```

After apply completes, copy the `github_actions_role_arn` output and set it as a GitHub Actions **variable** (not a secret):

1. Go to your repo **Settings > Secrets and variables > Actions > Variables**
2. Create a variable named `AWS_ROLE_ARN` with the role ARN value

### Automated Deployment
The infrastructure deploys automatically via GitHub Actions OIDC (no long-lived credentials) when code is pushed to the `main` branch.

The pipeline runs `terraform init -backend-config=backend.hcl`, then `plan` and `apply`.

### Manual Deployment
```bash
terraform init -backend-config=backend.hcl
terraform plan -out=tfplan
terraform apply tfplan
```

## Project Structure
```
ecsworkshop-infra/
├── main.tf                     # Network resources (VPC, subnets, gateways, routes)
├── variables.tf                # Input variables (CIDR blocks)
├── outputs.tf                  # Exported VPC and subnet IDs
├── data.tf                     # Availability zones data source
├── locals.tf                   # Common tags
├── backend.hcl                 # S3 backend config (used via -backend-config)
├── bootstrap/
│   ├── main.tf                 # S3 state bucket, GitHub OIDC provider, IAM role
│   ├── variables.tf            # GitHub org/repo, region, bucket name
│   └── outputs.tf              # Role ARN and bucket name
├── templates/
│   └── ecs-stack.cf.yml        # ECS cluster and application resources (CloudFormation)
├── .github/
│   └── workflows/
│       └── deploy.yml          # CI/CD pipeline (Terraform via OIDC)
└── README.md
```

## Outputs
After successful deployment, the ECS stack provides:
- **ALB DNS Name**: Public endpoint for accessing the application
- **ECR Repository URI**: Location for pushing Docker images

## Cost Optimization
- **Fargate**: Pay only for running containers
- **NAT Gateway**: Single NAT Gateway for cost efficiency
- **Log Retention**: 7-day retention to minimize storage costs
- **Resource Sizing**: Minimal CPU/memory allocation (256 CPU, 512 MB memory)

## Security Best Practices
- Private subnets for application workloads
- Security groups with least privilege access
- IAM roles with minimal required permissions
- ECR vulnerability scanning enabled
- No direct internet access for ECS tasks

## Monitoring and Logging
- CloudWatch log groups for each service
- Application Load Balancer access logs
- ECS service and task metrics
- Container insights for detailed monitoring

## Troubleshooting

### Common Issues
- **Terraform Init Fails**: Ensure the S3 state bucket exists and `backend.hcl` values are correct
- **GitHub Actions Fails**: Verify `AWS_ROLE_ARN` variable is set and the OIDC trust policy matches your repo/branch
- **ECS Stack Fails**: Ensure network stack is complete and verify IAM permissions
- **Tasks Not Starting**: Check that Docker images exist in ECR repository

### Verification Steps
1. Confirm VPC and subnets are created in AWS Console
2. Verify ECS cluster exists with services defined
3. Check ALB is running and target groups are healthy
4. Validate ECR repository is accessible

## Application Deployment

For deploying the 2-tier application (frontend and backend) on this ECS cluster, follow the instructions in the companion repository:

**📦 [ECS Workshop Application Repository](https://github.com/himanshurgit/ecsworkshop-app.git)**

This repository contains the Dockerized frontend and backend applications along with CI/CD pipelines to build, push to ECR, and deploy to the ECS cluster created by this infrastructure.

## Next Steps
1. Deploy application containers to ECR repository using the app repository above
2. Update ECS service desired count to start tasks
3. Configure custom domain and SSL certificate
4. Set up monitoring alerts and dashboards
5. Implement auto-scaling policies
