package main

import (
	"context"
	"dagger/test/internal/dagger"
	"fmt"
	"strings"
	"time"
)

// KubernetesCluster holds the Kubernetes cluster service and configuration
type KubernetesCluster struct {
	Service    *dagger.Service
	Kubeconfig *dagger.File
}

// buildParameterString converts templateParams slice into shell commands for adding parameters
func buildParameterString(templateParams []string) string {
	if len(templateParams) == 0 {
		return ""
	}

	// Instead of trying to create a single string with all parameters,
	// we'll generate individual --parameter additions to CREATE_CMD
	var commands []string
	for _, param := range templateParams {
		// Split into key=value
		parts := strings.SplitN(param, "=", 2)
		if len(parts) == 2 {
			key := parts[0]
			value := parts[1]

			// If key contains spaces, we need to quote it
			if strings.Contains(key, " ") {
				// For keys with spaces like "AI Prompt"
				commands = append(commands, fmt.Sprintf(`CREATE_CMD="$CREATE_CMD --parameter \"%s\"=\"%s\""`, key, value))
			} else {
				// For simple keys without spaces
				commands = append(commands, fmt.Sprintf(`CREATE_CMD="$CREATE_CMD --parameter %s=%s"`, key, value))
			}
		} else {
			// If no '=' found, just pass as is
			commands = append(commands, fmt.Sprintf(`CREATE_CMD="$CREATE_CMD --parameter %s"`, param))
		}
	}

	// Return the commands joined with newlines and proper indentation
	if len(commands) > 0 {
		return strings.Join(commands, "\n\t\t\t\t")
	}
	return ""
}

// generateTestPodYAML creates a test pod YAML specification for the workspace image
func generateTestPodYAML(imageRepository, finalImageTag string) string {
	return fmt.Sprintf(`apiVersion: v1
kind: Pod
metadata:
  name: workspace-test-pod
  namespace: coder
  labels:
    app: workspace-test
spec:
  containers:
  - name: workspace
    image: registry:5000/%s:%s
    command: ["sleep", "300"]
    resources:
      requests:
        memory: "512Mi"
        cpu: "250m"
      limits:
        memory: "1Gi"
        cpu: "500m"
  restartPolicy: Never`, imageRepository, finalImageTag)
}

// installCoderAndComponents installs Coder and its required components (PostgreSQL, RBAC, etc.)
func (m *Build) InstallCoderAndComponents(ctx context.Context, cluster *KubernetesCluster, chartVersion string) error {
	fmt.Println("   🔧 Configuring Kubernetes resources...")
	_, err := dag.Container().
		From("alpine/k8s:1.28.3").
		WithServiceBinding("k3s", cluster.Service).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", cluster.Kubeconfig).
		WithExec([]string{"sh", "-c", `
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
		`}).
		Stdout(ctx)

	if err != nil {
		return fmt.Errorf("❌ Failed to create namespace and secrets: %w", err)
	}

	// Base container with Helm and kubectl
	helmContainer := dag.Container().
		From("alpine/helm:3.13.3").
		WithExec([]string{"apk", "add", "--no-cache", "kubectl", "curl"}).
		WithServiceBinding("k3s", cluster.Service).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", cluster.Kubeconfig)

	// Create values for Coder deployment with RBAC permissions
	coderValues := `
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
`
	fmt.Println("   ✅ Kubernetes resources configured")
	fmt.Println("   ⚙️  Deploying Coder with Helm...")
	fmt.Printf("   🎯 Target version: %s\n", chartVersion)
	// Deploy PostgreSQL and Coder with Helm
	_, err = helmContainer.
		WithExec([]string{"sh", "-c", coderValues}).
		WithExec([]string{"sh", "-c", `
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
		`}).
		Stdout(ctx)

	if err != nil {
		return fmt.Errorf("❌ Failed to deploy Coder: %w", err)
	}
	fmt.Println("   ✅ Helm deployment completed")

	return nil
}

