# Kubernetes Local

Local Kubernetes cluster using Dagger and K3S.

## Functions

- `kube-server` - Start k3s with local registry
- `export-kubeconfig` - Export kubeconfig for host kubectl

## Usage

```bash
# Start k3s server with default name "test" (keep running)
dagger call kube-server up --ports 6443:6443

# Start k3s server with custom name (keep running)
dagger call kube-server --name="my-cluster" up --ports 6443:6443

# Export kubeconfig (in another terminal)
dagger call export-kubeconfig export --path=./kubeconfig.yaml

# Export kubeconfig for named cluster
dagger call export-kubeconfig --name="my-cluster" export --path=./my-cluster-kubeconfig.yaml

# Use with host kubectl
kubectl --kubeconfig=./kubeconfig.yaml get nodes
```check