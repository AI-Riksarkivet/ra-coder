# Docker Hub Secret Configuration

To pull images from the private Docker Hub repository `riksarkivet/coder-workspace-ml`, you need to create a Kubernetes secret with your Docker Hub credentials.

## Creating the Docker Hub Secret

Run this command to create the secret in your namespace:

```bash
kubectl create secret docker-registry dockerhub-secret \
  --docker-server=docker.io \
  --docker-username=YOUR_DOCKERHUB_USERNAME \
  --docker-password=YOUR_DOCKERHUB_TOKEN \
  --docker-email=YOUR_EMAIL \
  -n YOUR_NAMESPACE
```

Replace:
- `YOUR_DOCKERHUB_USERNAME` with your Docker Hub username
- `YOUR_DOCKERHUB_TOKEN` with your Docker Hub access token or password
- `YOUR_EMAIL` with your email address
- `YOUR_NAMESPACE` with the Kubernetes namespace where you're deploying workspaces

## Using a Custom Secret Name

If you want to use a different secret name, update the `docker_registry_secret` variable when deploying the template:

```hcl
variable "docker_registry_secret" {
  default = "your-custom-secret-name"
}
```

## Verifying the Secret

To verify the secret was created correctly:

```bash
kubectl get secret dockerhub-secret -n YOUR_NAMESPACE
kubectl describe secret dockerhub-secret -n YOUR_NAMESPACE
```

## Note

The secret must exist in the same namespace as the Coder workspaces before creating any workspace instances.