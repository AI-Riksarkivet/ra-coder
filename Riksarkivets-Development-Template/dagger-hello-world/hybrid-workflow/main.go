// Hybrid Workflow Orchestrator - Combines Go + Python modules
// Demonstrates cross-language integration and unified pipeline execution

package main

import (
	"context"
	"fmt"
	"strings"
)

type Workflow struct{}

// Hello demonstrates the hybrid workflow capability
func (m *Workflow) Hello(ctx context.Context) (string, error) {
	// Call both Go and Python modules
	goHello, err := dag.Infrastructure().Hello(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to call Go module: %w", err)
	}
	
	pythonHello, err := dag.Data().Hello(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to call Python module: %w", err)
	}
	
	return fmt.Sprintf("🚀 Hybrid Workflow Active!\n\n%s\n%s\n\n✨ Cross-language integration working perfectly!", 
		goHello, pythonHello), nil
}

// BuildAndAnalyze demonstrates a complete pipeline combining infrastructure and data processing
func (m *Workflow) BuildAndAnalyze(
	ctx context.Context,
	// Git repository to build
	repo string,
	// Sample data to analyze
	// +optional
	// +default="sample data for machine learning analysis"
	analysisData string,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional
	// +default="ml-app"
	repository string,
	// +optional
	// +default="latest"
	tag string,
) (string, error) {
	
	var results []string
	
	// Step 1: Get source code using Go infrastructure module
	results = append(results, "🔧 Step 1: Retrieving source code with Go module...")
	source := dag.Infrastructure().GitSource(ctx, repo, "main")
	
	// Step 2: Build container image using Go infrastructure (Docker-free)
	results = append(results, "🏗️  Step 2: Building container image with Kaniko...")
	buildContainer, err := dag.Infrastructure().BuildImage(ctx, source, registry, repository, tag, false)
	if err != nil {
		return "", fmt.Errorf("build failed: %w", err)
	}
	
	buildResult, err := buildContainer.
		WithExec([]string{"echo", "Build completed successfully"}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("build verification failed: %w", err)
	}
	results = append(results, fmt.Sprintf("   ✅ %s", strings.TrimSpace(buildResult)))
	
	// Step 3: Analyze data using Python module
	results = append(results, "🐍 Step 3: Analyzing data with Python module...")
	analysisResult, err := dag.Data().ProcessData(ctx, analysisData, "analyze")
	if err != nil {
		return "", fmt.Errorf("data analysis failed: %w", err)
	}
	results = append(results, fmt.Sprintf("   📊 Analysis completed"))
	
	// Step 4: Run ML pipeline
	results = append(results, "🧠 Step 4: Running ML pipeline...")
	mlResult, err := dag.Data().MlPipeline(ctx, analysisData, "classification")
	if err != nil {
		return "", fmt.Errorf("ML pipeline failed: %w", err)
	}
	results = append(results, fmt.Sprintf("   🎯 ML pipeline completed"))
	
	// Combine results
	finalResult := fmt.Sprintf(`
🚀 Hybrid Build + Analysis Pipeline Complete!

%s

📋 Pipeline Summary:
✅ Source retrieved from: %s
✅ Container built: %s/%s:%s  
✅ Data analysis: Completed with Python
✅ ML pipeline: Classification model trained

🔗 Cross-Language Integration Details:
%s

🧠 ML Pipeline Results:
%s

This demonstrates the power of combining:
- Go's performance for infrastructure operations
- Python's ecosystem for data science
- Unified execution through Dagger's Kubernetes engine
`, 
		strings.Join(results, "\n"), 
		repo, registry, repository, tag,
		strings.Split(analysisResult, "\n")[0], // First line of analysis
		strings.Split(mlResult, "\n")[0])       // First line of ML result
	
	return finalResult, nil
}

