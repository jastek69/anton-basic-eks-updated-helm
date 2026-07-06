# Kubernetes - Helm, Kong, OPA 

## Requirements (do these first, before installing Kong)

**Configuration**
1. Apply Terraform to build infrastructure
current infrastructure:
- VPC
- subnets
- EKS Cluster
- Node Group
- OIDC Provider via Heml release (11b-storage-helm.tf) - install EBS and storage driver
- `12-runtime.tf` `null_resource.update_kubeconfig` runs `aws eks update-kubeconfig` so kubectl is pointed to the new cluster after `terraform apply`

Verify:
```
kubectl get nodes
kubectl get pods -n kube-system   # look for ebs-csi-controller/-node pods Running
```

**Gateway API CRDs** — KIC 3.x (the `kong/ingress` Helm chart) uses the Gateway API's status-condition
model for all its CRDs, including `KongConsumer`, even when only classic `Ingress` objects are used.
Without these installed, consumer/credential reconciliation silently never completes.
([KIC 3.x prerequisites](https://docs.konghq.com/kubernetes-ingress-controller/latest/install/prerequisites/))
```
kubectl apply -f https://github.com/kubernetes-sigs/gateway-api/releases/download/v1.1.0/standard-install.yaml
```

**RBAC for cross-namespace Secrets** — the Kong controller's ServiceAccount (`kong-controller`, in the
`kong` namespace) can only read Secrets in its own namespace by default. Consumer credential Secrets
(e.g. `galactus-key-auth`) live in `default`, so grant it read access there too:
```
kubectl apply -f yaml/kong_controller_secrets_rbac.yaml
```

After applying either of these for the first time, restart the controller so it picks them up:
```
kubectl rollout restart deployment/kong-controller -n kong
kubectl rollout status deployment/kong-controller -n kong --timeout=90s
```

**Install k6:**
Option 1 — winget

winget install k6 --source winget
(We checked earlier and winget wasn't found on this machine, so this will likely fail — worth a quick try anyway since PATH/tools can change.)

Option 2 — Chocolatey (same tool that failed for helm, but worth trying since outages are usually transient):
`choco install k6 -y`

Option 3 — direct binary download
Download the official Windows zip from k6's GitHub releases, extract k6.exe, and drop it in the same AppData\Local\Programs convention already on your PATH from the helm install.


## Hardware considerations:

***Instance Size***
Memory:
- t3.medium has 4 GiB RAM
- t3.large has 8 GiB.

CPU:
- both have 2 vCPU;
- t3.large gets more burst credit headroom, not more cores.

Max pods per node:
Note: AWS's VPC CNI caps pods-per-node based on ENI slots × IPs-per-ENI for that instance type, independent of CPU/memory.
- `t3.medium` caps at 17 pods
- `t3.large` caps at 35 pods

If you were going to hit a wall with this workload, it's more likely this ceiling than raw CPU/memory, since Kong + EBS CSI + hello-app are all lightweight.


***Node capacity***
`desired_size` - impacts total cluster capacity across nodes, plus redundancy. 
- `min_size=0, desired_size=1`: is a single node. If that node gets replaced (patch, AZ issue, a node group update using max_unavailable=1), everything on it — including Kong itself — goes down until a replacement joins. A second node gives you a place for pods to land during that gap.


Rough math for actual workload on one node:
- kube-system daemonsets/controllers (coredns, kube-proxy, aws-node, ebs-csi-controller, ebs-csi-node) ≈ 6-7 pods
- Kong controller+proxy ≈ 1-2 pods
- hello-app (2 replicas) ≈ 2 pods → roughly 10-11 pods total.

With this projects configuration:
- This is under t3.medium's 17-pod ceiling, as a caution, in larger applications it could be an issue.
- The node group is 1× t3.medium (desired_size=1). Between Kong's controller+proxy, the EBS CSI driver, hello-app, and standard EKS system pods,which  may get tight — if pods stay Pending, scale it (Terraform won't do it because desired_size is in lifecycle.ignore_changes in `08-node.tf:92`):

```
aws eks update-nodegroup-config --cluster-name demo --nodegroup-name private-nodes --scaling-config desiredSize=2 --region us-west-2
```

Reccommended configuration:
Note these values can be set inside the `00-variables.tf`:
`t3.large`: provides enough headroom for pod-count and memory and a cheaper option than running 2 nodes.
`desired_size=2`: for node level redundancy - prevent Kong going dark during node replacement due to hitting a scheduling ceiling. If you see `Pending` pods consider using these settings

2. Install Kong (manual install see Kong_README.md Phase 3)
```
helm repo add kong https://charts.konghq.com
helm repo update
kubectl create namespace kong
helm install kong kong/ingress -n kong
kubectl get pods -n kong
kubectl get svc -n kong        # note the LoadBalancer EXTERNAL-IP/hostname — call it <KONG>
```

`<KONG>` is a placeholder for the external hostname of the Kong proxy's LoadBalancer Service

To place is as a variable:
```
KONG=$(kubectl get svc -n kong -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}')
echo $KONG
curl http://$KONG/hello
```


This will work without extra IAM setup because your public subnets already carry kubernetes.io/role/elb=1 (03-subnets.tf), which is what EKS's in-tree cloud provider needs to provision a Classic ELB for the kong-proxy Service.

3. Deploy the hello app
```
kubectl apply -f yaml/kong_helloapp.yaml
kubectl apply -f yaml/kong_helloservice.yaml
kubectl get pods
kubectl get svc
```

4. Confirm Ingress
```
vim yaml/kong_helloingress.yaml
```
In VIM confirm it contains correct Ingress settings: (`kind: Ingress`, `ingressClassName: kong`, routing `/hello` → `hello-service:80`, no plugin annotation).

Note:
`<KONG>`is the loadbalancer External IP value from `get svc` command above
example:
```
KONG=a00870e550db746b8931a98d0aed1450-1278373616.us-west-2.elb.amazonaws.com
```

```
kubectl apply -f yaml/kong_helloingress.yaml
curl http://$KONG/hello        # expect "Hello from Kong Lab 1"

```

5. Key-auth (Part 2)
```
kubectl apply -f yaml/kong_plugin_api.yaml       # KongPlugin: key-auth-plugin
kubectl apply -f yaml/apply_key_ingress.yaml      # replaces hello-ingress with the plugin attached
kubectl apply -f yaml/galactus_key.yaml           # Secret credential (key-auth), key: super-secret-key
kubectl apply -f yaml/galactus.yaml               # KongConsumer (your "Galactus" stand-in)

curl http://$KONG/hello                                  # expect 401
curl http://$KONG/hello -H "apikey: super-secret-key"    # expect 200
```

Note: `galactus.yaml`'s `KongConsumer` must carry the annotation `kubernetes.io/ingress.class: kong` — the
older, non-`konghq.com`-prefixed key. (`konghq.com/ingress.class` looks like the more modern choice and was
tried first, but the controller's debug logs kept showing `"Object missing ingress class, ensuring it's
removed from configuration"` even with it set — switching to `kubernetes.io/ingress.class` immediately
flipped it to `"Object has matching ingress class"` / `"configuration_status": "Succeeded"`.) A `KongPlugin`
inherits its ingress class from the `Ingress` it's attached to, but a standalone `KongConsumer` has nothing
to inherit from — without the correct annotation the controller silently drops it from Kong's config, so
any API key gets rejected as `Unauthorized` even though the consumer/credential objects exist fine in
Kubernetes.

 Real credentials are plain Kubernetes Secret objects labeled `konghq.com/credential: key-auth`, referenced from the `KongConsumer`'s `credentials:` list. Fixed by rewriting `galactus_key.yaml` as a `Secret` and adding `credentials: [galactus-key-auth]` to `galactus.yaml`.


Troubleshooting (if still Unauthorized with a valid key):
```
kubectl get kongconsumer galactus -o yaml                      # check status.conditions
kubectl port-forward -n kong svc/kong-gateway-admin 8444:8444 &
curl -sk https://localhost:8444/consumers                      # should list galactus
curl -sk https://localhost:8444/key-auths                      # should list the credential
kill %1
```
If both come back empty, confirm the Requirements section at the top of this doc is actually applied, then
check the controller's debug logs for the specific exclusion reason:
```
helm upgrade kong kong/ingress -n kong --reuse-values --set controller.ingressController.env.log_level=debug
kubectl rollout status deployment/kong-controller -n kong --timeout=90s
kubectl logs -n kong deploy/kong-controller --tail=500 2>&1 | grep -i -E "galactus|ingress class|translat"
```

**6. Rate limiting (Part 3) — use the correct file pair**
Use: rate_limit_plugin.yaml + ingress_rate_limit_plugin.yaml — correctly reference hello-service and /hello.

```
kubectl apply -f yaml/rate_limit_plugin.yaml
kubectl apply -f yaml/ingress_rate_limit_plugin.yaml
```

Verify:
```
kubectl get ingress hello-ingress -o jsonpath='{.metadata.annotations.konghq\.com/plugins}'

# should print: rate-limit-plugin
```

Note: this replaces `hello-ingress`'s annotation with `rate-limit-plugin` only — since the ingress can carry
just one `konghq.com/plugins` value at a time, this also means `key-auth-plugin` from step 5 is no longer
attached (see the note on combining plugins in step 5's history if you want both active simultaneously).
So from this point on, requests succeed or fail based on rate, not on the `apikey` header.


**Combined Ingress Test**

Apply the `ingress_combined_plugins.yaml`
```
kubectl apply -f yaml/ingress_combined_plugins.yaml
kubectl get ingress hello-ingress -o jsonpath='{.metadata.annotations.konghq\.com/plugins}'
# should print: key-auth-plugin,rate-limit-plugin
```
Expected behavior with both active:
Kong evaluates plugins by internal priority, not annotation order — key-auth runs before rate-limiting in the request-access phase. So:

- No apikey header → still 401 immediately (key-auth blocks before rate-limiting is ever evaluated, doesn't count against the limit).
- Valid apikey: super-secret-key → passes auth, then subject to the minute: 5 cap tied to the galactus consumer (rate-limiting's default limit_by is consumer once one's identified via key-auth) → first ~5 authenticated requests return 200, then 429 for the rest within that minute.

***Revert back to rate-limit option:***
Once you're done testing the combined state, revert back to rate-limit only so step 7's default
expected results (below) stay valid as written:
```
kubectl apply -f yaml/ingress_rate_limit_plugin.yaml
kubectl get ingress hello-ingress -o jsonpath='{.metadata.annotations.konghq\.com/plugins}'
# should print: rate-limit-plugin
```
(If you'd rather leave the combined ingress applied and run the flood test against *that* state instead,
skip the revert and see the "Combined-state expected results" note under step 7.)


**7. Flood-test**
NOTE: 
- `bash/simpleloop.sh` and `bash/keyloop.sh` reference `$KONG`;
- `javascript/rate_test.js` and `javascript/key_rate_test.js` reference `__ENV.KONG` (k6's mechanism for external variables — it does not automatically inherit shell-exported variables, so it must be passed explicitly with `-e` on the command
line).

Export `$KONG` once (reuse the value from step 2/4 — re-derive it if you're in a new shell):
```
export KONG=$(kubectl get svc -n kong -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}')
```

Then run:
```
bash bash/simpleloop.sh
bash bash/keyloop.sh
k6 run -e KONG=$KONG javascript/rate_test.js       # requires k6 installed locally
k6 run -e KONG=$KONG javascript/key_rate_test.js
```

Expected results:
- `bash/simpleloop.sh`: the first ~5 requests within the current minute window return `HTTP/1.1 200 OK`
  with body `Hello from Kong Lab 1`; once `rate_limit_plugin.yaml`'s `minute: 5` cap is exceeded, remaining
  requests return `HTTP/1.1 429 Too Many Requests` (with `X-RateLimit-*`/`RateLimit-*` headers) until the
  1-minute window resets.
- `bash/keyloop.sh`: same 200→429 pattern as above, **not** 401s — key-auth is no longer attached to the
  ingress at this point (see the note above), so the `apikey` header has no effect either way.
- `k6 run -e KONG=$KONG javascript/rate_test.js` / `key_rate_test.js`: with 5 VUs over 10s, only the first
  handful of requests (up to the shared `minute: 5` cap — `policy: local` tracks all traffic to the route
  together, not per-VU/consumer) return 200; the rest return 429 for the remainder of the run. Check k6's
  end-of-run summary for the status code breakdown.

Combined-state expected results (only applies if you skipped the revert step and `ingress_combined_plugins.yaml`
is still the live ingress — i.e. `konghq.com/plugins: key-auth-plugin,rate-limit-plugin`):
- `bash/simpleloop.sh` (no `apikey` header): **every** request returns `401 Unauthorized` — key-auth blocks
  before rate-limiting is ever evaluated, so you'll never see a 429 here, no matter how many requests run.
- `bash/keyloop.sh` (with `apikey: super-secret-key`): same 200→429 pattern as the rate-limit-only case —
  the first ~5 authenticated requests return 200, then 429 for the rest within that minute.
- `key_rate_test.js` (sends the `apikey` header): same 200→429 pattern as above. `rate_test.js` (no header)
  would show all 401s, same as `simpleloop.sh` — not particularly useful for exercising the rate limiter in
  this state, since it never gets past key-auth.


LOG Reports:

Capture a clean, trimmed record of the first 10 requests from a flood-test run into `./Reports/`. `head -n
40` on its own is **not** enough — it only previews lines in your terminal, the redirected file still
contains the full 100-request run. Use the `HTTP/1.1` markers themselves to cut at an exact request
boundary instead of guessing a line count (blank-line counting was tried and is unreliable — curl's
progress-meter output doesn't produce a consistent number of lines per request).

Prerequisite — export `$KONG` (re-derive if you're in a new shell):
```
export KONG=$(kubectl get svc -n kong -o jsonpath='{.items[?(@.spec.type=="LoadBalancer")].status.loadBalancer.ingress[0].hostname}')
```

`simpleloop.sh` — run fresh, trim to exactly the first 10 requests:
```
bash bash/simpleloop.sh > ./Reports/simpleloop-full.txt 2>&1
LINE=$(grep -n "HTTP/1.1" ./Reports/simpleloop-full.txt | sed -n '11p' | cut -d: -f1)
head -n $((LINE - 1)) ./Reports/simpleloop-full.txt > ./Reports/simpleloop-test.txt
grep -c "HTTP/1.1" ./Reports/simpleloop-test.txt   # sanity check: should print 10
rm ./Reports/simpleloop-full.txt
```

`keyloop.sh` — same pattern:
```
bash bash/keyloop.sh > ./Reports/keyloop-full.txt 2>&1
LINE=$(grep -n "HTTP/1.1" ./Reports/keyloop-full.txt | sed -n '11p' | cut -d: -f1)
head -n $((LINE - 1)) ./Reports/keyloop-full.txt > ./Reports/keyloop-test.txt
grep -c "HTTP/1.1" ./Reports/keyloop-test.txt      # sanity check: should print 10
rm ./Reports/keyloop-full.txt
```

Condensed status/quota view for either report file:
```
grep -oE "HTTP/1.1 [0-9]+|X-RateLimit-Remaining-Minute: [0-9]+" ./Reports/simpleloop-test.txt
```
Expect: 4 requests at 200 with `Remaining-Minute` counting down 4→1, a 5th 200 at 0 remaining, then 429 for
the rest — the same pattern documented under step 7's "Expected results" above.

Note on retrieving history from Kong's own gateway logs instead (`kubectl logs -n kong deploy/kong-gateway`):
this works, but the log buffer spans **every** test run you've done, not just your most recent one — a
plain `head`/`tail`/`grep` can easily pull stale entries from an earlier run (e.g. 401s from the key-auth
test) that look like a match but aren't from the run you're trying to document. Capturing client-side
output directly, as above, avoids that cross-run ambiguity entirely.

k6 reports — `rate_test.js`/`key_rate_test.js` don't log per-request status codes or define any `check()`s,
so a plain `k6 run ... > file` only captures the aggregated end-of-run summary, not a per-request
200/429 breakdown. Use `--http-debug="headers"` to dump full request/response info (status line +
headers) for every call instead:
```
k6 run --http-debug="headers" -e KONG=$KONG javascript/rate_test.js > ./Reports/rate_test.txt 2>&1
k6 run --http-debug="headers" -e KONG=$KONG javascript/key_rate_test.js > ./Reports/key_rate_test.txt 2>&1
```
This captures every request for the full run duration (not just the first 10 — `--http-debug` doesn't have
a request-count cutoff the way the bash loops do), so the report files will be longer; grep the same way as
above to pull out just the status/quota lines:

```
grep -oE "< HTTP/1.1 [0-9]+|< X-RateLimit-Remaining-Minute: [0-9]+" ./Reports/rate_test.txt | head -20
```

(`--http-debug` prefixes response lines with `<` and request lines with `>`, so filtering on a leading `<`
isolates the response side.)
