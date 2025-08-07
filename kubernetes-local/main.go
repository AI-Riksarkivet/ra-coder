package main

import (
	"context"
	"kubernetes-local/internal/dagger"

	"time"
)

type KubernetesLocal struct{}


// starts a k3s server with a local registry and a pre-loaded alpine image
func (m *KubernetesLocal) KubeServer(ctx context.Context,
	// +optional
	// +default="test"
	name string) (*dagger.Service, error) {
	if name == "" {
		name = "test"
	}
	
	// Create a local container registry service on port 5000
	regSvc := dag.Container().From("registry:2.8").
		WithExposedPort(5000).AsService()

	// Pre-load the registry with Alpine image using Skopeo
	// This copies alpine:latest from Docker Hub to our local registry
	// so k3s can pull it locally for faster, offline-capable deployments
	_, err := dag.Container().From("quay.io/skopeo/stable").
		WithServiceBinding("registry", regSvc).                          // Connect to local registry
		WithEnvVariable("BUST", time.Now().String()).                    // Cache-bust to ensure fresh execution
		WithExec([]string{"copy", "--dest-tls-verify=false",            // Copy image without TLS verification
			"docker://docker.io/alpine:latest",                         // Source: Docker Hub
			"docker://registry:5000/alpine:latest"},                    // Destination: Local registry
			dagger.ContainerWithExecOpts{UseEntrypoint: true}).Sync(ctx)
	if err != nil {
		return nil, err
	}

	return dag.K3S(name).With(func(k *dagger.K3S) *dagger.K3S {
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
	}).Server(), nil
}


// exports the kubeconfig for a cluster to use with host kubectl
func (m *KubernetesLocal) ExportKubeconfig(ctx context.Context,
	// +optional
	// +default="test"
	name string) *dagger.File {
	if name == "" {
		name = "test"
	}
	return dag.K3S(name).Config()
}
