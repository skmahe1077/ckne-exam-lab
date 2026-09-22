# Security Remediation: Exposed Private Key

## Summary

This repository's Git history contains a committed private key file:

```text
kubeadm-setup/aws-new.pem
```

A private key that has ever been committed to a Git repository — especially
one pushed to a remote such as GitHub — **must be treated as permanently
compromised**, even after the file is deleted from the working tree or a
later commit. Anyone with read access to the repository (including through
forks, cached clones, or GitHub's own history/API) may have already
retrieved it.

This document explains what has been done automatically, and what you must
do manually. No AWS resources were touched and no Git history was rewritten
by this remediation — both require explicit action from you.

## What was done automatically

1. `kubeadm-setup/aws-new.pem` was removed from the working tree and staged
   for removal (`git rm`) — it no longer exists on disk and, once you
   commit, will no longer exist in the tip of the branch. **It still exists
   in every prior commit until you rewrite history (see below).**
2. `.gitignore` was updated with `*.pem` (and other credential patterns) so
   a private key cannot be accidentally re-added and committed.
3. The file's contents were never displayed, printed, or inspected as part
   of this remediation.

## What you must do manually

### 1. Revoke the corresponding AWS key pair (do this first, do this now)

The EC2 key pair that `aws-new.pem` corresponds to must be deleted or
rotated in AWS. Deleting the key pair does **not** invalidate keys already
authorized on running instances (the public key is baked into
`~/.ssh/authorized_keys` on any instance launched with it), so also do the
following:

```bash
# 1. Identify the key pair (adjust region as needed)
aws ec2 describe-key-pairs --region <your-region>

# 2. Delete the compromised key pair so it can no longer be used to launch new instances
aws ec2 delete-key-pair --key-name aws-new --region <your-region>

# 3. On any EXISTING instance that was ever launched with this key,
#    remove the corresponding public key from the ubuntu user's
#    authorized_keys (run this on the instance itself, e.g. via SSM
#    Run Command or Session Manager, not via the compromised key):
#      sudo sed -i '/<comment-or-fingerprint-of-aws-new-key>/d' /home/ubuntu/.ssh/authorized_keys
#
# 4. If you are unsure which instances used this key, the safest option is
#    to terminate and recreate them with a new key pair (or, per this
#    repository's new design, with SSM Session Manager and no key pair at
#    all — see kubeadm-setup/config/cluster.env.example, EC2_KEY_NAME="").
```

If this key pair was ever used outside this lab environment, rotate it
there too. Assume the key is public.

**This step has not been performed for you.** Deleting an AWS key pair is a
destructive, account-affecting action and must be a deliberate choice made
by you, in your own AWS account, with your own credentials.

### 2. Remove the key from Git history (optional but recommended)

Removing the file from the current commit is not enough — it is still
readable in every earlier commit (`git log --all --full-history -- kubeadm-setup/aws-new.pem`,
`git show <old-commit>:kubeadm-setup/aws-new.pem`). If this repository has
already been pushed to GitHub, also consider that GitHub caches objects and
may have indexed the blob independently of your local history rewrite —
rotating the AWS key (Step 1) is the only remediation that actually
neutralizes the exposure. History rewriting is about hygiene, not safety,
once the key has been rotated.

If you still want to scrub the blob from history, use
[`git filter-repo`](https://github.com/newren/git-filter-repo) (the tool
GitHub itself recommends; do **not** use the older `git filter-branch` or
BFG unless you already prefer them):

```bash
# Install (one-time)
pip install git-filter-repo   # or: brew install git-filter-repo

# From a FRESH CLONE of the repository (filter-repo refuses to run
# in a clone that has a remote configured, and rewrites are safest
# starting from a disposable copy):
git clone git@github.com:skmahe1077/cks-exam-practise.git cks-exam-practise-history-scrub
cd cks-exam-practise-history-scrub

# Remove the file from every commit in history:
git filter-repo --path kubeadm-setup/aws-new.pem --invert-paths

# Review the result BEFORE pushing anywhere:
git log --all --oneline -- kubeadm-setup/aws-new.pem   # should print nothing
git log --oneline | head

# Only once you are satisfied, force-push the rewritten history.
# This rewrites every commit hash after the point the file was introduced,
# and will break any other clone/fork/branch that isn't also reset:
#   git remote add origin git@github.com:skmahe1077/cks-exam-practise.git
#   git push origin --force --all
#   git push origin --force --tags
```

**This step has not been performed for you.** Rewriting published history
is a destructive, hard-to-reverse operation that affects anyone else with a
clone of this repository, and must be a deliberate choice made by you.

### 3. Do not commit a replacement key

Do not add a new `.pem` file to this repository to replace the removed one
— `.gitignore` now blocks `*.pem` from being committed. The redesigned
infrastructure scripts (see `kubeadm-setup/config/cluster.env.example`)
default to **AWS Systems Manager (SSM) Session Manager** for node access,
which requires no SSH key pair at all. SSH access via `EC2_KEY_NAME` is
supported only as an explicit, opt-in fallback (`ENABLE_SSH=true`); if you
enable it, keep the private key outside this repository (e.g. in
`~/.ssh/`) and never `git add` it.

## Checklist

- [ ] AWS key pair `aws-new` deleted or rotated in every region/account it existed in
- [ ] Any running EC2 instance that trusted this key had its `authorized_keys` cleaned or was recreated
- [ ] (Optional) Git history scrubbed with `git filter-repo` and force-pushed, with collaborators notified to re-clone
- [ ] No new `.pem`/`.key`/`.p12`/`.pfx`/`.env`/`kubeconfig*` files committed going forward
