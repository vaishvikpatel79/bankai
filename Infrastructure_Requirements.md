# Kubernetes Infrastructure Requirement

## Project Information

| Field | Value |
|---|---|
| Project Name | bankai |
| Cloud Provider | kubernetes |
| Environment | dev |
| Deployment Platform | Kubernetes |
| Architecture Type | 2-tier |
| Application Exposure | Public |
| Resource Naming Prefix | bankai-dev |
| Kubernetes Namespace | bankai-dev-ns |
| Kubernetes Cluster | devops-testing |

---

# 1. Application Services

The application consists of two services:

| Service | Container Image | Role |
|---|---|---|
| Backend | `bankai-backend:v1` | Backend API |
| Frontend | `bankai-frontend:v1` | Frontend application |

---

# 2. Backend Requirements

| Field | Value |
|---|---|
| Service Role | Backend API |
| Container Image | `bankai-backend:v1` |
| Container Port | 8000 |
| Protocol | HTTP |
| Replicas | 1 |
| Health Check | Enabled |
| Health Check Path | `/health` |

The backend must be reachable by the frontend application.

---

# 3. Frontend Requirements

| Field | Value |
|---|---|
| Service Role | Frontend |
| Container Image | `bankai-frontend:v1` |
| Container Port | 80 |
| Protocol | HTTP |
| Replicas | 1 |

The frontend must be accessible from the user's browser.

---

# 4. Service Communication (Computed — not a static environment variable)

| Field | Value |
|---|---|
| Communication | Frontend → Backend |
| Caller Context | User's browser (client-side JavaScript, not the Frontend Pod) |
| Protocol | HTTP |
| Backend Port | 8000 |
| Backend Accessibility | Required from the user's browser |
| Environment Variable Name | `VITE_API_URL` |
| Frontend API Configuration | Backend URL must be configurable through this environment variable |

The frontend is a browser-rendered (Vite) application. All calls to the backend API
are made directly from the user's browser using `VITE_API_URL`, not from within the
Frontend Pod. This means the backend URL supplied to the frontend must be reachable
from outside the Kubernetes cluster — a cluster-internal Service DNS name
(e.g. `http://backend-svc:8000`) is NOT reachable from the browser and must not be used
for this variable.

`VITE_API_URL` is a **computed** variable: its value is the backend Service's own
NodePort address, resolved entirely by Terraform at apply time (node IP + the
backend's pinned NodePort). It is NOT a static value and must NOT also appear in the
Environment Configuration tables below — it is fully described here and only here.

The backend must be accessible from the user's browser because the frontend API requests
are made from the browser, not from server-side/Pod-to-Pod code.

---

# 5. Application Exposure

| Field | Value |
|---|---|
| Frontend Exposure | Public |
| Backend Exposure | Public |
| Local Testing Platform | Kind |
| External Access Method | NodePort |

For local Kind testing, both services should be reachable using their NodePort and the
Kind node's IP address. `kubectl port-forward` may additionally be used for ad-hoc
developer testing, but NodePort is the exposure mechanism the deployment must configure.

---

# 6. Environment Configuration

Environment variables below are split into **Non-Sensitive** (delivered as literal
values directly in the Terraform configuration) and **Sensitive** (never written into
Terraform in any form — referenced from a Kubernetes Secret that already exists in the
cluster before `terraform apply` runs; see Section 10 for how that Secret must be
created).

## 6.1 Frontend — Non-Sensitive Environment Variables

| Variable | Value | Sensitive |
|---|---|---|
| *(none — see Section 4: `VITE_API_URL` is computed, not static)* | | |

## 6.2 Frontend — Sensitive Environment Variables

None.

## 6.3 Backend — Non-Sensitive Environment Variables

| Variable | Value | Sensitive |
|---|---|---|
| `DATABASE_URL` | `sqlite:///./app.db` | No |
| `CORS_ORIGINS` | `http://localhost:3000` | No |
| `PORT` | `8000` | No |
| `ACCESS_TOKEN_EXPIRE_MINUTES` | `60` | No |
| `ENVIRONMENT` | `development` | No |

## 6.4 Backend — Sensitive Environment Variables

| Variable | Sensitive | Secret Name | Secret Key |
|---|---|---|---|
| `JWT_SECRET_KEY` | Yes | `bankai-dev-backend-secret` | `JWT_SECRET_KEY` |

Sensitive configuration values must not be hardcoded into the container image, must
never be written into Terraform state or `.tfvars`, and must never be passed as a
`terraform apply` input. The Secret named above must already exist in the
`bankai-dev-ns` namespace before `terraform apply` runs — Terraform only references it
by name via a data lookup; it never creates or manages its value.

---

# 7. Health Requirements

## Backend

| Field | Value |
|---|---|
| Health Check Enabled | Yes |
| Path | `/health` |
| Port | 8000 |
| Protocol | HTTP |

## Frontend

| Field | Value |
|---|---|
| Health Check | Required |
| Port | 80 |
| Protocol | HTTP |

---

# 8. Deployment Requirements

The application must support deployment of both services into the same Kubernetes environment.

The frontend and backend must be independently deployable.

The backend must remain reachable by the frontend after Pod recreation.

The deployment configuration must support the specified container images and their versions.

Deployment is performed with a single `terraform apply` — there is no multi-step or
targeted-apply workflow. Everything Terraform itself cannot create in one pass (the
namespace, the backend Secret) is a prerequisite established before that one apply
runs, not a step performed by Terraform.

---

# 9. Cluster Connection

| Field | Value |
|---|---|
| Connection Method | kubeconfig |
| kubeconfig Context | kind-devops-testing |

Terraform connects to the existing `devops-testing` Kubernetes cluster using a
user-supplied kubeconfig file. The kubeconfig file path is provided at apply time and
must not be hardcoded into any Terraform file.

---

# 10. Namespace & Secret Prerequisites

The following must already exist in the cluster **before** `terraform apply` is run.
Terraform reads them via data lookups — it does not create or manage them, because
Secrets are namespace-scoped and this deployment uses exactly one `terraform apply`
with no intermediate step to create the namespace first.

| Field | Value |
|---|---|
| Namespace (must pre-exist) | `bankai-dev-ns` |
| Secret (must pre-exist in that namespace) | `bankai-dev-backend-secret` |
| Required key(s) in that Secret | `JWT_SECRET_KEY` |

Example one-time setup, run before the first (and only) `terraform apply`:

```bash
kubectl create namespace bankai-dev-ns
kubectl create secret generic bankai-dev-backend-secret \
  --from-literal=JWT_SECRET_KEY=<actual-value> \
  -n bankai-dev-ns
```

---

# Outputs Required

- Kubernetes Namespace
- Frontend Deployment Name
- Backend Deployment Name
- Frontend Service Name
- Backend Service Name
- Frontend Endpoint (NodePort)
- Backend Endpoint (NodePort)