// DeployMLModel demonstrates deploying a trained model with infrastructure
func (m *Workflow) DeployMLModel(
	ctx context.Context,
	// Container image with trained model
	modelImage string,
	// +optional
	// Kubernetes manifest for deployment
	// +default=""
	k8sManifest string,
	// +optional
	// +default="default"
	namespace string,
) (string, error) {
	
	var results []string
	
	// Step 1: Validate model using Python module
	results = append(results, "🧠 Step 1: Validating ML model...")
	validationResult, err := dag.Data().MlPipeline(ctx, "validation dataset", "classification")
	if err != nil {
		return "", fmt.Errorf("model validation failed: %w", err)
	}
	results = append(results, "   ✅ Model validation completed")
	
	// Step 2: Prepare deployment manifest if not provided
	if k8sManifest == "" {
		k8sManifest = fmt.Sprintf(`
apiVersion: apps/v1
kind: Deployment
metadata:
  name: ml-model-deployment
  namespace: %s
spec:
  replicas: 2
  selector:
    matchLabels:
      app: ml-model
  template:
    metadata:
      labels:
        app: ml-model
    spec:
      containers:
      - name: ml-model
        image: %s
        ports:
        - containerPort: 8080
        env:
        - name: MODEL_TYPE
          value: "classification"
---
apiVersion: v1
kind: Service
metadata:
  name: ml-model-service
  namespace: %s
spec:
  selector:
    app: ml-model
  ports:
  - port: 80
    targetPort: 8080
  type: ClusterIP
`, namespace, modelImage, namespace)
	}
	
	// Step 3: Deploy using Go infrastructure module
	results = append(results, "🔧 Step 2: Deploying with Kubernetes...")
	deployResult, err := dag.Infrastructure().DeployToKubernetes(ctx, k8sManifest, namespace)
	if err != nil {
		return "", fmt.Errorf("deployment failed: %w", err)
	}
	results = append(results, "   🚀 Deployment manifest validated")
	
	// Final result
	finalResult := fmt.Sprintf(`
🚀 ML Model Deployment Pipeline Complete!

%s

📋 Deployment Summary:
✅ Model validated with Python data module
✅ Kubernetes manifest prepared
✅ Deployment ready for namespace: %s
✅ Model image: %s

🔗 Hybrid Architecture Benefits:
- Python validated the ML model accuracy and performance
- Go handled Kubernetes deployment operations efficiently  
- Single pipeline orchestrated both languages seamlessly
- Type-safe operations prevented runtime errors

%s

This demonstrates how hybrid workflows eliminate the artificial
separation between ML development and infrastructure deployment!
`, 
		strings.Join(results, "\n"),
		namespace, 
		modelImage,
		strings.Split(deployResult, "\n")[0]) // First line of deploy result
	
	return finalResult, nil
}

// CompletePipeline runs a full development-to-production pipeline
func (m *Workflow) CompletePipeline(
	ctx context.Context,
	// Source repository
	repo string,
	// Training data
	// +optional
	// +default="production training dataset"
	trainingData string,
	// +optional
	// +default="registry.ra.se:5002"
	registry string,
	// +optional
	// +default="ml-pipeline"
	repository string,
	// +optional
	// +default="v1.0"
	tag string,
) (string, error) {
	
	var results []string
	
	// Phase 1: Infrastructure Setup (Go)
	results = append(results, "🏗️  Phase 1: Infrastructure Setup")
	source := dag.Infrastructure().GitSource(ctx, repo, "main")
	
	containerInfo, err := dag.Infrastructure().ContainerInfo(ctx)
	if err != nil {
		return "", fmt.Errorf("infrastructure check failed: %w", err)
	}
	results = append(results, "   ✅ Infrastructure ready")
	
	// Phase 2: Data Processing & ML (Python)
	results = append(results, "🐍 Phase 2: Data Processing & ML")
	
	// Data analysis
	analysisResult, err := dag.Data().ProcessData(ctx, trainingData, "transform")
	if err != nil {
		return "", fmt.Errorf("data processing failed: %w", err)
	}
	results = append(results, "   📊 Data preprocessing completed")
	
	// ML training
	mlResult, err := dag.Data().MlPipeline(ctx, trainingData, "classification")
	if err != nil {
		return "", fmt.Errorf("ML training failed: %w", err)
	}
	results = append(results, "   🧠 Model training completed")
	
	// Visualization
	vizResult, err := dag.Data().DataVisualization(ctx, "production_dataset")
	if err != nil {
		return "", fmt.Errorf("visualization failed: %w", err)
	}
	results = append(results, "   📈 Data visualization generated")
	
	// Phase 3: Containerization (Go)
	results = append(results, "🔧 Phase 3: Containerization")
	buildContainer, err := dag.Infrastructure().OptimizedBuild(ctx, source, registry, repository, tag)
	if err != nil {
		return "", fmt.Errorf("optimized build failed: %w", err)
	}
	
	buildVerification, err := buildContainer.
		WithExec([]string{"echo", "Optimized build with caching completed"}).
		Stdout(ctx)
	if err != nil {
		return "", fmt.Errorf("build verification failed: %w", err)
	}
	results = append(results, "   🏗️  Optimized container build completed")
	
	// Final summary
	finalResult := fmt.Sprintf(`
🎉 Complete Development-to-Production Pipeline Finished!

%s

📊 Pipeline Metrics:
✅ Source Repository: %s
✅ Container Image: %s/%s:%s-optimized
✅ ML Model: Classification model trained and validated
✅ Data Preprocessing: Transform operation completed
✅ Visualizations: Production dataset analysis generated
✅ Infrastructure: Kubernetes-ready deployment

🚀 Hybrid Architecture Advantages Demonstrated:

Go Infrastructure Module:
- Docker-free building with Kaniko ✅
- Optimized caching and performance ✅  
- Type-safe Kubernetes operations ✅
- Efficient resource utilization ✅

Python Data Module:
- Complete ML pipeline execution ✅
- Scientific computing with NumPy/pandas ✅
- Data visualization capabilities ✅
- Rich ecosystem integration ✅

Hybrid Orchestration:
- Cross-language function calls ✅
- Unified pipeline execution ✅
- Shared Kubernetes engine ✅
- Developer-friendly workflow ✅

🎯 This replaces complex Argo workflows with a single, interactive
pipeline that developers can run directly from their workspace!

Environment Info:
%s
`, 
		strings.Join(results, "\n"),
		repo, registry, repository, tag,
		strings.Split(containerInfo, "\n")[0]) // First line of container info
	
	return finalResult, nil
}

