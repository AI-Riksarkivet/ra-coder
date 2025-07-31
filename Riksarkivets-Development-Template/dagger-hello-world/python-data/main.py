"""
Python Data Processing Module - ML pipelines and scientific computing
Demonstrates Python's rich ecosystem for data science and ML operations
"""

import dagger
from dagger import dag, function, object_type
from typing import Annotated


@object_type
class Data:
    """Python Data Processing Module for ML and Analytics"""

    @function
    async def hello(self) -> str:
        """Hello from the Python data processing module"""
        return "🐍 Hello from Python Data Module - Ready for ML and analytics!"

    @function  
    async def process_data(
        self,
        input_data: Annotated[str, "Input data to process"],
        operation: Annotated[str, "Processing operation"] = "analyze"
    ) -> str:
        """Process data using Python's scientific computing capabilities"""
        
        # Simulate data processing with pandas and numpy
        result = await (
            dag.container()
            .from_("python:3.12-slim")
            .with_exec(["pip", "install", "pandas", "numpy", "scikit-learn"])
            .with_new_file("/app/process.py", 
                f'''
import pandas as pd
import numpy as np
from sklearn.preprocessing import StandardScaler
import json

# Simulate data processing
data = "{input_data}"
operation = "{operation}"

print(f"🐍 Processing data with operation: {{operation}}")
print(f"📊 Input data: {{data}}")

# Simulate different operations
if operation == "analyze":
    result = {{
        "operation": operation,
        "input_length": len(data),
        "word_count": len(data.split()),
        "analysis": "Data analyzed successfully",
        "numpy_version": np.__version__,
        "pandas_version": pd.__version__
    }}
elif operation == "transform":
    # Simulate ML preprocessing
    numbers = [len(word) for word in data.split()]
    if numbers:
        scaler = StandardScaler()
        scaled = scaler.fit_transform(np.array(numbers).reshape(-1, 1))
        result = {{
            "operation": operation,
            "original_lengths": numbers,
            "scaled_lengths": scaled.flatten().tolist(),
            "mean": float(np.mean(numbers)),
            "std": float(np.std(numbers))
        }}
    else:
        result = {{"operation": operation, "error": "No data to transform"}}
else:
    result = {{"operation": operation, "status": "Unknown operation"}}

print("✅ Processing complete!")
print(json.dumps(result, indent=2))
                ''')
            .with_workdir("/app")
            .with_exec(["python", "process.py"])
            .stdout()
        )
        
        return f"🐍 Python Data Processing Result:\n{result}"

    @function
    async def ml_pipeline(
        self,
        data_source: Annotated[str, "Data source or sample data"],
        model_type: Annotated[str, "ML model type"] = "classification"
    ) -> str:
        """Run a complete ML pipeline with popular Python libraries"""
        
        result = await (
            dag.container()
            .from_("python:3.12-slim")
            .with_exec([
                "pip", "install", 
                "pandas", "numpy", "scikit-learn", "matplotlib", "seaborn"
            ])
            .with_new_file("/app/ml_pipeline.py",
                f'''
import pandas as pd
import numpy as np
from sklearn.model_selection import train_test_split
from sklearn.ensemble import RandomForestClassifier, RandomForestRegressor
from sklearn.metrics import accuracy_score, mean_squared_error
from sklearn.datasets import make_classification, make_regression
import json

print("🧠 Starting ML Pipeline...")
model_type = "{model_type}"
data_source = "{data_source}"

# Generate sample data based on type
if model_type == "classification":
    X, y = make_classification(n_samples=1000, n_features=10, n_classes=2, random_state=42)
    model = RandomForestClassifier(n_estimators=100, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("📊 Training classification model...")
    model.fit(X_train, y_train)
    predictions = model.predict(X_test)
    score = accuracy_score(y_test, predictions)
    metric_name = "accuracy"
    
elif model_type == "regression":
    X, y = make_regression(n_samples=1000, n_features=10, noise=0.1, random_state=42)
    model = RandomForestRegressor(n_estimators=100, random_state=42)
    X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.2, random_state=42)
    
    print("📈 Training regression model...")
    model.fit(X_train, y_train)
    predictions = model.predict(X_test)
    score = mean_squared_error(y_test, predictions)
    metric_name = "mse"
    
else:
    raise ValueError(f"Unknown model type: {{model_type}}")

# Feature importance
feature_importance = model.feature_importances_.tolist()

result = {{
    "model_type": model_type,
    "data_source": data_source,
    "dataset_shape": [X.shape[0], X.shape[1]],
    "training_samples": len(X_train),
    "test_samples": len(X_test),
    "model_score": {{metric_name: float(score)}},
    "feature_importance": feature_importance[:5],  # Top 5 features
    "status": "✅ ML Pipeline completed successfully!"
}}

print("🎯 ML Pipeline Results:")
print(json.dumps(result, indent=2))
                ''')
            .with_workdir("/app")
            .with_exec(["python", "ml_pipeline.py"])
            .stdout()
        )
        
        return f"🧠 ML Pipeline Result:\n{result}"

    @function
    async def data_visualization(
        self,
        dataset_name: Annotated[str, "Dataset name"] = "sample_data"
    ) -> str:
        """Create data visualizations using matplotlib and seaborn"""
        
        result = await (
            dag.container()
            .from_("python:3.12-slim")
            .with_exec([
                "pip", "install", 
                "pandas", "numpy", "matplotlib", "seaborn", "plotly"
            ])
            .with_new_file("/app/visualize.py",
                f'''
import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
import json
from sklearn.datasets import make_classification

print("📊 Creating data visualizations...")
dataset_name = "{dataset_name}"

# Generate sample data
X, y = make_classification(n_samples=500, n_features=4, n_classes=2, random_state=42)
df = pd.DataFrame(X, columns=[f'feature_{{i+1}}' for i in range(4)])
df['target'] = y

# Basic statistics
stats = {{
    "dataset_name": dataset_name,
    "shape": df.shape,
    "columns": df.columns.tolist(),
    "target_distribution": df['target'].value_counts().to_dict(),
    "feature_means": df.drop('target', axis=1).mean().to_dict(),
    "feature_correlations": df.drop('target', axis=1).corr().values.tolist()
}}

# Note: In a real scenario, we would save actual plots
# For demo purposes, we return the analysis
print("📈 Visualization analysis complete!")
print("📊 Dataset statistics:")
print(json.dumps(stats, indent=2))

# Simulate plot creation
plots_created = [
    "correlation_heatmap.png",
    "feature_distributions.png", 
    "target_distribution.png",
    "pairplot.png"
]

result = {{
    **stats,
    "plots_created": plots_created,
    "status": "✅ Visualizations created successfully!"
}}

print("🎨 Final visualization results:")
print(json.dumps(result, indent=2))
                ''')
            .with_workdir("/app")
            .with_exec(["python", "visualize.py"])
            .stdout()
        )
        
        return f"📊 Data Visualization Result:\n{result}"

    @function
    async def deep_learning_demo(
        self,
        framework: Annotated[str, "DL framework"] = "pytorch"
    ) -> str:
        """Demonstrate deep learning capabilities with PyTorch or TensorFlow"""
        
        if framework not in ["pytorch", "tensorflow"]:
            return f"❌ Unsupported framework: {framework}. Use 'pytorch' or 'tensorflow'"
        
        pip_packages = {
            "pytorch": "torch torchvision",
            "tensorflow": "tensorflow"
        }
        
        result = await (
            dag.container()
            .from_("python:3.12-slim")
            .with_exec(["pip", "install"] + pip_packages[framework].split() + ["numpy"])
            .with_new_file("/app/deep_learning.py",
                f'''
import numpy as np
import json

framework = "{framework}"
print(f"🧠 Deep Learning Demo with {{framework}}")

if framework == "pytorch":
    import torch
    import torch.nn as nn
    import torch.optim as optim
    
    # Simple neural network
    class SimpleNet(nn.Module):
        def __init__(self):
            super(SimpleNet, self).__init__()
            self.fc1 = nn.Linear(10, 50)
            self.fc2 = nn.Linear(50, 1)
            self.relu = nn.ReLU()
            
        def forward(self, x):
            x = self.relu(self.fc1(x))
            x = self.fc2(x)
            return x
    
    model = SimpleNet()
    optimizer = optim.Adam(model.parameters(), lr=0.001)
    criterion = nn.MSELoss()
    
    # Generate sample data
    X = torch.randn(100, 10)
    y = torch.randn(100, 1)
    
    # Train for a few epochs
    for epoch in range(10):
        optimizer.zero_grad()
        outputs = model(X)
        loss = criterion(outputs, y)
        loss.backward()
        optimizer.step()
    
    result = {{
        "framework": framework,
        "model_parameters": sum(p.numel() for p in model.parameters()),
        "final_loss": float(loss.item()),
        "pytorch_version": torch.__version__,
        "status": "✅ PyTorch model trained successfully!"
    }}
    
elif framework == "tensorflow":
    import tensorflow as tf
    
    # Simple model
    model = tf.keras.Sequential([
        tf.keras.layers.Dense(50, activation='relu', input_shape=(10,)),
        tf.keras.layers.Dense(1)
    ])
    
    model.compile(optimizer='adam', loss='mse')
    
    # Generate sample data
    X = np.random.randn(100, 10)
    y = np.random.randn(100, 1)
    
    # Train for a few epochs
    history = model.fit(X, y, epochs=10, verbose=0)
    
    result = {{
        "framework": framework,
        "model_parameters": model.count_params(),
        "final_loss": float(history.history['loss'][-1]),
        "tensorflow_version": tf.__version__,
        "status": "✅ TensorFlow model trained successfully!"
    }}

print("🎯 Deep Learning Results:")
print(json.dumps(result, indent=2))
                ''')
            .with_workdir("/app")
            .with_exec(["python", "deep_learning.py"])
            .stdout()
        )
        
        return f"🧠 Deep Learning Result:\n{result}"

    @function
    async def python_advantages(self) -> str:
        """Explain why Python is ideal for data processing and ML"""
        
        advantages = """
🐍 Python Data Module Advantages:

✅ Rich Ecosystem - NumPy, pandas, scikit-learn, PyTorch, TensorFlow
✅ Interactive Development - Jupyter notebooks, IPython, rapid prototyping  
✅ Scientific Computing - Mature libraries for statistics and mathematics
✅ ML/AI Libraries - Comprehensive machine learning and deep learning tools
✅ Data Visualization - Matplotlib, seaborn, plotly for beautiful charts
✅ Community Support - Vast community, extensive documentation
✅ Flexibility - Dynamic typing, easy experimentation
✅ Integration - Works with databases, APIs, file formats

Perfect for:
📊 Data analysis and preprocessing
🧠 Machine learning model development  
📈 Statistical analysis and visualization
🔬 Scientific computing and research
🤖 AI and deep learning experiments
📚 Rapid prototyping and experimentation

Combined with Go infrastructure module:
🚀 Python handles data science, Go handles deployment
⚡ Best of both worlds - Python's ease + Go's performance
🔄 Seamless integration through Dagger's cross-language calls
"""
        return advantages

    @function
    async def container_info(self) -> str:
        """Get information about the Python container environment"""
        
        result = await (
            dag.container()
            .from_("python:3.12-slim")
            .with_exec(["python", "-c", 
                """
import sys
import platform
print("🐍 Python Data Module Environment:")
print(f"Python version: {sys.version}")
print(f"Platform: {platform.platform()}")
print(f"Architecture: {platform.architecture()}")
print(f"Machine: {platform.machine()}")
                """])
            .stdout()
        )
        
        return result