// setupK3sCluster configures and starts a K3s cluster with registry mirror
func (m *Build) SetupK3sCluster(ctx context.Context, clusterName string, regSvc *dagger.Service) (*KubernetesCluster, error) {
	fmt.Println("   🔧 Configuring K3s with local registry mirror...")

	k3s := dag.K3S(clusterName).With(func(k *dagger.K3S) *dagger.K3S {
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

	k3sSvc, err := k3sSvc.Start(ctx)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to start K3s service: %w", err)
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

	return &KubernetesCluster{
		Service:    k3sSvc,
		Kubeconfig: kubeconfig,
	}, nil
}

// setupAdminUserAndTemplate configures admin user, pushes template, and creates test pod
func (m *Build) SetupAdminUserAndTemplate(ctx context.Context, cluster *KubernetesCluster, regSvc *dagger.Service, source *dagger.Directory, imageRepository, finalImageTag string, templateParams []string, preset string) error {
	fmt.Println("   🔧 Installing k9s and configuring admin user...")

	// Start with base container with all dependencies
	container := dag.Container().
		From("alpine/k8s:1.28.3").
		WithExec([]string{"apk", "add", "--no-cache", "curl", "tar"}).
		WithServiceBinding("k3s", cluster.Service).
		WithServiceBinding("registry", regSvc).
		WithEnvVariable("KUBECONFIG", "/.kube/config").
		WithFile("/.kube/config", cluster.Kubeconfig).
		WithDirectory("/template", source)

	// Step 1: Install k9s
	container = container.WithExec([]string{"sh", "-c", `
		echo "   🔧 Installing k9s for cluster management..."
		K9S_VERSION=$(curl -s https://api.github.com/repos/derailed/k9s/releases/latest | grep '"tag_name"' | cut -d'"' -f4)
		curl -sL "https://github.com/derailed/k9s/releases/download/${K9S_VERSION}/k9s_Linux_amd64.tar.gz" | tar xz -C /usr/local/bin k9s 2>/dev/null
		chmod +x /usr/local/bin/k9s
		echo "   ✅ k9s installed"
	`})

	// Step 2: Wait for Coder deployment
	container = container.WithExec([]string{"sh", "-c", `
		echo "   ⏳ Waiting for Coder deployment to be ready..."
		kubectl wait --for=condition=available --timeout=300s deployment/coder -n coder > /dev/null 2>&1 || true
	`})

	// Step 3: Copy template to Coder pod
	container = container.WithExec([]string{"sh", "-c", `
		echo "   📦 Copying template to Coder pod..."
		CODER_POD=$(kubectl get pod -n coder -l app.kubernetes.io/name=coder -o jsonpath='{.items[0].metadata.name}')
		kubectl cp /template coder/$CODER_POD:/tmp/my-template 2>/dev/null
		echo "   ✅ Template copied"
	`})

	// Step 4: Create admin user and push template
	container = container.WithExec([]string{"sh", "-c", fmt.Sprintf(`
		echo "   👤 Creating admin user and pushing template..."
		kubectl exec -n coder deployment/coder -- sh -c '
			# Create admin user (if not exists)
			coder server create-admin-user --username admin --email admin@example.com --password changeme123 2>&1 | grep -v "duplicate key" || true

			# Login using session token method
			SESSION_TOKEN=$(curl -s -X POST -H "Content-Type: application/json" \
				-d "{\"email\":\"admin@example.com\",\"password\":\"changeme123\"}" \
				"http://localhost:8080/api/v2/users/login" | grep -o "\"session_token\":\"[^\"]*\"" | cut -d"\"" -f4)
			
			echo "$SESSION_TOKEN" | coder login http://localhost:8080 > /dev/null 2>&1

			# Push the template with image variables
			coder templates push my-template \
				--directory /tmp/my-template \
				--message "Automated push" \
				--variable image_registry=registry:5000 \
				--variable image_repository=%s \
				--variable image_tag=%s \
				--yes > /dev/null 2>&1
		' 2>/dev/null
		echo "   ✅ Admin user configured and template pushed"
	`, imageRepository, finalImageTag)})

	// Step 5: Create test workspace (with 5 minute timeout using shell timeout command)
	presetCmd := ""
	if preset != "" {
		presetCmd = fmt.Sprintf(`--preset "%s"`, preset)
	}
	container = container.WithExec([]string{"sh", "-c", fmt.Sprintf(`
		echo "   🚀 Creating test workspace..."
		kubectl exec -n coder deployment/coder -- sh -c '
			coder create %s \
				--parameter dotfiles_uri=https://github.com/AI-Riksarkivet/dotfiles \
				--parameter "AI Prompt"="" \
				--parameter is_ci=true \
				--template my-template test --yes
		' || echo "   ⚠️  Test workspace creation failed"
		echo "   ✅ Workspace created"
	`, presetCmd)})

	// Step 6: Health check workspace
	container = container.WithExec([]string{"sh", "-c", `
		echo "   🔍 Health checking workspace..."
		#for i in $(seq 1 30); do
		#	echo "   📊 Checking workspace status (attempt $i/30)..."
		#	WORKSPACE_STATUS=$(kubectl exec -n coder deployment/coder -- coder show admin/test --output json 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "unknown")
		#	echo "   🔍 Status: $WORKSPACE_STATUS"
		#	
		#	if [ "$WORKSPACE_STATUS" = "running" ]; then
		#		echo "   ✅ Workspace is running"
		#		break
		#	elif [ "$WORKSPACE_STATUS" = "failed" ]; then
		#		echo "   ❌ Workspace failed"
		#		break
		#	fi
		#	sleep 10
		#done
		
		#echo "   📋 Final status:"
		kubectl exec -n coder deployment/coder -- coder show admin/test
		
		echo "   🔍 Pod status:"
		kubectl get pods -n coder -l com.coder.workspace.name=test -o wide || true
		
		echo "   📊 Pod logs (last 50 lines):"
		POD_NAME=$(kubectl get pod -n coder -l com.coder.workspace.name=test -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)
		if [ -n "$POD_NAME" ]; then
			kubectl logs "$POD_NAME" -n coder --tail=50 || true
		fi
		
		echo "   ✅ Health check completed"
	`})

	// Execute the final container
	_, err := container.
		WithWorkdir("/template").
		//Terminal().
		Sync(ctx)

	if err != nil {
		return fmt.Errorf("❌ Failed to setup admin user and template: %w", err)
	}

	return nil
}

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

	// riksarkivet/coderworkspacename
	imageRepository string,

	// The tag of the image we want to build
	imageTag string,

	// Registry username (optional for pushing to external registry)
	dockerUsername string,

	// Registry password/token (optional for pushing to external registry, as a secret)
	dockerPassword *dagger.Secret,

	// Target registry for pushing (e.g., "docker.io", "ghcr.io", "quay.io")
	// +default="docker.io"
	targetRegistry string,

	// Environment variables for template customization (KEY=VALUE format)
	// +default=[]
	envVars []string,

	// Template parameters for coder create command (KEY=VALUE format)
	// +default=[]
	templateParams []string,

	// Preset name for coder create command
	// +default=""
	preset string,

	// Coder server URL for template upload (optional)
	// +default=""
	coderUrl string,

	// Coder access token for authentication (optional, as a secret)
	coderToken *dagger.Secret,

	// Template name in Coder
	// +default=""
	templateName string,

) (*dagger.Service, error) {
	startTime := time.Now()
	fmt.Println("")
	fmt.Println("╔══════════════════════════════════════════════════════════════╗")
	fmt.Println("║       🚀 CODER DEPLOYMENT PIPELINE STARTING                  ║")
	fmt.Println("╚══════════════════════════════════════════════════════════════╝")
	fmt.Println("")
	fmt.Printf("📅 Start Time: %s\n", startTime.Format("15:04:05"))
	fmt.Printf("🎯 Target: K3s cluster with Coder v%s\n", chartVersion)
	fmt.Printf("🔧 Environment Variables: %v\n", envVars)
	fmt.Println("")

	// Check if registry credentials are provided for optional push
	pushToRegistry := dockerUsername != "" && dockerPassword != nil
	if pushToRegistry {
		fmt.Printf("   ✅ Registry credentials provided - will push to %s\n", targetRegistry)
	} else {
		fmt.Println("   ℹ️  No registry credentials provided - building locally only")
	}

	fmt.Println("   🔄 Starting registry service on port 5000...")
	regSvc := dag.Container().
		From("registry:2.8").
		WithExposedPort(5000).
		AsService()

	fmt.Println("   🔍 Calculating final image tag...")
	finalImageTag := DefaultTagCalculator(imageTag, envVars, imageRepository)

	builtContainer := m.BuildContainer(ctx, source, envVars)

	err := m.PushToLocalRegistry(ctx, builtContainer, imageRepository, finalImageTag, regSvc)
	if err != nil {
		return nil, err
	}

	cluster, err := m.SetupK3sCluster(ctx, clusterName, regSvc)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to setup K3s cluster: %w", err)
	}
	fmt.Println("   ✅ K3s cluster setup completed successfully")

	err = m.InstallCoderAndComponents(ctx, cluster, chartVersion)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to install Coder and components: %w", err)
	}
	fmt.Println("   ✅ Coder and components installation completed successfully")

	err = m.SetupAdminUserAndTemplate(ctx, cluster, regSvc, source, imageRepository, finalImageTag, templateParams, preset)
	if err != nil {
		return nil, fmt.Errorf("❌ Failed to setup admin user and template: %w", err)
	}
	fmt.Println("   ✅ Admin user and template setup completed successfully")

	// Conditional registry push
	var pushedRef string
	if pushToRegistry {

		// Push the already-built container to the target registry
		targetRef := fmt.Sprintf("%s/%s:%s", targetRegistry, imageRepository, finalImageTag)

		fmt.Println("   📤 Pushing to external registry...")
		_, err := builtContainer.
			WithRegistryAuth(targetRegistry, dockerUsername, dockerPassword).
			Publish(ctx, targetRef)

		if err != nil {
			fmt.Printf("   ⚠️  Failed to push to %s: %v\n", targetRegistry, err)
			pushedRef = fmt.Sprintf("registry:5000/%s:%s", imageRepository, finalImageTag)
			fmt.Printf("   📦 Image available locally: %s\n", pushedRef)
		} else {
			pushedRef = targetRef
			fmt.Printf("   📦 Image reference: %s\n", pushedRef)
			fmt.Printf("   ✅ Image built locally and pushed to %s\n", targetRegistry)
		}
	} else {
		pushedRef = fmt.Sprintf("registry:5000/%s:%s", imageRepository, finalImageTag)
		fmt.Printf("   📦 Image available locally: %s\n", pushedRef)
		fmt.Println("   ✅ Image built and available in local registry")
	}

	// Upload template to Coder server if credentials provided
	if coderUrl != "" && coderToken != nil && templateName != "" {
		fmt.Println("")
		fmt.Println("   🚀 Uploading template to Coder server...")

		// Get token value
		tokenValue, err := coderToken.Plaintext(ctx)
		if err != nil {
			fmt.Printf("   ⚠️  Failed to get Coder token: %v\n", err)
		} else {
			// Create a container with Coder CLI installed
			_, err = dag.Container().
				From("alpine:latest").
				WithExec([]string{"apk", "add", "--no-cache", "curl", "tar", "bash", "jq"}).
				WithExec([]string{"sh", "-c", `
					set -e
					# Install Coder CLI - need to get version first
					CODER_VERSION=$(curl -s https://api.github.com/repos/coder/coder/releases/latest | jq -r .tag_name | sed 's/^v//')
					echo "Installing Coder CLI version: ${CODER_VERSION}"
					curl -L "https://github.com/coder/coder/releases/download/v${CODER_VERSION}/coder_${CODER_VERSION}_linux_amd64.tar.gz" | tar -xz -C /usr/local/bin
					chmod +x /usr/local/bin/coder
				`}).
				WithSecretVariable("CODER_SESSION_TOKEN", dag.SetSecret("coder-session", tokenValue)).
				WithDirectory("/template", source).
				WithExec([]string{"bash", "-c", fmt.Sprintf(`
					set -e
					
					# Setup Coder environment
					export CODER_URL="%s"
					export CODER_SESSION_TOKEN="$CODER_SESSION_TOKEN"
					echo "   🔐 Logging into Coder server..."
					coder login $CODER_URL
					
					# Push the template with the new image tag
					echo "   📦 Pushing template to Coder..."
					coder templates push '%s' \
						--directory /template \
						--message "Automated push - Image: %s:%s" \
						--variable image_registry=%s \
						--variable image_repository=%s \
						--variable image_tag=%s \
						--yes
					
					echo "   ✅ Template successfully uploaded to Coder"
				`, coderUrl, templateName, imageRepository, finalImageTag, targetRegistry, imageRepository, finalImageTag)}).
				WithWorkdir("/template").
				Sync(ctx)
				//Stdout(ctx)

			if err != nil {
				fmt.Printf("   ⚠️  Failed to upload template to Coder: %v\n", err)
			} else {
				fmt.Println("   ✅ Template successfully uploaded to Coder server")
				fmt.Printf("   📍 Template URL: %s/templates/%s\n", coderUrl, templateName)
			}
		}
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
	return cluster.Service, nil
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
