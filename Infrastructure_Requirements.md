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
This computed value is delivered to the Frontend Pod as a key inside the Frontend's
ConfigMap (see Section 6), not as a separate standalone variable.

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

All environment configuration is delivered through Kubernetes ConfigMaps and Secrets —
never as individual standalone container environment entries. **Non-Sensitive**
values (including the computed `VITE_API_URL` from Section 4) are grouped into one
ConfigMap per service, populated directly from this document. **Sensitive** values are
grouped into one Secret per service, created and managed by this same Terraform
configuration — their actual values are supplied as `terraform apply` inputs
(via `-var` or an untracked `.tfvars` file), never written into this document, never
pre-created out-of-band, and never given a default.

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

The Secret named above is created and managed by this Terraform configuration. Its
value is never hardcoded into the container image or this document, and is supplied
by the operator at `terraform apply` time (e.g. `-var 'backend_secret_data={"JWT_SECRET_KEY"="<actual-value>"}'`
or an untracked `.tfvars` file) — never given a default, never pre-created via
`kubectl` before apply.

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
targeted-apply workflow. Terraform creates everything this deployment needs, including
the namespace and the backend Secret, within that one apply — the only inputs supplied
from outside Terraform are the kubeconfig path (Section 9) and the sensitive Secret
values (Section 6.4), both passed as apply-time inputs, not pre-created infrastructure.

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

# Outputs Required

- Kubernetes Namespace
- Frontend Deployment Name
- Backend Deployment Name
- Frontend Service Name
- Backend Service Name
- Frontend Endpoint (NodePort)
- Backend Endpoint (NodePort)
