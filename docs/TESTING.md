# Testing

## Continuous integration

`.github/workflows/validate.yml` runs `terraform fmt -check` and `terraform validate` (no backend, no credentials), plus `bash -n` on the loop scripts.

## Platform verification (after apply)

| Check | Command | Expected |
|---|---|---|
| Nodes joined | `kubectl get nodes` | Private nodes `Ready` |
| CSI driver | `kubectl get pods -n kube-system \| grep ebs-csi` | Controller and node pods `Running` |
| Dynamic volumes | Install kube-prometheus-stack ([`CLUSTER-COMMANDS.md`](CLUSTER-COMMANDS.md)), then `kubectl get pvc -n observability` | PVCs `Bound` to EBS volumes |
| Kong ready | `kubectl get pods,svc -n kong` | Controller and proxy running, proxy has an external address |

## Ingress policy tests (k6 + curl)

| Test | File | What it does |
|---|---|---|
| Unkeyed load | `javascript/rate_test.js` | 5 VUs for 10 s against `/hello` with **no** key. Read the k6 summary's status distribution: 401 if key-auth is attached, 429 beyond 5/min otherwise. |
| Keyed load | `javascript/key_rate_test.js` | 5 VUs for 10 s **with** the consumer's key. The first 5 requests per minute get 200, the rest 429. |
| Curl loop | `bash/simpleloop.sh` | Sequential requests to watch rate-limit headers |
| Keyed curl loop | `bash/keyloop.sh` | 100 keyed requests. `X-RateLimit-Remaining-Minute` counts down, then 429. |

The k6 scripts generate load and **don't assert** (no `check()` or thresholds). Pass or fail is judged from the k6 summary and the captured headers. Set the proxy address first: `export KONG=<kong-proxy-lb-hostname>`.

```bash
k6 run javascript/rate_test.js
k6 run javascript/key_rate_test.js
./bash/keyloop.sh
```

**Captured evidence** in `Reports/`: `kong_install.JPG`, `kong_hello.JPG`, `kong_java_k6_ratetest.JPG`, `kong_java_k6_keytest.JPG`, `Kong_combinedTest.JPG`, `keyloop-test.txt`, `simpleloop-test.txt`. For example, `keyloop-test.txt` shows `X-RateLimit-Limit-Minute: 5` counting down on Kong 3.9.3.

## Known gaps

- **k6 scripts have no assertions.** Adding `check(res, {...})` and `thresholds` (for example, keyed 200s ≤ 5/min) would turn evidence screenshots into pass/fail runs.
- **No negative-key test is scripted.** A wrong key → 401 is verified manually only.
- **No ephemeral-cluster CI.** k6 runs need a live cluster. A kind or EKS job in CI could run them per PR.
- **Helm releases for Kong and monitoring are outside Terraform**, so their install isn't validated by `terraform validate`.
