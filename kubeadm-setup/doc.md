# Provisioning the CKNE Practice Cluster on AWS

This guide explains how the automation in this directory provisions a
Kubernetes cluster on AWS for CKNE hands-on practice:

* 1 control-plane node
* 2 worker nodes
* Ubuntu 24.04, containerd, kubeadm, kubelet, kubectl
* Cilium CNI (also used as the cluster's Gateway API implementation) + Hubble
* Gateway API CRDs, Istio, Prometheus, Jaeger, cert-manager, Helm

Everything is driven by shell scripts and the AWS CLI — no Terraform,
CloudFormation, CDK, EKS, kind, Minikube, k3s or MicroK8s. Node access is
via **AWS Systems Manager (SSM) Session Manager / Run Command by default** —
no SSH key pair, no open port 22 — with SSH available only as an explicit,
opt-in fallback (`ENABLE_SSH=true`).

See the root `README.md` for the one-line `make` commands. This document
explains what each step actually does.

---

## 0. Prerequisites

* AWS CLI v2, configured (`aws configure` or an assumed role) with
  permissions for EC2, IAM (role/instance-profile only), and SSM.
* `jq`, `envsubst` (from `gettext`), `bash` available locally.
* `make` (optional but convenient — wraps every script below).

## 1. Configure

```bash
cp kubeadm-setup/config/cluster.env.example kubeadm-setup/config/cluster.env
$EDITOR kubeadm-setup/config/cluster.env
```

`cluster.env` is git-ignored and is the single source of truth for region,
sizing, CIDRs, and access control (`ALLOWED_ADMIN_CIDR`, `ENABLE_SSH`). See
inline comments in `cluster.env.example` for every field.

## 2. Create AWS infrastructure

```bash
make aws-create
# or directly:
./kubeadm-setup/aws-infra-setup.sh
```

Creates (idempotently — safe to re-run, only creates what's missing): a
dedicated VPC/subnet/Internet Gateway/route table, a locked-down security
group (see below), an IAM role + instance profile granting only
`AmazonSSMManagedInstanceCore`, and 3 Ubuntu EC2 instances (1 control plane +
2 workers) with encrypted gp3 root volumes and IMDSv2 required. The AMI is
discovered at run time via the official Canonical SSM public parameter —
never a hard-coded AMI ID. Every resource is tagged
`Project=CKNEHandsOn / Environment=Training / ManagedBy=AWSCliScripts /
ResourceSet=ckne-lab`; all discovery, status, and teardown scripts only ever
act on resources carrying that exact tag set.

Security group, by design:

* All traffic between cluster nodes (self-referencing rule) — covers
  node-to-node traffic and the ports Cilium needs (VXLAN overlay, health
  checks, etc.).
* TCP 6443 (API server) from the cluster SG, plus from `ALLOWED_ADMIN_CIDR`
  if you set one.
* TCP 30000-32767 (NodePort) from the cluster SG, plus from
  `ALLOWED_NODEPORT_CIDR` if you set one.
* TCP 22 **only** if `ENABLE_SSH=true`, and only from `ALLOWED_ADMIN_CIDR`
  (the script refuses to start if you ask for SSH without an admin CIDR).
* Nothing is ever opened to `0.0.0.0/0`. etcd (2379/2380), the kubelet API
  (10250), controller-manager (10257) and scheduler (10259) are reachable
  only from inside the cluster security group — never from the internet.

Check status any time with `make aws-status`; pause the lab with
`make aws-stop` / resume with `make aws-start` (these only ever touch
project-tagged instances).

## 3. Bootstrap Kubernetes

```bash
make cluster-bootstrap
# or directly:
./kubeadm-setup/cluster-bootstrap.sh
```

This single idempotent script:

1. Discovers the control-plane and worker instances by tag.
2. Waits for SSM registration (falls back to SSH only if `ENABLE_SSH=true`
   and SSM doesn't come up).
3. Runs `common.sh` on every node (containerd, kubeadm/kubelet/kubectl,
   crictl, sysctls, swap disabled, diagnostic tools).
4. Renders `config/kubeadm.config.template` with the control plane's
   *actual* private IP (discovered dynamically, never hard-coded) and the
   exact installed Kubernetes patch version.
5. Runs `kubeadm init` on the control plane (`control-plane-setup.sh`) and
   configures kubeconfig for both `root` and `ubuntu`.
6. Generates a short-lived join token and joins both workers
   (`worker-setup.sh`).
7. Installs Cilium + Hubble (`install-addons.sh --only cilium`).
8. Waits for all nodes `Ready`, verifies CoreDNS, and runs a self-cleaning
   cross-node pod connectivity + Service DNS test.
9. Revokes the bootstrap join token — nothing long-lived is left behind.

## 4. Install the remaining shared add-ons

```bash
make addons-install     # Gateway API CRDs, Istio, Prometheus, Jaeger, cert-manager
make addons-verify       # == make cluster-verify
```

These are cluster-level, installed **once** — individual labs assume they
already exist and must never reinstall or reconfigure them outside the
locking mechanism in `shared/scripts/lock.sh` (see `docs/syllabus-mapping.md`).

## 5. Get kubectl access from your laptop

```bash
make kubeconfig
# or directly:
./kubeadm-setup/download-kubeconfig.sh
export KUBECONFIG=kubeadm-setup/ckne-cluster.kubeconfig
kubectl get nodes -o wide
```

The kubeconfig is fetched over SSM (never SCP/SSH) and written locally with
`0600` permissions; the filename matches the `kubeconfig*` pattern in
`.gitignore` and must never be committed. If `ALLOWED_ADMIN_CIDR` is unset,
the API server stays private-only — reach it via an SSM port-forwarding
session instead (the script prints the exact command).

## 6. Verify

```bash
make cluster-verify
```

Runs a read-only check (plus a self-cleaning connectivity test) for node
readiness, CoreDNS, and every installed add-on, printing `PASS`/`FAIL`/`SKIP`
per component.

## 7. Run labs

See the root `README.md` and `docs/syllabus-mapping.md`.

```bash
make start LAB=CNI-01
make validate LAB=CNI-01
make cleanup LAB=CNI-01
```

## 8. Reset or tear down

* `make cluster-reset` — `kubeadm reset` on every node, keeps the EC2
  instances (useful after breaking something at the cluster level).
* `make aws-destroy-dry-run` — prints exactly what would be deleted.
* `make aws-destroy` — deletes it, after an explicit confirmation prompt.
  Only ever touches resources carrying this project's exact tag set; never
  the account's default VPC; never resources without matching tags.

Always tear down (or at least `make aws-stop`) when you're done practicing,
to avoid ongoing AWS charges.

---

## Reliability notes

This flow has been run end-to-end against a real AWS account. A few
non-obvious pitfalls were found and fixed along the way — worth knowing if
you're editing these scripts:

* **SSM Run Command executes via `/bin/sh` (dash on Ubuntu), not bash.**
  Any script uploaded to a node this way has its `#!/usr/bin/env bash`
  shebang silently ignored (it's not exec'd as a file) and dash doesn't
  support `set -o pipefail`. `lib/kubernetes.sh`'s `ssm_run` wraps every
  uploaded script in a quoted `bash <<'EOF' ... EOF` heredoc so bash-isms
  and `pipefail` actually work. Don't remove that wrapper.
* **`some-command | head -n1` can SIGPIPE the producer under `pipefail`.**
  `head` closes its end of the pipe once it has its line; if the producer
  is still writing, it can be killed with SIGPIPE (exit 141), which
  `pipefail` then reports as the pipeline's failure — even though the
  output you wanted was already printed. This is racy, not deterministic
  (it hit one node out of three in testing). The fix used throughout this
  codebase is `cmd | { head -n1; cat >/dev/null; }`, which drains the rest
  of the pipe instead of closing it early.
* **`kubeadm.config.template`'s `audit-log-path` requires the parent
  directory to exist first.** `kube-apiserver` doesn't create
  `/var/log/kubernetes/` itself; `control-plane-setup.sh` runs
  `mkdir -p /var/log/kubernetes` immediately before `kubeadm init` for
  this reason — without it, control-plane init fails outright.
* **`sed`'s delimiter must not collide with the substituted value.**
  `install-addons.sh` templates `POD_CIDR` (e.g. `10.244.0.0/16`, which
  contains `/`) into a manifest locally before upload; it uses `#` as the
  `sed` delimiter rather than `/` for this reason.