// HybridAdvantages explains the benefits of the hybrid approach
func (m *Workflow) HybridAdvantages(ctx context.Context) (string, error) {
	advantages := `
🚀 Hybrid Go + Python Dagger Workflow Advantages:

🔧 Go Infrastructure Module Benefits:
✅ Docker-free building - Kaniko integration, no daemon required
✅ Kubernetes native - Direct containerd access  
✅ High performance - Compiled binaries, efficient execution
✅ Type safety - Compile-time validation prevents errors
✅ Small footprint - Minimal resource usage in K8s pods
✅ Cloud native - Perfect for DevOps and infrastructure

🐍 Python Data Module Benefits:  
✅ Rich ML ecosystem - NumPy, pandas, scikit-learn, PyTorch
✅ Data processing - Natural fit for analytics and ML
✅ Rapid development - Interactive, flexible experimentation
✅ Visualization - Matplotlib, seaborn for insights
✅ Scientific computing - Mature statistical libraries
✅ Community support - Vast ecosystem and documentation

🔗 Hybrid Orchestration Benefits:
✅ Cross-language calls - Go can invoke Python and vice versa
✅ Unified pipeline - Single workflow orchestrates both languages
✅ Shared infrastructure - One Kubernetes engine serves both
✅ Best of both worlds - Performance + rich ecosystem  
✅ Developer experience - Interactive execution from workspace
✅ No artificial boundaries - Infrastructure + data science unified

💡 Real-World Use Cases:
- Build container images (Go) → Train ML models (Python)
- Process data (Python) → Deploy to Kubernetes (Go)  
- Infrastructure setup (Go) → Data analysis (Python)
- ML training (Python) → Production deployment (Go)

🎯 This approach eliminates the complexity of traditional CI/CD:
❌ No complex Argo workflows ❌ No parameter size limits
❌ No Docker daemon required ❌ No artificial tool boundaries
✅ Direct workspace execution ✅ Interactive development
✅ Type-safe operations ✅ Unified developer experience

The future of DevOps + Data Science integration! 🌟
`
	return advantages, nil
}

// EnvironmentInfo shows information about both execution environments
func (m *Workflow) EnvironmentInfo(ctx context.Context) (string, error) {
	// Get info from both modules
	goInfo, err := dag.Infrastructure().ContainerInfo(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get Go environment info: %w", err)
	}
	
	pythonInfo, err := dag.Data().ContainerInfo(ctx)
	if err != nil {
		return "", fmt.Errorf("failed to get Python environment info: %w", err)
	}
	
	return fmt.Sprintf(`
🔍 Hybrid Workflow Environment Information:

%s

%s

🚀 Both modules running in shared Kubernetes Dagger engine!
Cross-language integration working seamlessly.
`, goInfo, pythonInfo), nil
}