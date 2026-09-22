# Hints — OBS-01

## Level 1

Start with the namespace-wide Events, then look at the Pods themselves:

```bash
kubectl -n ckne-obs-01 get events --sort-by=.lastTimestamp
kubectl -n ckne-obs-01 get pods -o wide
```

What restart-related Warning events do you see? How many times has each
netprobe Pod restarted?

## Level 2

Read what the application itself logged right before it died:

```bash
kubectl -n ckne-obs-01 logs -l app=netprobe --tail=20
kubectl -n ckne-obs-01 logs -l app=netprobe --previous --tail=20
```

The error line names the exact URL netprobe tried to reach. Compare that
hostname against the real Service:

```bash
kubectl -n ckne-obs-01 get svc
```

## Level 3

```bash
kubectl -n ckne-obs-01 get deployment netprobe -o yaml | grep -A2 TARGET_URL
```

The env var's hostname doesn't match any existing Service name in the
namespace. Nothing about `backend` needs to change — only netprobe's
`TARGET_URL`.
