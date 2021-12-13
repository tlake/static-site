---
title: "Curriculum Vitae"
date: 2019-04-18T00:11:46-07:00
layout: "terms"
---

## About

Tanner Lake  \
Infrastructure-Side Software Engineer  \
Seattle, WA  \
[tanner.lake@gmail.com](mailto:tanner.lake@gmail.com)

If you're looking for my **resume**, you can find it [here](/resume_tannerlake.pdf).

## Experience

### Fandom _(Jan 2021 - Present)_

_TechOps Engineer, **D&D Beyond**_

### IQVIA _(May 2016 - Mar 2020)_

_Software and DevOps engineer._

- Collaborated on creating and maintaining tools to streamline deployment.
- Wrote Terraform modules and configurations.
- Evangelized infrastructure-as-code and best practices.
- Created, maintained, streamlined, and repaired CI/CD pipelines in both GitLab and GitHub.

#### Notable Projects

##### AWS Cleanup Tools

- Authored Golang and Bash scripts to identify and terminate unnecessary AWS resources.
- Composed tools into Helm charts and deployed them into our production EKS cluster to automate recurring cleanup runs.

##### Terraform Enterprise

Deployed, maintained, and updated on-prem inter-office Terraform Enterprise installation.

- Implemented Auth0-backed SSO.
- Created Auth0 rules to auto-assign users to teams and organizations based on LDAP user data.

##### Splunk on EKS

A Terraform and kubectl configuration to deploy a production-ready Splunk cluster onto an existing EKS cluster.

- Created deployment Splunk cluster of 1 master node, 2 search heads, and 3 indexers with enabled HTTP Event Collectors.
- Enabled SmartStore to persist warm-and-colder indexer buckets to S3 instead of large, expensive EBS volumes.
- Implemented Auth0-backed SSO.
- Replaced local machine workflow with deployment to workspaces in Terraform Enterprise.

##### Production EKS cluster

A Terraform configuration to deploy a custom Kubernetes cluster on AWS EKS.

- Converted Makefile workflow into Terraform workflow.
- Added Tillerless Helm to Terraform configuration.
- Added validation for binaries and dependencies.
- Implemented "Terraform admin" setup to manage resources through an IAM role instead of AWS credentials directly.
- Replaced local machine workflow with deployment to workspaces in Terraform Enterprise.

##### Orca

A React + Go tool for managing Kubernetes RBAC permissions.

Repository: <https://github.com/quintilesims/orca>

- Assumed ownership of project and led design.
- Implemented API client middleware with authorization header management.
- Refactored as better practices were learned.
- Wrote Jest + Enzyme test suite, set up pre-commit CI.

##### Layer0

A Go CLI tool for deploying Dockerized applications to AWS infrastructure.

Repository: <https://github.com/quintilesims/layer0>

- Added stateless workflow via AWS Fargate.
- Expanded system tests.
- Took ownership of service entities during big API refactor.
- Added load balancer health checks.
- Wrote usage walkthroughs, updated documentation.
- Automated release process through a GitHub machine user.

##### d.ims.io

A Go wrapper around AWS ECR with custom authentication.

Repository: <https://github.com/quintilesims/d.ims.io>

- Authored Auth0-backed authentication workflow with retry and exponential backoff logic.
- Implemented `/images` API endpoint, including Swagger.

---

### Code Fellows _(Feb - May 2016)_

_Teaching assistant._

Evaluated student assignments and provided feedback and code review.
Provided assistance and mentorship in person and remotely.

---

## Education

Certificate, Full-Stack Python -- August 2015
Code Fellows, Seattle WA

B.A. in Classical Civilization -- May 2010
University of Vermont, Burlington VT
