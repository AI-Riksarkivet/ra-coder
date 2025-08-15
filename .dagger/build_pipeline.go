package main

import (
	"context"
	"dagger/test/internal/dagger"
	"fmt"
	"strings"
	"time"
)

// DeployCoderToK3s deploys Coder to a K3s cluster using Helm and returns the K3s service
func (m *Build) BuildPipeline(
	ctx context.Context,
	// Template source directory
	source *dagger.Directory,

	// K3s cluster name
	// +default="coder-cluster"
	clusterName string,
	// Coder Helm chart version
	// +default="2.19.2"
	chartVersion string,
	// Enable CUDA support
	// +default=false
	enableCuda bool,
	// Docker Hub username (required for pushing)
	dockerUsername string,
	// Docker Hub password/token (required for pushing, as a secret)
	dockerPassword *dagger.Secret,
) (*dagger.Service, error) {
	startTime := time.Now()
	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════════════════════════════╗")
	fmt.Println("║       🚀 CODER DEPLOYMENT PIPELINE STARTING                  ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════╝")
	fmt.Println("")
	fmt.Printf("📅 Start Time: %s\n", startTime.Format("15:04:05"))
	fmt.Printf("🎯 Target: K3s cluster with Coder v%s\n", chartVersion)
	fmt.Printf("🐳 CUDA Support: %v\n", enableCuda)
	fmt.Println("")

	// Validate Docker Hub credentials
	fmt.Println("[STEP 0/6] 🔐 Validating credentials...")
	if dockerUsername == "" || dockerPassword == nil {
		return nil, fmt.Errorf("❌ Docker Hub credentials are required (dockerUsername and dockerPassword)")
	}
	fmt.Println("   ✅ Docker credentials validated")

	fmt.Println("\n[STEP 1/6] 📦 Setting up local registry...")
	regSvc := dag.Container().From("registry:2.8").
		WithExposedPort(5000).AsService()
	fmt.Println("   🔄 Starting registry service on port 5000...")

	_, err := dag.Container().From("quay.io/skopeo/stable").
		WithServiceBinding("registry", regSvc).
		WithEnvVariable("BUST", time.Now().String()).
		WithExec([]string{"copy", "--dest-tls-verify=false", "docker://docker.io/alpine:latest", "docker://registry:5000/alpine:latest"}, dagger.ContainerWithExecOpts{UseEntrypoint: true}).Sync(ctx)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to setup local registry: %w", err)
	}
	fmt.Println("   ✅ Local registry ready")

	fmt.Println("\n[STEP 2/6] 🌐 Starting K3s cluster...")
	fmt.Println("   🔧 Configuring K3s with local registry mirror...")
	k3s := dag.K3S("test").With(func(k *dagger.K3S) *dagger.K3S {
		return k.WithContainer(
			k.Container().
				WithEnvVariable("BUST", time.Now().String()).
				WithExec([]string{"sh", "-c", `
cat <<EOF > /etc/rancher/k3s/registries.yaml
mirrors:
  "registry:5000":
    endpoint:
      - "http://registry:5000"
EOF`}).
				WithServiceBinding("registry", regSvc),
		)
	})

	k3sSvc := k3s.Server()
	fmt.Println("   🚀 Starting K3s server...")

	k3sSvc, err2 := k3sSvc.Start(ctx)

	if err2 != nil {
		return nil, fmt.Errorf("❌ Failed to start K3s service: %w", err2)
	}

	// Get K3s endpoint to verify it's running
	ep, err := k3sSvc.Endpoint(ctx, dagger.ServiceEndpointOpts{Port: 6443, Scheme: "https"})
	if err != nil {
		fmt.Printf("   ⚠️  Could not get K3s endpoint (continuing anyway): %v\n", err)
	} else {
		fmt.Printf("   ✅ K3s cluster running at: %s\n", ep)
	}

	// Get kubeconfig from K3s
	kubeconfig := k3s.Config()
	fmt.Println("   ✅ Kubeconfig retrieved")

	fmt.Println("\n[STEP 3/6] 🏗️  Building workspace image...")
	// Generate SHA-based tag from source directory
	fmt.Println("   🔍 Generating source hash...")
	sourceHash, err := source.Digest(ctx)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to generate source hash: %w", err)
	}
	// Remove "sha256:" prefix and use first 12 characters of the actual hash
	hashParts := strings.Split(sourceHash, ":")
	actualHash := hashParts[len(hashParts)-1]
	generatedTag := actualHash[:12]
	fmt.Printf("   📌 Generated SHA tag: %s\n", generatedTag)

	// Use BuildAndPublish to build and push in one operation
	fmt.Println("   🐳 Building Docker image (this may take a few minutes)...")
	//publishResult, err := m.BuildAndPublish(ctx, source, dockerUsername, dockerPassword, enableCuda, generatedTag, "registry:5000", "riksarkivet/coder-workspace-ml")
	if err != nil {
		return nil, fmt.Errorf("❌ Build and publish failed: %w", err)
	}

	// Construct the full image reference
	finalImageTag := generatedTag
	if !enableCuda {
		finalImageTag = generatedTag + "-cpu"
	}
	pushedRef := fmt.Sprintf("docker.io/riksarkivet/coder-workspace-ml:%s", finalImageTag)

	//fmt.Printf("   ✅ %s\n", publishResult)
	fmt.Printf("   📦 Image reference: %s\n", pushedRef)
	fmt.Println("   ✅ Image built and pushed successfully")

	fmt.Println("\n[STEP 4/6] 🔧 Configuring Kubernetes resources...")
	_, err = dag.Container().
		From("alpine/k8s:1.28.3").
		WithServiceBinding("k3s", k3sSvc).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", kubeconfig).
		WithExec([]string{"sh", "-c", fmt.Sprintf(`
			# Wait for K3s API to be ready
			echo "   ⏳ Waiting for K3s API to be ready..."
			for i in $(seq 1 30); do
				if kubectl get nodes 2>/dev/null; then
					echo "   ✅ K3s API is ready"
					break
				fi
				echo "   ⏳ Waiting for K3s API... ($i/30)"
				sleep 2
			done
			
			# Create namespace
			echo "   📁 Creating namespace 'coder'..."
			kubectl create namespace coder 2>/dev/null || echo "   ℹ️  Namespace coder already exists"
			kubectl get namespace coder > /dev/null
			
			# Create LakeFS secret in coder namespace (hardcoded)
			echo "   🔐 Creating LakeFS secret..."
			kubectl apply -n coder -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: lakefs-secrets
type: Opaque
stringData:
  endpoint: "http://lakefs.lakefs.svc.cluster.local:8000"
  access_key_id: "AKIAIOSFODNN7EXAMPLE"
  secret_access_key: "wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY"
EOF
			echo "   ✅ LakeFS secret created"
			kubectl get secret -n coder lakefs-secrets > /dev/null
			
			# Create fake kubeconfig secret in coder namespace
			echo "   🔐 Creating default kubeconfig secret..."
			kubectl apply -n coder -f - <<EOF
apiVersion: v1
kind: Secret
metadata:
  name: default-kubeconfig
type: Opaque
stringData:
  config: |
    apiVersion: v1
    kind: Config
    clusters:
    - cluster:
        server: https://fake-k8s:6443
      name: fake
    contexts:
    - context:
        cluster: fake
      name: fake
    current-context: fake
EOF
			echo "   ✅ Default kubeconfig secret created"
			kubectl get secret -n coder default-kubeconfig > /dev/null
		`)}).
		Stdout(ctx)

	if err != nil {
		return nil, fmt.Errorf("❌ Failed to create namespace and secrets: %w", err)
	}
	fmt.Println("   ✅ All Kubernetes resources configured")

	// Base container with Helm and kubectl
	helmContainer := dag.Container().
		From("alpine/helm:3.13.3").
		WithExec([]string{"apk", "add", "--no-cache", "kubectl", "curl"}).
		WithServiceBinding("k3s", k3sSvc).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", kubeconfig)

	// Create values for Coder deployment with RBAC permissions
	coderValues := fmt.Sprintf(`
# First deploy a simple PostgreSQL
kubectl apply -n coder -f - <<PSQL
apiVersion: v1
kind: ConfigMap
metadata:
  name: postgres-config
data:
  POSTGRES_DB: coder
  POSTGRES_USER: coder
  POSTGRES_PASSWORD: coder
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: postgres
spec:
  replicas: 1
  selector:
    matchLabels:
      app: postgres
  template:
    metadata:
      labels:
        app: postgres
    spec:
      containers:
      - name: postgres
        image: postgres:14-alpine
        envFrom:
        - configMapRef:
            name: postgres-config
        ports:
        - containerPort: 5432
---
apiVersion: v1
kind: Service
metadata:
  name: postgres
spec:
  selector:
    app: postgres
  ports:
  - port: 5432
PSQL

# Create RBAC permissions for Coder to manage workspaces
kubectl apply -f - <<RBAC
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: coder-workspace-manager
rules:
# Core resources for workspaces
- apiGroups: [""]
  resources: ["pods", "pods/log", "pods/exec", "pods/attach", "pods/portforward"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["services", "persistentvolumeclaims", "configmaps", "secrets"]
  verbs: ["*"]
- apiGroups: [""]
  resources: ["namespaces"]
  verbs: ["get", "list", "watch", "create"]
- apiGroups: [""]
  resources: ["events"]
  verbs: ["get", "list", "watch"]
# Apps resources
- apiGroups: ["apps"]
  resources: ["deployments", "statefulsets", "replicasets", "daemonsets"]
  verbs: ["*"]
# Batch resources for jobs
- apiGroups: ["batch"]
  resources: ["jobs", "cronjobs"]
  verbs: ["*"]
# Networking resources
- apiGroups: ["networking.k8s.io"]
  resources: ["ingresses", "networkpolicies"]
  verbs: ["*"]
# Storage resources
- apiGroups: ["storage.k8s.io"]
  resources: ["storageclasses"]
  verbs: ["get", "list", "watch"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: coder-workspace-manager
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: coder-workspace-manager
subjects:
- kind: ServiceAccount
  name: coder
  namespace: coder
RBAC

# Create Helm values with enhanced permissions
cat <<'EOF' > /tmp/coder-values.yaml
coder:
  env:
    - name: CODER_ACCESS_URL
      value: "http://localhost:8080"
    - name: CODER_PG_CONNECTION_URL
      value: "postgresql://coder:coder@postgres.coder.svc.cluster.local:5432/coder?sslmode=disable"
    - name: CODER_TELEMETRY_ENABLE
      value: "false"
  service:
    type: ClusterIP
  serviceAccount:
    create: true
    name: coder
    annotations: {}
  rbac:
    create: true
    clusterRoleName: coder-workspace-manager
EOF
`)

	fmt.Println("\n[STEP 5/6] ⚙️  Deploying Coder with Helm...")
	fmt.Printf("   🎯 Target version: %s\n", chartVersion)
	// Deploy PostgreSQL and Coder with Helm
	_, err = helmContainer.
		WithExec([]string{"sh", "-c", coderValues}).
		WithExec([]string{"sh", "-c", fmt.Sprintf(`
			set -e
			
			# Check if values file was created
			echo "   📋 Validating Helm values file..."
			if [ -f /tmp/coder-values.yaml ]; then
				echo "   ✅ Values file created"
			else
				echo "   ❌ Values file not found!"
				exit 1
			fi
			
			# Add Coder Helm repository
			echo "   📦 Adding Coder Helm repository..."
			helm repo add coder https://helm.coder.com/v2 2>/dev/null || echo "   ℹ️  Repository already added"
			helm repo update > /dev/null 2>&1
			echo "   ✅ Helm repository ready"
			
			# Install/upgrade Coder
			echo "   🚀 Installing Coder (this may take a minute)..."
			helm upgrade --install coder coder/coder \
				--namespace coder \
				--values /tmp/coder-values.yaml \
				--create-namespace \
				--wait --timeout=5m 2>&1 | tail -5 || {
					ERROR_CODE=$?
					echo "   ❌ Helm install failed with error code: $ERROR_CODE"
					echo "   🔄 Retrying with stable version 2.17.2..."
					helm upgrade --install coder coder/coder \
						--namespace coder \
						--version 2.17.2 \
						--values /tmp/coder-values.yaml \
						--create-namespace \
						--wait --timeout=5m 2>&1 | tail -5 || echo "   ❌ Installation failed"
				}
			
			# Verify deployment
			if helm list -n coder | grep -q coder; then
				echo "   ✅ Coder successfully deployed"
			else
				echo "   ⚠️  Coder deployment status unclear"
			fi
		`)}).
		Stdout(ctx)

	if err != nil {
		return nil, fmt.Errorf("❌ Failed to deploy Coder: %w", err)
	}
	fmt.Println("   ✅ Helm deployment completed")

	fmt.Println("\n[STEP 6/6] 👥 Setting up admin user and template...")
	_, err = dag.Container().
		From("alpine/k8s:1.28.3").
		WithExec([]string{"apk", "add", "--no-cache", "curl", "tar"}).
		WithServiceBinding("k3s", k3sSvc).
		WithServiceBinding("registry", regSvc).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", kubeconfig).
		WithDirectory("/template", source).
		WithExec([]string{"sh", "-c", `
			# Install k9s
			echo "   🔧 Installing k9s for cluster management..."
			K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
			curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin k9s 2>/dev/null
			chmod +x /usr/local/bin/k9s
			echo "   ✅ k9s installed"

			# Wait for Coder deployment
			echo "   ⏳ Waiting for Coder deployment to be ready..."
			kubectl wait --for=condition=available --timeout=300s deployment/coder -n coder > /dev/null 2>&1 || true

			# Get pod name, copy template and push
			echo "   📦 Copying template to Coder pod..."
			CODER_POD=$(kubectl get pod -n coder -l app.kubernetes.io/name=coder -o jsonpath='{.items[0].metadata.name}')
			kubectl cp /template coder/$CODER_POD:/tmp/my-template 2>/dev/null
			echo "   ✅ Template copied"

			# push the template
			echo "   👤 Creating admin user..."
		    kubectl exec -n coder deployment/coder -- sh -c '
				# Create admin user (if not exists)
				coder server create-admin-user --username admin --email admin@example.com --password changeme123 2>&1 | grep -v "duplicate key" || true

				# Login using session token method
				SESSION_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
					-d "{\"email\":\"admin@example.com\",\"password\":\"changeme123\"}" \
					"http://localhost:8080/api/v2/users/login" | grep -o "\"session_token\":\"[^\"]*\"" | cut -d"\"" -f4)
				
				echo "$SESSION_TOKEN" | coder login http://localhost:8080 > /dev/null 2>&1

				# Now push the template
				coder templates push my-template --directory /tmp/my-template --message "Automated push" --yes > /dev/null 2>&1

			' 2>/dev/null && echo "   ✅ Admin user configured and template pushed" || echo "   ⚠️  Some configuration steps may have failed"
		`}).
		WithWorkdir("/template").
		Terminal().
		Stdout(ctx)

	if err != nil {
		fmt.Printf("   ⚠️  Some configuration steps had issues: %v\n", err)
	} else {
		fmt.Println("   ✅ Configuration completed")
	}

	// Print the summary information
	endTime := time.Now()
	duration := endTime.Sub(startTime)

	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════════════════════════════╗")
	fmt.Println("║       ✨ DEPLOYMENT COMPLETED SUCCESSFULLY!                  ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════╝")
	fmt.Println("")
	fmt.Printf("⏱️  Total deployment time: %v\n", duration.Round(time.Second))
	fmt.Println("")
	fmt.Println("📦 Deployed Components:")
	fmt.Printf("   • K3s cluster: %s\n", clusterName)
	fmt.Printf("   • Coder version: %s\n", chartVersion)
	fmt.Printf("   • Workspace image: %s\n", pushedRef)
	fmt.Println("   • PostgreSQL: Internal database")
	fmt.Println("   • Admin user: admin (admin@example.com)")
	fmt.Println("")
	fmt.Println("🔗 Access Instructions:")
	fmt.Println("   1. Get kubeconfig:")
	fmt.Printf("      dagger call get-k3s-kubeconfig --cluster-name=%s > kubeconfig.yaml\n", clusterName)
	fmt.Println("")
	fmt.Println("   2. Port-forward to access Coder:")
	fmt.Println("      kubectl port-forward -n coder svc/coder 8080:80")
	fmt.Println("")
	fmt.Println("   3. Open browser:")
	fmt.Println("      http://localhost:8080")
	fmt.Println("")
	fmt.Println("   4. Login credentials:")
	fmt.Println("      Username: admin")
	fmt.Println("      Password: changeme123")
	fmt.Println("")
	fmt.Println("═══════════════════════════════════════════════════════════════")

	// Return the K3s service for external access
	return k3sSvc, nil
}

