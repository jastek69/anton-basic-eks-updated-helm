
# KONG
“Kong gives a central place to manage inbound traffic, path routing, and later security policies. It separates application logic from traffic control.”

1. Diagram
Make A simple traffic-flow diagram:
Client
  |
  |  (API Key required)
  v
Kong Gateway
  |
  v
Service
  |
  v
Pods

2. Change YAML Deployment Service Ingress

3. Test evidence kubectl get output curl success output one failure case and explanation

4. Reflection: Why would an organization want Kong in front of services instead of exposing each app directly?

5. Add.....
/hello /weather /status

all through Kong.

Project objective:
- deploy a simple “hello” application
- create a Service for it
- expose it with Kong
- test access through a route like /hello

Lab flow
## Phase 1 — Deploy the application
Use a tiny echo app or hello app.

Example deployment:
Hello App: https://github.com/BalericaAI/kubernetesclass/blob/main/Project5_Kong/yaml/helloapp.yaml

## Phase 2 — Create the Service

Hello Service: https://github.com/BalericaAI/kubernetesclass/blob/main/Project5_Kong/yaml/helloservice.yaml

Verify

    kubectl get pods
    kubectl get svc

## Phase 3 — Install Kong
Install via Helm:
```
    helm repo add kong https://charts.konghq.com
    helm repo update
    
    kubectl create namespace kong
    
    helm install kong kong/ingress -n kong
```

Then verify:
```
    kubectl get pods -n kong
    kubectl get svc -n kong
```
Questions:
  1) What is the controller pod?
  2) What is the proxy Service?
  3) Waht is the namespace separation?

## Phase 4 — Expose the app through Kong with Ingress
Example Ingress:
Kong Ingress: https://github.com/BalericaAI/kubernetesclass/blob/main/Project5_Kong/yaml/kong_helloingress.yaml

Expected result:
```

        Hello from Kong Lab 1
```

KIC documentation explains that it processes Kubernetes resources marked for its ingress class and translates them into Kong configuration.

Question Time:
```
        Where is the application actually running?
        What object exposes the Pods internally?
        What object tells Kong how to route traffic?
        What happens if I request /hello?
        What happens if I request /wrongpath?
```

Useful Commands:
```
        kubectl get pods
        kubectl get svc
        kubectl get ingress
        kubectl describe ingress hello-ingress
        kubectl logs -n kong <kong-controller-pod>
```

Learning Points to Remember:
```
        the Deployment manages Pods
        the Service abstracts Pod access
        the Ingress defines external routing intent
        Kong is the gateway enforcing that routing
        clients do not talk directly to Pods
```

Let's make some Errors and see what happens.

Failure A — Wrong service name
Change: name: hello-service
To: name: hello-servicex

What happens?

Failure B — Wrong target port
Change: targetPort: 5678
To: targetPort: 9999

What happens?

Failure C — Wrong path expectation
Remove strip-path annotation or change path behavior.

What Happens?


# Kong Part 2 — Security Plugins (API Protection)

Protect Kubernetes Services with Kong Authentication:
In Kong Part 1:---> Kong decided where traffic goes
In Kong Part 2:---> Kong decides who is allowed to send traffic

Goal:  “Oh… I can block access to services without touching application code.”

That's O'Block OG gangster power 

Learning Objectives:
By the end of this Project 2:

    enforce authentication at the gateway level
    understand consumer identity in Kong
    configure an API key authentication plugin
    observe 401 vs 200 behavior
    troubleshoot broken auth configurations


Starting Point (From Kong Project 1)

You should already have:

        hello-app (Deployment)
        hello-service
        hello-ingress
        working endpoint:

Verify: curl http://<KONG>/hello

Response: Hello from Kong Lab 1

Phase 1 — Prove It's Open (Baseline)

Notice.... curl http://<KONG>/hello .... anyone can do this.... maybe you have Lizzo pics there.....

Phase 2 — Enable API Key Authentication

        Kong uses plugins for security.
        
        We will use: --> key-auth plugin
        This forces requests to include an API key.


Apply API Plugin to Ingress: https://github.com/BalericaAI/kubernetesclass/blob/main/Project6_Kong/yaml/kong_plugin_api.yaml

    kubectl apply -f kong_plugin_api.yaml

Attach this yaml:  https://github.com/BalericaAI/kubernetesclass/blob/main/Project5_Kong/yaml/kong_helloingress.yaml

    kubectl apply -f apply_key_ingress.yaml

Phase 3 — Test (Should Fail)

Verify: curl http://<KONG>/hello

What happened?

Phase 4 — Give Galactus Access
Apply Galactus: https://github.com/BalericaAI/kubernetesclass/blob/main/Project6_Kong/yaml/galactus.yaml

kubectl apply -f galactus.yaml


Phase 5 — Create API Key Credential
Apply API Key Cred: https://github.com/BalericaAI/kubernetesclass/blob/main/Project6_Kong/yaml/chewbacca_key.yaml

    kubectl apply -f galactus_key.yaml

Phase 6 — Test With API Key

curl http://<KONG>/hello -H "apikey: super-secret-key"
What happens?

Let's verify 

        kubectl get kongplugin
        kubectl get kongconsumer
        kubectl get kongcredential
        kubectl describe ingress hello-ingress




## Deliverables
Submit:

1. Evidence
curl without key → 401
curl with key → 200

2. YAML
KongPlugin
KongConsumer
KongCredential

3. Explanation

Question:  “Where is authentication enforced?”

Correct answer: “At the Kong gateway, before traffic reaches the service.”


