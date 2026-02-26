# Argo Workflows for Coder Template Builds

This directory contains Argo Workflow resources for building Coder templates using Dagger.

## Important

## Files

- `workflow-template.yaml` - Reusable WorkflowTemplate for building Coder templates
- `cron-workflow.yaml` - CronWorkflow for nightly builds
- `secrets-example.yaml` - Example secrets configuration

## Setup

### 1. Create Required Secrets

First, create the necessary secrets in your cluster:

```bash
# Create GitHub SSH key secret for accessing private repo
kubectl create secret generic github-ssh-key \
  --from-file=ssh-privatekey=$HOME/.ssh/id_rsa \
  -n argo-workflow

# Create Docker registry credentials
kubectl create secret generic docker-registry-credentials \
  --from-literal=password="your-docker-password-or-token" \
  -n argo-workflow

# Optional: Create Dagger Cloud token
kubectl create secret generic dagger-cloud-token \
  --from-literal=token="your-dagger-cloud-token" \
  -n argo-workflow
```

### 2. Deploy the WorkflowTemplate

```bash
kubectl apply -f workflow-template.yaml
```

### 3. Deploy the CronWorkflow for Nightly Builds

```bash
kubectl apply -f cron-workflow.yaml
```

## Usage

### Local Development and Testing

The primary way to test and run the build pipeline is using Dagger directly:

```bash
# Set required environment variables
export DOCKER_PASSWORD="your-docker-hub-password-or-token"
export CODER_TOKEN="your-coder-api-token"

# Run the complete build pipeline with Coder template upload
dagger call build-pipeline \
  --cluster-name="developer" \
  --source=./riksarkivet-developer-template \
  --docker-password=env:DOCKER_PASSWORD \
  --docker-username=airiksarkivet \
  --image-repository=riksarkivet/workspace-developer \
  --image-tag=v1.0.0 \
  --preset "Small Development" \
  --coder-url=http://coder.coder.svc.cluster.local \
  --coder-token=env:CODER_TOKEN \
  --template-name="Riksarkivets-Developer-Template" \
  --template-params "dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles" \
  --template-params "AI Prompt=" \
  --env-vars="ENABLE_CUDA=false"
```

This command will:
1. Build the Docker image with the specified parameters
2. Push the image to Docker Hub
3. Upload the template to your Coder instance with the new image reference

### Manual Trigger via Argo Workflows

You can also trigger a build using the WorkflowTemplate:

```bash
argo submit --from workflowtemplate/coder-template-build \
  -p cluster-name=developer \
  -p image-repository=riksarkivet/workspace-developer \
  -p image-tag=v1.0.1 \
  -p docker-username=airiksarkivet \
  -p preset="Small Development" \
  -p git-branch=main \
  -p template-name="Riksarkivets-Developer-Template" \
  -p coder-url="http://coder.coder.svc.cluster.local" \
  -p template-params='["dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles","AI Prompt="]' \
  -p env-vars='["ENABLE_CUDA=false"]' \
  -n argo-workflow
```

### View Cron Schedule

```bash
# List CronWorkflows
argo cron list -n argo-workflow

# Get details of the nightly build cron
argo cron get coder-template-nightly-build -n argo-workflow
```

### Suspend/Resume Nightly Builds

```bash
# Suspend nightly builds
argo cron suspend coder-template-nightly-build -n argo-workflow

# Resume nightly builds
argo cron resume coder-template-nightly-build -n argo-workflow
```

## Parameters

### Core Parameters
- `cluster-name` - Target Kubernetes cluster name (default: "developer")
- `image-repository` - Docker image repository (default: "riksarkivet/workspace-developer")
- `image-tag` - Docker image tag (default: "v1.0.0", nightly builds use date format)
- `docker-username` - Docker Hub username (default: "airiksarkivet")
- `preset` - Coder template preset (default: "Small Development")
- `git-branch` - Git branch to build from (default: "main")

### Dynamic Parameters
- `template-params` - JSON array of template parameters in "key=value" format
- `env-vars` - JSON array of environment variables in "key=value" format

## Customization

### Adding New Template Parameters

Edit the `template-params` JSON array:
```yaml
- name: template-params
  value: |
    [
      "dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles",
      "AI Prompt=Custom AI prompt here",
      "new_param=value"
    ]
```

### Adding New Environment Variables

Edit the `env-vars` JSON array:
```yaml
- name: env-vars
  value: |
    [
      "ENABLE_CUDA=false",
      "NEW_ENV_VAR=value"
    ]
```

### Changing Build Schedule

Edit the `schedule` field in `cron-workflow.yaml`:
```yaml
schedule: "0 2 * * *"  # Current: 2 AM UTC daily
```

Common cron expressions:
- `"0 2 * * *"` - Daily at 2 AM
- `"0 2 * * 1-5"` - Weekdays at 2 AM
- `"0 2 * * 0"` - Weekly on Sunday at 2 AM
- `"0 2 1 * *"` - Monthly on the 1st at 2 AM

## Monitoring

### View Workflow Logs
```bash
# Get workflow status
argo get <workflow-name> -n argo-workflow

# View logs
argo logs <workflow-name> -n argo-workflow

# Follow logs in real-time
argo logs <workflow-name> -n argo-workflow -f
```

### View in Argo UI
Access the Argo Workflows UI to monitor builds visually:
```bash
kubectl port-forward svc/argo-workflows-server 2746:2746 -n argo-workflow
```
Then open http://localhost:2746 in your browser.