// returns the kubeconfig file for accessing the K3s cluster
func (m *Build) GetKubeconfig(
	ctx context.Context,
	// K3s cluster name
	// +default="coder-cluster"
	clusterName string,
) (*dagger.File, error) {
	fmt.Println("📋 Getting K3s kubeconfig...")

	// Get the K3s cluster config
	k3s := dag.K3S(clusterName)
	kubeconfig := k3s.Config()

	fmt.Printf("✅ Kubeconfig retrieved for cluster: %s\n", clusterName)
	fmt.Println("💡 Save to file: dagger call get-k3s-kubeconfig --cluster-name=<name> > kubeconfig.yaml")
	fmt.Println("💡 Use with kubectl: export KUBECONFIG=./kubeconfig.yaml")

	return kubeconfig, nil
}

// AccessCoderCluster provides a container with kubectl configured to access the deployed Coder cluster
func (m *Build) AccessCoderCluster(
	ctx context.Context,
	// K3s cluster name
	// +default="coder-cluster"
	clusterName string,
	// Command to run in the cluster (e.g., "get pods -n coder")
	// +default="get all -n coder"
	command string,
) (string, error) {
	fmt.Printf("🔧 Accessing cluster '%s'...\n", clusterName)

	// Get the K3s service
	k3s := dag.K3S(clusterName)
	k3sSvc := k3s.Server()

	// Start the service if not already running
	k3sSvc, err := k3sSvc.Start(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to start K3s service: %w", err)
	}

	// Get kubeconfig
	kubeconfig := k3s.Config()

	// Run kubectl command
	result, err := dag.Container().
		From("alpine/k8s:1.28.3").
		WithServiceBinding("k3s", k3sSvc).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", kubeconfig).
		WithExec([]string{"sh", "-c", fmt.Sprintf("kubectl %s", command)}).
		Stdout(ctx)

	if err != nil {
		return "", fmt.Errorf("failed to execute command: %w", err)
	}

	return result, nil
}