Reflection:

    Why is this better than coding auth inside every app?
    What happens if you have 50 microservices?
    What team would own Kong in a company?


Real-World Mapping

This maps directly to:

| Concept            | Real Job Role     |
| ------------------ | ----------------- |
| Kong plugin config | Platform Engineer |
| API authentication | Security Engineer |
| consumer identity  | IAM Engineer      |


__________



# Part 3
Kong Lab 3 — Rate Limiting
Control API Abuse with Kong Rate Limiting

architecture:
```
Client
  |
  |  (Authenticated or unauthenticated traffic)
  v
Kong Gateway
  |
  |  Rate Limiting Plugin
  v
Service
  |
  v
Pods
```


Big Idea

A) In Kong Lab 2:--> Kong decided who may access the API.
B) In Kong Lab 3:--> Kong decides how much access is permitted.

This is the platform lesson:--> A valid user can still be a problem.”

Project Objectives:

    explain what rate limiting is and why it matters
    apply Kong’s rate-limiting plugin using a KongPlugin
    enforce a per-minute request cap
    generate request floods with curl loops or k6a
    observe 200 OK changing into 429 Too Many Requests
    understand the difference between unauthenticated abuse and authenticated overuse

Kong’s KIC docs specifically show rate limiting by creating a KongPlugin with plugin: rate-limiting
and setting config.minute to the allowed number of requests per minute, then associating it with a
Kubernetes resource using konghq.com/plugins


Scenerio

        “You locked the API with authentication. Good.
        Then Chewbacca sends 10,000 Lizzo pic requests.
        Your app is still dead.
        Fix it without touching application code.”
        
        That is a real platform-engineering problem.


Starting Point

You should already have from prior labs:

        hello-app
        hello-service
        hello-ingress
        optional Lab 2 key auth working

They should be able to hit

curl http://<KONG>/hello
or
curl http://<KONG>/hello -H "apikey: super-secret-key"


Phase 1 — Rate Limiting Purpose

Let's think..... Why rate limiting exists
        protect services from accidental floods
        reduce damage from abusive clients
        preserve application availability
        create predictable API behavior

Kong describes rate limiting as controlling how many requests a client can make within a specified period, and frames it as a core availability and traffic-control function


Phase 2 — Create the Rate Limiting Plugin

For the first version, keep it simple: rate-limit-plugin.yaml: https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/yaml/rate-limit-plugin.yaml

        kubectl apply -f rate-limit-plugin.yaml

What this means
        allow 5 requests per minute
        after that, Kong starts rejecting requests
        policy: local is fine for a basic single-node/small-class lab

Phase 3 — Attach the Plugin

You can attach plugins to an Ingress, Service, HTTPRoute, KongConsumer, or other supported resources using konghq.com/plugins. For this lab, attaching it to the Ingress keeps the mental model simple.

Apply Ingress_Rate_Limit_Ingress.yaml
https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/yaml/ingress_rate_limit_plugin.yaml

        kubectl apply -f  Ingress_Rate_Limit_Ingress.yaml

Phase 4 — Test Slowly First

First, prove the API still works under normal use.

        curl http://<KONG>/hello
        curl http://<KONG>/hello
        curl http://<KONG>/hello

If Kong Lab 2 key-auth is still enabled:

        curl http://<KONG>/hello -H "apikey: super-secret-key"
        curl http://<KONG>/hello -H "apikey: super-secret-key"
        curl http://<KONG>/hello -H "apikey: super-secret-key"

Phase 5 — Trigger the Limit

Now make them exceed the cap.

Simple bash loop

Without auth: https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/bash/simpleloop.sh
With auth: https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/bash/keyloop.sh

Apply

        ./simpleloop.sh
        ./keyloop.sh

What happens?

Phase 6 — Use k6 for a Realer Flood

k6 is an open-source load-testing tool designed for running scripted HTTP load tests, and its docs walk through writing a simple test script and running it locally.

rate-test.js            https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/javascript/rate-test.js
key_rate-test.js        https://github.com/BalericaAI/kubernetesclass/blob/main/Project7_Kong/javascript/key_rate-test.js

Run it!

        k6 run rate-test.js
        k6 run key_rate-test.js

What happens?

## Testing - Failure Injection

Failure Injection

Now the fun part.

### Failure A — Limit Too Low

Set:
config:
  minute: 1

What happens?

### Failure B — Plugin Not Attached

Create the KongPlugin, but forget: --> konghq.com/plugins: rate-limit-plugin

What happens?

### Failure C — Wrong Target Resource

Attach rate limiting somewhere unexpected or incorrectly.

### Failure D — Student Confuses Auth Failure with Rate Limit Failure

You forget the API key and see:

    401 Unauthorized

Then later with a valid key they get:

    429 Too Many Requests

Lesson:
identity failure and quota failure are different states


## Objectives:
1. YAML
KongPlugin for rate limiting
updated Ingress annotation

2. Evidence
successful low-volume requests
flood evidence showing 429 Too Many Requests

3. Short explanation

Answer this: --> Where is request throttling enforced?

Correct answer:--> At Kong, before the upstream Kubernetes service handles the request.


Required Verification Commands

    kubectl get kongplugin
    kubectl describe ingress hello-ingress
    kubectl get svc
    kubectl get pods
    kubectl logs -n kong <kong-controller-pod>
    k6 run rate-test.js

Reflection Questions

    Why is authentication alone not enough?
    Why should rate limiting happen at the gateway instead of inside every microservice?
    What is the difference between 401, 403, and 429?
    How could a bad rate limit configuration break production?