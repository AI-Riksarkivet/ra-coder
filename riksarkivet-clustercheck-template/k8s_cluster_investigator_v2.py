#!/usr/bin/env -S uv run
# /// script
# requires-python = ">=3.9"
# dependencies = [
#     "kubernetes>=28.1.0",
#     "tabulate>=0.9.0",
#     "pyyaml>=6.0",
#     "rich>=13.7.0",
#     "click>=8.1.0",
#     "jinja2>=3.1.2",
# ]
# ///

"""
Advanced Kubernetes Cluster Investigation Script v2
Comprehensive analysis and reporting for Kubernetes clusters
"""

import subprocess
import json
import sys
import re
import os
from datetime import datetime, timedelta, timezone
from typing import Dict, List, Any, Optional, Tuple
from collections import defaultdict
from tabulate import tabulate
from rich.console import Console
from rich.table import Table
from rich.panel import Panel
from rich.text import Text
from rich.progress import Progress, SpinnerColumn, TextColumn, BarColumn, TaskProgressColumn
from rich.layout import Layout
from rich.live import Live
from rich.prompt import Prompt, Confirm
import yaml
import click
from jinja2 import Template

console = Console()

class K8sClusterInvestigator:
    def __init__(self, output_format: str = "console", verbose: bool = False, 
                 namespaces: Optional[List[str]] = None):
        self.cluster_info = {}
        self.issues = []
        self.warnings = []
        self.metrics = {}
        self.health_score = 100
        self.output_format = output_format
        self.verbose = verbose
        self.target_namespaces = namespaces
        self.rbac_errors = []
        
    def run_kubectl(self, args: List[str], namespace: Optional[str] = None) -> Optional[Dict]:
        """Execute kubectl command and return JSON output"""
        cmd = ["kubectl"]
        if namespace:
            cmd.extend(["-n", namespace])
        cmd.extend(args)
        
        # Don't add -o json if it's already in args
        if "-o" not in args:
            cmd.extend(["-o", "json"])
        
        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=30)
            if result.returncode == 0:
                if "-o" in args and "json" in args:
                    return json.loads(result.stdout)
                elif "-o" not in args:
                    return json.loads(result.stdout)
                else:
                    return {"output": result.stdout}
            else:
                # Track RBAC errors
                if "forbidden" in result.stderr.lower():
                    self.rbac_errors.append(f"RBAC: {' '.join(cmd)} - {result.stderr.split(':')[1].strip()}")
                if self.verbose:
                    console.print(f"[yellow]Warning: {' '.join(cmd)}: {result.stderr}[/yellow]")
                return None
        except subprocess.TimeoutExpired:
            if self.verbose:
                console.print(f"[yellow]Command timed out: {' '.join(cmd)}[/yellow]")
            return None
        except json.JSONDecodeError:
            if self.verbose:
                console.print(f"[yellow]Failed to parse JSON from: {' '.join(cmd)}[/yellow]")
            return None
        except Exception as e:
            if self.verbose:
                console.print(f"[red]Error: {e}[/red]")
            return None

    def calculate_health_score(self):
        """Calculate overall cluster health score"""
        penalties = {
            "node_not_ready": 20,
            "pod_failed": 5,
            "pod_pending": 2,
            "high_restart": 3,
            "pvc_pending": 2,
            "deployment_unhealthy": 5,
            "warning_event": 1,
            "critical_resource": 10
        }
        
        # Node health
        if "nodes" in self.cluster_info:
            for node in self.cluster_info["nodes"]["details"]:
                if node["status"] != "Ready":
                    self.health_score -= penalties["node_not_ready"]
        
        # Pod health
        if "pods" in self.cluster_info:
            pods = self.cluster_info["pods"]
            self.health_score -= pods["failed"] * penalties["pod_failed"]
            self.health_score -= min(pods["pending"] * penalties["pod_pending"], 10)
            self.health_score -= min(len(pods.get("problematic", [])) * penalties["high_restart"], 15)
        
        # Storage health
        if "storage" in self.cluster_info:
            if "pvcs" in self.cluster_info["storage"]:
                self.health_score -= self.cluster_info["storage"]["pvcs"]["pending"] * penalties["pvc_pending"]
        
        # Deployment health
        if "workloads" in self.cluster_info:
            if "deployments" in self.cluster_info["workloads"]:
                deps = self.cluster_info["workloads"]["deployments"]
                self.health_score -= deps["unhealthy"] * penalties["deployment_unhealthy"]
        
        # Resource pressure
        if "metrics" in self.cluster_info:
            for metric in self.cluster_info.get("metrics", {}).get("critical_resources", []):
                self.health_score -= penalties["critical_resource"]
        
        self.health_score = max(0, self.health_score)
        
        # Determine health status
        if self.health_score >= 90:
            self.cluster_info["health_status"] = "Excellent"
        elif self.health_score >= 75:
            self.cluster_info["health_status"] = "Good"
        elif self.health_score >= 60:
            self.cluster_info["health_status"] = "Fair"
        elif self.health_score >= 40:
            self.cluster_info["health_status"] = "Poor"
        else:
            self.cluster_info["health_status"] = "Critical"

    def get_cluster_info(self):
        """Get basic cluster information"""
        # Get cluster version
        version_info = self.run_kubectl(["version"])
        if version_info:
            self.cluster_info["version"] = {
                "client": version_info.get("clientVersion", {}).get("gitVersion", "Unknown"),
                "server": version_info.get("serverVersion", {}).get("gitVersion", "Unknown"),
                "platform": version_info.get("serverVersion", {}).get("platform", "Unknown")
            }
        
        # Get nodes
        nodes = self.run_kubectl(["get", "nodes"])
        if nodes:
            self.cluster_info["nodes"] = self.process_nodes(nodes)
        
        # Get API resources to check capabilities
        api_resources = subprocess.run(["kubectl", "api-resources", "--verbs=list", "-o", "name"], 
                                     capture_output=True, text=True)
        if api_resources.returncode == 0:
            self.cluster_info["available_resources"] = api_resources.stdout.strip().split("\n")

    def process_nodes(self, nodes_data: Dict) -> Dict:
        """Process node information with enhanced metrics"""
        nodes_info = {
            "count": len(nodes_data.get("items", [])),
            "ready": 0,
            "not_ready": 0,
            "details": [],
            "total_capacity": {"cpu": 0, "memory": 0, "pods": 0},
            "total_allocatable": {"cpu": 0, "memory": 0, "pods": 0}
        }
        
        for node in nodes_data.get("items", []):
            node_detail = {
                "name": node["metadata"]["name"],
                "status": "Unknown",
                "roles": [],
                "version": node["status"]["nodeInfo"]["kubeletVersion"],
                "kernel": node["status"]["nodeInfo"]["kernelVersion"],
                "os": node["status"]["nodeInfo"]["osImage"],
                "container_runtime": node["status"]["nodeInfo"]["containerRuntimeVersion"],
                "conditions": {},
                "taints": [],
                "age": self.calculate_age(node["metadata"].get("creationTimestamp"))
            }
            
            # Get node status and conditions
            for condition in node["status"].get("conditions", []):
                if condition["type"] == "Ready":
                    node_detail["status"] = "Ready" if condition["status"] == "True" else "NotReady"
                    if node_detail["status"] == "Ready":
                        nodes_info["ready"] += 1
                    else:
                        nodes_info["not_ready"] += 1
                node_detail["conditions"][condition["type"]] = {
                    "status": condition["status"],
                    "message": condition.get("message", "")
                }
            
            # Check for pressure conditions
            for cond_type in ["MemoryPressure", "DiskPressure", "PIDPressure"]:
                if cond_type in node_detail["conditions"]:
                    if node_detail["conditions"][cond_type]["status"] == "True":
                        self.warnings.append(f"Node {node_detail['name']} has {cond_type}")
            
            # Get node roles
            labels = node["metadata"].get("labels", {})
            for label, value in labels.items():
                if "node-role.kubernetes.io/" in label:
                    role = label.split("/")[1]
                    node_detail["roles"].append(role)
            
            # Get taints
            node_detail["taints"] = node["spec"].get("taints", [])
            
            # Check for issues
            if node_detail["status"] != "Ready":
                self.issues.append(f"Node {node_detail['name']} is not ready")
            
            # Get resource capacity and allocatable
            node_detail["capacity"] = {
                "cpu": node["status"]["capacity"].get("cpu", "0"),
                "memory": node["status"]["capacity"].get("memory", "0"),
                "pods": node["status"]["capacity"].get("pods", "0"),
                "storage": node["status"]["capacity"].get("ephemeral-storage", "0")
            }
            node_detail["allocatable"] = {
                "cpu": node["status"]["allocatable"].get("cpu", "0"),
                "memory": node["status"]["allocatable"].get("memory", "0"),
                "pods": node["status"]["allocatable"].get("pods", "0"),
                "storage": node["status"]["allocatable"].get("ephemeral-storage", "0")
            }
            
            # Calculate totals
            try:
                nodes_info["total_capacity"]["cpu"] += int(node_detail["capacity"]["cpu"])
                nodes_info["total_allocatable"]["cpu"] += int(node_detail["allocatable"]["cpu"])
            except:
                pass
            
            nodes_info["details"].append(node_detail)
        
        return nodes_info

    def get_metrics(self):
        """Get resource metrics if metrics-server is available"""
        self.cluster_info["metrics"] = {
            "available": False,
            "node_metrics": [],
            "pod_metrics": [],
            "top_consumers": {"cpu": [], "memory": []},
            "critical_resources": []
        }
        
        # Check if metrics-server is available
        metrics_check = self.run_kubectl(["top", "nodes"])
        if metrics_check:
            self.cluster_info["metrics"]["available"] = True
            
            # Get node metrics
            node_metrics = subprocess.run(["kubectl", "top", "nodes", "--no-headers"], 
                                         capture_output=True, text=True)
            if node_metrics.returncode == 0:
                for line in node_metrics.stdout.strip().split("\n"):
                    if line:
                        parts = line.split()
                        if len(parts) >= 5:
                            self.cluster_info["metrics"]["node_metrics"].append({
                                "name": parts[0],
                                "cpu": parts[1],
                                "cpu_percent": parts[2],
                                "memory": parts[3],
                                "memory_percent": parts[4]
                            })
                            # Check for high usage
                            cpu_pct = int(parts[2].rstrip('%'))
                            mem_pct = int(parts[4].rstrip('%'))
                            if cpu_pct > 80:
                                self.warnings.append(f"Node {parts[0]} CPU usage is {parts[2]}")
                                self.cluster_info["metrics"]["critical_resources"].append(f"High CPU on {parts[0]}")
                            if mem_pct > 85:
                                self.warnings.append(f"Node {parts[0]} memory usage is {parts[4]}")
                                self.cluster_info["metrics"]["critical_resources"].append(f"High memory on {parts[0]}")
            
            # Get top pod consumers
            pod_cpu = subprocess.run(["kubectl", "top", "pods", "--all-namespaces", "--sort-by=cpu", "--no-headers"], 
                                   capture_output=True, text=True)
            if pod_cpu.returncode == 0:
                lines = pod_cpu.stdout.strip().split("\n")[:10]  # Top 10
                for line in lines:
                    if line:
                        parts = line.split()
                        if len(parts) >= 4:
                            self.cluster_info["metrics"]["top_consumers"]["cpu"].append({
                                "namespace": parts[0],
                                "name": parts[1],
                                "cpu": parts[2],
                                "memory": parts[3]
                            })
            
            pod_mem = subprocess.run(["kubectl", "top", "pods", "--all-namespaces", "--sort-by=memory", "--no-headers"], 
                                   capture_output=True, text=True)
            if pod_mem.returncode == 0:
                lines = pod_mem.stdout.strip().split("\n")[:10]  # Top 10
                for line in lines:
                    if line:
                        parts = line.split()
                        if len(parts) >= 4:
                            self.cluster_info["metrics"]["top_consumers"]["memory"].append({
                                "namespace": parts[0],
                                "name": parts[1],
                                "cpu": parts[2],
                                "memory": parts[3]
                            })

    def get_namespaces(self):
        """Get all namespaces with resource counts"""
        namespaces = self.run_kubectl(["get", "namespaces"])
        if namespaces:
            self.cluster_info["namespaces"] = []
            for ns in namespaces.get("items", []):
                ns_name = ns["metadata"]["name"]
                
                # Skip if filtering namespaces
                if self.target_namespaces and ns_name not in self.target_namespaces:
                    continue
                
                ns_info = {
                    "name": ns_name,
                    "status": ns["status"]["phase"],
                    "age": self.calculate_age(ns["metadata"].get("creationTimestamp")),
                    "labels": ns["metadata"].get("labels", {}),
                    "resource_counts": {}
                }
                
                # Get resource counts for namespace
                for resource in ["pods", "services", "deployments", "configmaps", "secrets"]:
                    count_result = subprocess.run(
                        ["kubectl", "get", resource, "-n", ns_name, "--no-headers", "-o", "name"],
                        capture_output=True, text=True
                    )
                    if count_result.returncode == 0:
                        ns_info["resource_counts"][resource] = len(count_result.stdout.strip().split("\n")) if count_result.stdout.strip() else 0
                
                self.cluster_info["namespaces"].append(ns_info)
                
                if ns_info["status"] != "Active":
                    self.issues.append(f"Namespace {ns_info['name']} is in {ns_info['status']} state")

    def get_workloads(self):
        """Get information about workloads with enhanced details"""
        self.cluster_info["workloads"] = {}
        
        # Build namespace filter
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        # Get deployments
        deployments = self.run_kubectl(["get", "deployments"] + ns_args)
        if deployments:
            self.cluster_info["workloads"]["deployments"] = self.process_deployments(deployments)
        
        # Get daemonsets
        daemonsets = self.run_kubectl(["get", "daemonsets"] + ns_args)
        if daemonsets:
            self.cluster_info["workloads"]["daemonsets"] = self.process_daemonsets(daemonsets)
        
        # Get statefulsets
        statefulsets = self.run_kubectl(["get", "statefulsets"] + ns_args)
        if statefulsets:
            self.cluster_info["workloads"]["statefulsets"] = self.process_statefulsets(statefulsets)
        
        # Get jobs
        jobs = self.run_kubectl(["get", "jobs"] + ns_args)
        if jobs:
            self.cluster_info["workloads"]["jobs"] = self.process_jobs(jobs)
        
        # Get cronjobs
        cronjobs = self.run_kubectl(["get", "cronjobs"] + ns_args)
        if cronjobs:
            self.cluster_info["workloads"]["cronjobs"] = self.process_cronjobs(cronjobs)

    def process_deployments(self, deployments_data: Dict) -> Dict:
        """Process deployment information with strategy details"""
        deployments_info = {
            "total": len(deployments_data.get("items", [])),
            "healthy": 0,
            "unhealthy": 0,
            "scaling": 0,
            "details": [],
            "by_strategy": defaultdict(int)
        }
        
        for deployment in deployments_data.get("items", []):
            strategy = deployment["spec"].get("strategy", {}).get("type", "Unknown")
            deployments_info["by_strategy"][strategy] += 1
            
            deploy_detail = {
                "name": deployment["metadata"]["name"],
                "namespace": deployment["metadata"]["namespace"],
                "replicas": deployment["spec"].get("replicas", 0),
                "ready_replicas": deployment["status"].get("readyReplicas", 0),
                "available_replicas": deployment["status"].get("availableReplicas", 0),
                "updated_replicas": deployment["status"].get("updatedReplicas", 0),
                "strategy": strategy,
                "age": self.calculate_age(deployment["metadata"].get("creationTimestamp")),
                "images": []
            }
            
            # Get container images
            for container in deployment["spec"]["template"]["spec"].get("containers", []):
                deploy_detail["images"].append(container["image"])
            
            # Check health status
            if deploy_detail["ready_replicas"] == deploy_detail["replicas"]:
                if deploy_detail["replicas"] > 0:
                    deployments_info["healthy"] += 1
            else:
                deployments_info["unhealthy"] += 1
                if deploy_detail["updated_replicas"] != deploy_detail["replicas"]:
                    deployments_info["scaling"] += 1
                self.issues.append(
                    f"Deployment {deploy_detail['namespace']}/{deploy_detail['name']} "
                    f"has {deploy_detail['ready_replicas']}/{deploy_detail['replicas']} ready replicas"
                )
            
            deployments_info["details"].append(deploy_detail)
        
        return dict(deployments_info)

    def process_daemonsets(self, daemonsets_data: Dict) -> Dict:
        """Process daemonset information"""
        daemonsets_info = {
            "total": len(daemonsets_data.get("items", [])),
            "healthy": 0,
            "unhealthy": 0,
            "details": []
        }
        
        for daemonset in daemonsets_data.get("items", []):
            ds_detail = {
                "name": daemonset["metadata"]["name"],
                "namespace": daemonset["metadata"]["namespace"],
                "desired": daemonset["status"].get("desiredNumberScheduled", 0),
                "current": daemonset["status"].get("currentNumberScheduled", 0),
                "ready": daemonset["status"].get("numberReady", 0),
                "updated": daemonset["status"].get("updatedNumberScheduled", 0),
                "age": self.calculate_age(daemonset["metadata"].get("creationTimestamp"))
            }
            
            if ds_detail["ready"] == ds_detail["desired"]:
                daemonsets_info["healthy"] += 1
            else:
                daemonsets_info["unhealthy"] += 1
                self.warnings.append(
                    f"DaemonSet {ds_detail['namespace']}/{ds_detail['name']} "
                    f"has {ds_detail['ready']}/{ds_detail['desired']} ready pods"
                )
            
            daemonsets_info["details"].append(ds_detail)
        
        return daemonsets_info

    def process_statefulsets(self, statefulsets_data: Dict) -> Dict:
        """Process statefulset information"""
        statefulsets_info = {
            "total": len(statefulsets_data.get("items", [])),
            "healthy": 0,
            "unhealthy": 0,
            "details": []
        }
        
        for statefulset in statefulsets_data.get("items", []):
            sts_detail = {
                "name": statefulset["metadata"]["name"],
                "namespace": statefulset["metadata"]["namespace"],
                "replicas": statefulset["spec"].get("replicas", 0),
                "ready_replicas": statefulset["status"].get("readyReplicas", 0),
                "current_replicas": statefulset["status"].get("currentReplicas", 0),
                "age": self.calculate_age(statefulset["metadata"].get("creationTimestamp"))
            }
            
            if sts_detail["ready_replicas"] == sts_detail["replicas"]:
                statefulsets_info["healthy"] += 1
            else:
                statefulsets_info["unhealthy"] += 1
                self.issues.append(
                    f"StatefulSet {sts_detail['namespace']}/{sts_detail['name']} "
                    f"has {sts_detail['ready_replicas']}/{sts_detail['replicas']} ready replicas"
                )
            
            statefulsets_info["details"].append(sts_detail)
        
        return statefulsets_info

    def process_jobs(self, jobs_data: Dict) -> Dict:
        """Process job information"""
        jobs_info = {
            "total": len(jobs_data.get("items", [])),
            "succeeded": 0,
            "failed": 0,
            "running": 0,
            "details": []
        }
        
        for job in jobs_data.get("items", []):
            job_detail = {
                "name": job["metadata"]["name"],
                "namespace": job["metadata"]["namespace"],
                "completions": job["spec"].get("completions", 1),
                "succeeded": job["status"].get("succeeded", 0),
                "failed": job["status"].get("failed", 0),
                "active": job["status"].get("active", 0),
                "age": self.calculate_age(job["metadata"].get("creationTimestamp"))
            }
            
            if job_detail["succeeded"] > 0:
                jobs_info["succeeded"] += 1
            elif job_detail["failed"] > 0:
                jobs_info["failed"] += 1
            elif job_detail["active"] > 0:
                jobs_info["running"] += 1
            
            jobs_info["details"].append(job_detail)
        
        return jobs_info

    def process_cronjobs(self, cronjobs_data: Dict) -> Dict:
        """Process cronjob information"""
        cronjobs_info = {
            "total": len(cronjobs_data.get("items", [])),
            "active": 0,
            "suspended": 0,
            "details": []
        }
        
        for cronjob in cronjobs_data.get("items", []):
            cj_detail = {
                "name": cronjob["metadata"]["name"],
                "namespace": cronjob["metadata"]["namespace"],
                "schedule": cronjob["spec"].get("schedule", "Unknown"),
                "suspended": cronjob["spec"].get("suspend", False),
                "last_scheduled": cronjob["status"].get("lastScheduleTime", "Never"),
                "active_jobs": len(cronjob["status"].get("active", []))
            }
            
            if cj_detail["suspended"]:
                cronjobs_info["suspended"] += 1
            elif cj_detail["active_jobs"] > 0:
                cronjobs_info["active"] += 1
            
            cronjobs_info["details"].append(cj_detail)
        
        return cronjobs_info

    def get_pods(self):
        """Get pod information with container details"""
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        pods = self.run_kubectl(["get", "pods"] + ns_args)
        if pods:
            self.cluster_info["pods"] = self.process_pods(pods)

    def process_pods(self, pods_data: Dict) -> Dict:
        """Process pod information with enhanced container details"""
        pods_info = {
            "total": len(pods_data.get("items", [])),
            "running": 0,
            "pending": 0,
            "failed": 0,
            "succeeded": 0,
            "unknown": 0,
            "terminating": 0,
            "problematic": [],
            "by_namespace": defaultdict(int),
            "container_stats": {
                "total": 0,
                "running": 0,
                "waiting": 0,
                "terminated": 0
            }
        }
        
        for pod in pods_data.get("items", []):
            namespace = pod["metadata"]["namespace"]
            phase = pod["status"].get("phase", "Unknown")
            pods_info["by_namespace"][namespace] += 1
            
            # Check if pod is terminating
            if pod["metadata"].get("deletionTimestamp"):
                pods_info["terminating"] += 1
                self.warnings.append(f"Pod {namespace}/{pod['metadata']['name']} is terminating")
            
            if phase == "Running":
                pods_info["running"] += 1
            elif phase == "Pending":
                pods_info["pending"] += 1
                self.warnings.append(f"Pod {namespace}/{pod['metadata']['name']} is pending")
            elif phase == "Failed":
                pods_info["failed"] += 1
                self.issues.append(f"Pod {namespace}/{pod['metadata']['name']} has failed")
            elif phase == "Succeeded":
                pods_info["succeeded"] += 1
            else:
                pods_info["unknown"] += 1
            
            # Analyze containers
            all_containers = (pod["status"].get("containerStatuses", []) + 
                            pod["status"].get("initContainerStatuses", []))
            
            for container_status in all_containers:
                pods_info["container_stats"]["total"] += 1
                
                # Check container state
                state = container_status.get("state", {})
                if "running" in state:
                    pods_info["container_stats"]["running"] += 1
                elif "waiting" in state:
                    pods_info["container_stats"]["waiting"] += 1
                    reason = state["waiting"].get("reason", "Unknown")
                    if reason in ["CrashLoopBackOff", "ImagePullBackOff", "ErrImagePull"]:
                        self.issues.append(
                            f"Pod {namespace}/{pod['metadata']['name']} "
                            f"container {container_status['name']}: {reason}"
                        )
                elif "terminated" in state:
                    pods_info["container_stats"]["terminated"] += 1
                
                # Check restart counts
                restart_count = container_status.get("restartCount", 0)
                if restart_count > 5:
                    pod_issue = {
                        "name": pod["metadata"]["name"],
                        "namespace": namespace,
                        "container": container_status["name"],
                        "restarts": restart_count,
                        "phase": phase,
                        "ready": container_status.get("ready", False)
                    }
                    pods_info["problematic"].append(pod_issue)
                    self.warnings.append(
                        f"Pod {namespace}/{pod['metadata']['name']} "
                        f"container {container_status['name']} has {restart_count} restarts"
                    )
        
        # Sort problematic pods by restart count
        pods_info["problematic"] = sorted(pods_info["problematic"], 
                                         key=lambda x: x["restarts"], reverse=True)
        
        return dict(pods_info)

    def get_services(self):
        """Get service information with endpoint details"""
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        services = self.run_kubectl(["get", "services"] + ns_args)
        if services:
            self.cluster_info["services"] = self.process_services(services)

    def process_services(self, services_data: Dict) -> Dict:
        """Process service information"""
        services_info = {
            "total": len(services_data.get("items", [])),
            "types": defaultdict(int),
            "with_external_ip": 0,
            "without_endpoints": 0,
            "details": []
        }
        
        for service in services_data.get("items", []):
            svc_type = service["spec"].get("type", "Unknown")
            services_info["types"][svc_type] += 1
            
            svc_detail = {
                "name": service["metadata"]["name"],
                "namespace": service["metadata"]["namespace"],
                "type": svc_type,
                "cluster_ip": service["spec"].get("clusterIP", "None"),
                "ports": [],
                "selector": service["spec"].get("selector", {})
            }
            
            for port in service["spec"].get("ports", []):
                port_info = f"{port.get('port')}:{port.get('targetPort', port.get('port'))}/{port.get('protocol', 'TCP')}"
                svc_detail["ports"].append(port_info)
            
            if svc_type == "LoadBalancer":
                ingress = service["status"].get("loadBalancer", {}).get("ingress", [])
                if not ingress:
                    self.warnings.append(
                        f"LoadBalancer service {svc_detail['namespace']}/{svc_detail['name']} "
                        f"has no external IP assigned"
                    )
                else:
                    svc_detail["external_ip"] = ingress[0].get("ip", ingress[0].get("hostname", "Unknown"))
                    services_info["with_external_ip"] += 1
            elif svc_type == "NodePort":
                svc_detail["node_ports"] = [p.get("nodePort") for p in service["spec"].get("ports", [])]
            
            # Check if service has endpoints
            if svc_detail["selector"] and svc_type != "ExternalName":
                endpoints = self.run_kubectl(["get", "endpoints", svc_detail["name"]], 
                                            namespace=svc_detail["namespace"])
                if endpoints and endpoints.get("items"):
                    ep = endpoints["items"][0] if endpoints.get("items") else {}
                    if not ep.get("subsets"):
                        services_info["without_endpoints"] += 1
                        self.warnings.append(
                            f"Service {svc_detail['namespace']}/{svc_detail['name']} has no endpoints"
                        )
            
            services_info["details"].append(svc_detail)
        
        return dict(services_info)

    def get_networking(self):
        """Get ingress and network policy information"""
        self.cluster_info["networking"] = {
            "ingresses": {"total": 0, "details": []},
            "network_policies": {"total": 0, "details": []},
            "ingress_classes": []
        }
        
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        # Get Ingresses
        ingresses = self.run_kubectl(["get", "ingresses"] + ns_args)
        if ingresses:
            self.cluster_info["networking"]["ingresses"]["total"] = len(ingresses.get("items", []))
            for ingress in ingresses.get("items", []):
                ing_detail = {
                    "name": ingress["metadata"]["name"],
                    "namespace": ingress["metadata"]["namespace"],
                    "class": ingress["spec"].get("ingressClassName", "default"),
                    "hosts": [],
                    "tls": bool(ingress["spec"].get("tls"))
                }
                
                for rule in ingress["spec"].get("rules", []):
                    if rule.get("host"):
                        ing_detail["hosts"].append(rule["host"])
                
                # Check for LoadBalancer IP
                lb_ingress = ingress["status"].get("loadBalancer", {}).get("ingress", [])
                if lb_ingress:
                    ing_detail["address"] = lb_ingress[0].get("ip", lb_ingress[0].get("hostname", "Pending"))
                
                self.cluster_info["networking"]["ingresses"]["details"].append(ing_detail)
        
        # Get IngressClasses
        ingress_classes = self.run_kubectl(["get", "ingressclasses"])
        if ingress_classes:
            for ic in ingress_classes.get("items", []):
                self.cluster_info["networking"]["ingress_classes"].append({
                    "name": ic["metadata"]["name"],
                    "controller": ic["spec"].get("controller", "Unknown"),
                    "is_default": ic["metadata"].get("annotations", {}).get(
                        "ingressclass.kubernetes.io/is-default-class") == "true"
                })
        
        # Get NetworkPolicies
        netpols = self.run_kubectl(["get", "networkpolicies"] + ns_args)
        if netpols:
            self.cluster_info["networking"]["network_policies"]["total"] = len(netpols.get("items", []))
            for netpol in netpols.get("items", []):
                np_detail = {
                    "name": netpol["metadata"]["name"],
                    "namespace": netpol["metadata"]["namespace"],
                    "pod_selector": netpol["spec"].get("podSelector", {}),
                    "policy_types": netpol["spec"].get("policyTypes", []),
                    "ingress_rules": len(netpol["spec"].get("ingress", [])),
                    "egress_rules": len(netpol["spec"].get("egress", []))
                }
                self.cluster_info["networking"]["network_policies"]["details"].append(np_detail)

    def get_storage(self):
        """Get storage information (PVs, PVCs, StorageClasses)"""
        self.cluster_info["storage"] = {}
        
        # Get StorageClasses
        storage_classes = self.run_kubectl(["get", "storageclasses"])
        if storage_classes:
            self.cluster_info["storage"]["storage_classes"] = {
                "total": len(storage_classes.get("items", [])),
                "details": []
            }
            for sc in storage_classes.get("items", []):
                sc_detail = {
                    "name": sc["metadata"]["name"],
                    "provisioner": sc["provisioner"],
                    "reclaim_policy": sc.get("reclaimPolicy", "Delete"),
                    "volume_binding_mode": sc.get("volumeBindingMode", "Immediate"),
                    "is_default": sc["metadata"].get("annotations", {}).get(
                        "storageclass.kubernetes.io/is-default-class") == "true"
                }
                self.cluster_info["storage"]["storage_classes"]["details"].append(sc_detail)
        
        # Get PVs
        pvs = self.run_kubectl(["get", "persistentvolumes"])
        if pvs:
            self.cluster_info["storage"]["pvs"] = self.process_pvs(pvs)
        
        # Get PVCs
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        pvcs = self.run_kubectl(["get", "persistentvolumeclaims"] + ns_args)
        if pvcs:
            self.cluster_info["storage"]["pvcs"] = self.process_pvcs(pvcs)

    def process_pvs(self, pvs_data: Dict) -> Dict:
        """Process persistent volume information"""
        pvs_info = {
            "total": len(pvs_data.get("items", [])),
            "available": 0,
            "bound": 0,
            "released": 0,
            "failed": 0,
            "total_capacity": 0,
            "details": []
        }
        
        for pv in pvs_data.get("items", []):
            status = pv["status"].get("phase", "Unknown")
            
            if status == "Available":
                pvs_info["available"] += 1
            elif status == "Bound":
                pvs_info["bound"] += 1
            elif status == "Released":
                pvs_info["released"] += 1
            elif status == "Failed":
                pvs_info["failed"] += 1
                self.issues.append(f"PV {pv['metadata']['name']} is in Failed state")
            
            capacity_str = pv["spec"].get("capacity", {}).get("storage", "0")
            
            pv_detail = {
                "name": pv["metadata"]["name"],
                "capacity": capacity_str,
                "access_modes": pv["spec"].get("accessModes", []),
                "reclaim_policy": pv["spec"].get("persistentVolumeReclaimPolicy", "Unknown"),
                "status": status,
                "storage_class": pv["spec"].get("storageClassName", ""),
                "claim": pv["spec"].get("claimRef", {}).get("name", "None") if pv["spec"].get("claimRef") else "None"
            }
            pvs_info["details"].append(pv_detail)
        
        return pvs_info

    def process_pvcs(self, pvcs_data: Dict) -> Dict:
        """Process persistent volume claim information"""
        pvcs_info = {
            "total": len(pvcs_data.get("items", [])),
            "bound": 0,
            "pending": 0,
            "lost": 0,
            "by_namespace": defaultdict(int),
            "details": []
        }
        
        for pvc in pvcs_data.get("items", []):
            namespace = pvc["metadata"]["namespace"]
            status = pvc["status"].get("phase", "Unknown")
            pvcs_info["by_namespace"][namespace] += 1
            
            if status == "Bound":
                pvcs_info["bound"] += 1
            elif status == "Pending":
                pvcs_info["pending"] += 1
                self.warnings.append(
                    f"PVC {namespace}/{pvc['metadata']['name']} is pending"
                )
            elif status == "Lost":
                pvcs_info["lost"] += 1
                self.issues.append(
                    f"PVC {namespace}/{pvc['metadata']['name']} is lost"
                )
            
            pvc_detail = {
                "name": pvc["metadata"]["name"],
                "namespace": namespace,
                "status": status,
                "volume": pvc["spec"].get("volumeName", "None"),
                "storage_class": pvc["spec"].get("storageClassName", ""),
                "capacity": pvc["status"].get("capacity", {}).get("storage", "Unknown") if pvc["status"].get("capacity") else "Unknown",
                "access_modes": pvc["spec"].get("accessModes", []),
                "age": self.calculate_age(pvc["metadata"].get("creationTimestamp"))
            }
            pvcs_info["details"].append(pvc_detail)
        
        return dict(pvcs_info)

    def get_config_secrets(self):
        """Get ConfigMap and Secret counts"""
        self.cluster_info["configuration"] = {
            "configmaps": {"total": 0, "by_namespace": defaultdict(int)},
            "secrets": {"total": 0, "by_namespace": defaultdict(int), "by_type": defaultdict(int)}
        }
        
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        # Get ConfigMaps
        configmaps = self.run_kubectl(["get", "configmaps"] + ns_args)
        if configmaps:
            self.cluster_info["configuration"]["configmaps"]["total"] = len(configmaps.get("items", []))
            for cm in configmaps.get("items", []):
                namespace = cm["metadata"]["namespace"]
                self.cluster_info["configuration"]["configmaps"]["by_namespace"][namespace] += 1
        
        # Get Secrets
        secrets = self.run_kubectl(["get", "secrets"] + ns_args)
        if secrets:
            self.cluster_info["configuration"]["secrets"]["total"] = len(secrets.get("items", []))
            for secret in secrets.get("items", []):
                namespace = secret["metadata"]["namespace"]
                secret_type = secret.get("type", "Opaque")
                self.cluster_info["configuration"]["secrets"]["by_namespace"][namespace] += 1
                self.cluster_info["configuration"]["secrets"]["by_type"][secret_type] += 1

    def get_crds_operators(self):
        """Get Custom Resource Definitions and detect operators"""
        self.cluster_info["extensions"] = {
            "crds": {"total": 0, "details": []},
            "operators": [],
            "api_groups": []
        }
        
        # Get CRDs
        crds = self.run_kubectl(["get", "customresourcedefinitions"])
        if crds:
            self.cluster_info["extensions"]["crds"]["total"] = len(crds.get("items", []))
            
            operator_patterns = ["operator", "controller", "manager"]
            detected_operators = set()
            
            for crd in crds.get("items", []):
                crd_name = crd["metadata"]["name"]
                group = crd["spec"]["group"]
                
                crd_detail = {
                    "name": crd_name,
                    "group": group,
                    "scope": crd["spec"]["scope"],
                    "versions": [v["name"] for v in crd["spec"].get("versions", [])]
                }
                self.cluster_info["extensions"]["crds"]["details"].append(crd_detail)
                
                # Detect potential operators
                for pattern in operator_patterns:
                    if pattern in group.lower():
                        detected_operators.add(group)
            
            self.cluster_info["extensions"]["operators"] = list(detected_operators)
        
        # Get API Groups
        api_groups = subprocess.run(["kubectl", "api-resources", "--verbs=list", "-o", "wide"], 
                                   capture_output=True, text=True)
        if api_groups.returncode == 0:
            lines = api_groups.stdout.strip().split("\n")[1:]  # Skip header
            groups = set()
            for line in lines:
                parts = line.split()
                if len(parts) > 2:
                    apigroup = parts[2] if parts[2] != "" else "core"
                    groups.add(apigroup)
            self.cluster_info["extensions"]["api_groups"] = sorted(list(groups))

    def get_events(self):
        """Get recent cluster events with categorization"""
        ns_args = ["--all-namespaces"]
        if self.target_namespaces:
            ns_args = []
            for ns in self.target_namespaces:
                ns_args.extend(["-n", ns])
        
        events = self.run_kubectl(["get", "events", "--sort-by=.lastTimestamp"] + ns_args)
        if events:
            self.cluster_info["events"] = self.process_events(events)

    def process_events(self, events_data: Dict) -> Dict:
        """Process cluster events with enhanced categorization"""
        events_info = {
            "total": len(events_data.get("items", [])),
            "warning_events": [],
            "error_patterns": defaultdict(int),
            "recent_critical": [],
            "by_reason": defaultdict(int)
        }
        
        critical_reasons = ["BackOff", "Failed", "FailedScheduling", "FailedMount", 
                          "FailedAttachVolume", "NodeNotReady", "Unhealthy"]
        
        now = datetime.now(timezone.utc)
        one_hour_ago = now - timedelta(hours=1)
        
        for event in events_data.get("items", []):
            event_type = event.get("type", "Normal")
            reason = event.get("reason", "Unknown")
            events_info["by_reason"][reason] += 1
            
            if event_type == "Warning":
                event_detail = {
                    "namespace": event["metadata"]["namespace"],
                    "object": f"{event['involvedObject']['kind']}/{event['involvedObject']['name']}",
                    "reason": reason,
                    "message": event.get("message", "No message"),
                    "count": event.get("count", 1),
                    "last_seen": event.get("lastTimestamp", "Unknown"),
                    "first_seen": event.get("firstTimestamp", "Unknown")
                }
                events_info["warning_events"].append(event_detail)
                
                # Categorize error patterns
                if "pull" in reason.lower() or "image" in reason.lower():
                    events_info["error_patterns"]["Image Issues"] += 1
                elif "schedule" in reason.lower():
                    events_info["error_patterns"]["Scheduling Issues"] += 1
                elif "volume" in reason.lower() or "mount" in reason.lower():
                    events_info["error_patterns"]["Storage Issues"] += 1
                elif "probe" in reason.lower() or "unhealthy" in reason.lower():
                    events_info["error_patterns"]["Health Check Issues"] += 1
                
                # Check if critical and recent
                if reason in critical_reasons and event.get("lastTimestamp"):
                    try:
                        event_time = datetime.fromisoformat(event["lastTimestamp"].replace("Z", "+00:00"))
                        if event_time > one_hour_ago:
                            events_info["recent_critical"].append(event_detail)
                            self.warnings.append(
                                f"Recent critical event: {event_detail['object']} - {reason}"
                            )
                    except:
                        pass
        
        # Keep only recent events
        events_info["warning_events"] = sorted(
            events_info["warning_events"], 
            key=lambda x: x["last_seen"], 
            reverse=True
        )[:50]
        
        return dict(events_info)

    def calculate_age(self, timestamp: str) -> str:
        """Calculate age from timestamp"""
        if not timestamp:
            return "Unknown"
        
        try:
            created = datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
            age = datetime.now(created.tzinfo) - created
            
            days = age.days
            hours = age.seconds // 3600
            minutes = (age.seconds % 3600) // 60
            
            if days > 365:
                years = days // 365
                return f"{years}y {days % 365}d"
            elif days > 0:
                return f"{days}d {hours}h"
            elif hours > 0:
                return f"{hours}h {minutes}m"
            else:
                return f"{minutes}m"
        except:
            return "Unknown"

    def generate_html_report(self):
        """Generate HTML report"""
        html_template = """
<!DOCTYPE html>
<html>
<head>
    <title>K8s Cluster Report - {{ timestamp }}</title>
    <style>
        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; 
               margin: 0; padding: 20px; background: #f5f5f5; }
        .container { max-width: 1400px; margin: 0 auto; }
        h1 { color: #2c3e50; border-bottom: 3px solid #3498db; padding-bottom: 10px; }
        h2 { color: #34495e; margin-top: 30px; }
        .health-score { 
            display: inline-block; padding: 10px 20px; border-radius: 5px; 
            font-size: 24px; font-weight: bold; margin: 20px 0;
        }
        .health-excellent { background: #27ae60; color: white; }
        .health-good { background: #2ecc71; color: white; }
        .health-fair { background: #f39c12; color: white; }
        .health-poor { background: #e67e22; color: white; }
        .health-critical { background: #e74c3c; color: white; }
        .stats-grid { 
            display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); 
            gap: 20px; margin: 20px 0; 
        }
        .stat-card { 
            background: white; padding: 20px; border-radius: 8px; 
            box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        .stat-title { color: #7f8c8d; font-size: 14px; margin-bottom: 5px; }
        .stat-value { font-size: 32px; font-weight: bold; color: #2c3e50; }
        .stat-subtitle { color: #95a5a6; font-size: 12px; margin-top: 5px; }
        table { 
            width: 100%; background: white; border-radius: 8px; 
            overflow: hidden; box-shadow: 0 2px 4px rgba(0,0,0,0.1); 
        }
        th { background: #34495e; color: white; padding: 12px; text-align: left; }
        td { padding: 10px; border-bottom: 1px solid #ecf0f1; }
        tr:hover { background: #f8f9fa; }
        .issue { background: #ffebee; color: #c62828; padding: 10px; border-radius: 5px; margin: 5px 0; }
        .warning { background: #fff3e0; color: #ef6c00; padding: 10px; border-radius: 5px; margin: 5px 0; }
        .success { color: #27ae60; }
        .danger { color: #e74c3c; }
        .warning-text { color: #f39c12; }
        .info-box { 
            background: #e3f2fd; border-left: 4px solid #2196f3; 
            padding: 15px; margin: 20px 0; border-radius: 4px; 
        }
    </style>
</head>
<body>
    <div class="container">
        <h1>Kubernetes Cluster Investigation Report</h1>
        <p><strong>Generated:</strong> {{ timestamp }}</p>
        <p><strong>Cluster:</strong> {{ cluster_version }}</p>
        
        <div class="health-score health-{{ health_class }}">
            Health Score: {{ health_score }}/100 ({{ health_status }})
        </div>
        
        <h2>Cluster Overview</h2>
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-title">Nodes</div>
                <div class="stat-value">{{ nodes_total }}</div>
                <div class="stat-subtitle">{{ nodes_ready }} ready, {{ nodes_not_ready }} not ready</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">Namespaces</div>
                <div class="stat-value">{{ namespaces_total }}</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">Pods</div>
                <div class="stat-value">{{ pods_total }}</div>
                <div class="stat-subtitle">{{ pods_running }} running, {{ pods_failed }} failed</div>
            </div>
            <div class="stat-card">
                <div class="stat-title">Deployments</div>
                <div class="stat-value">{{ deployments_total }}</div>
                <div class="stat-subtitle">{{ deployments_healthy }} healthy</div>
            </div>
        </div>
        
        {% if issues %}
        <h2>Critical Issues ({{ issues|length }})</h2>
        {% for issue in issues %}
        <div class="issue">❌ {{ issue }}</div>
        {% endfor %}
        {% endif %}
        
        {% if warnings %}
        <h2>Warnings ({{ warnings|length }})</h2>
        {% for warning in warnings[:20] %}
        <div class="warning">⚠️ {{ warning }}</div>
        {% endfor %}
        {% endif %}
        
        {% if nodes_details %}
        <h2>Node Details</h2>
        <table>
            <tr>
                <th>Name</th>
                <th>Status</th>
                <th>Roles</th>
                <th>Version</th>
                <th>Age</th>
            </tr>
            {% for node in nodes_details %}
            <tr>
                <td>{{ node.name }}</td>
                <td class="{% if node.status == 'Ready' %}success{% else %}danger{% endif %}">
                    {{ node.status }}
                </td>
                <td>{{ node.roles|join(', ') or 'worker' }}</td>
                <td>{{ node.version }}</td>
                <td>{{ node.age }}</td>
            </tr>
            {% endfor %}
        </table>
        {% endif %}
        
        {% if top_cpu_consumers %}
        <h2>Top CPU Consumers</h2>
        <table>
            <tr>
                <th>Namespace</th>
                <th>Pod</th>
                <th>CPU</th>
                <th>Memory</th>
            </tr>
            {% for pod in top_cpu_consumers[:10] %}
            <tr>
                <td>{{ pod.namespace }}</td>
                <td>{{ pod.name }}</td>
                <td>{{ pod.cpu }}</td>
                <td>{{ pod.memory }}</td>
            </tr>
            {% endfor %}
        </table>
        {% endif %}
        
        {% if rbac_errors %}
        <h2>RBAC Limitations</h2>
        <div class="info-box">
            <p>The following resources could not be accessed due to RBAC restrictions:</p>
            <ul>
            {% for error in rbac_errors[:10] %}
                <li>{{ error }}</li>
            {% endfor %}
            </ul>
        </div>
        {% endif %}
    </div>
</body>
</html>
        """
        
        template = Template(html_template)
        
        # Prepare template variables
        health_class = self.cluster_info.get("health_status", "Unknown").lower()
        
        html_content = template.render(
            timestamp=datetime.now().strftime("%Y-%m-%d %H:%M:%S"),
            cluster_version=self.cluster_info.get("version", {}).get("server", "Unknown"),
            health_score=self.health_score,
            health_status=self.cluster_info.get("health_status", "Unknown"),
            health_class=health_class,
            nodes_total=self.cluster_info.get("nodes", {}).get("count", 0),
            nodes_ready=self.cluster_info.get("nodes", {}).get("ready", 0),
            nodes_not_ready=self.cluster_info.get("nodes", {}).get("not_ready", 0),
            namespaces_total=len(self.cluster_info.get("namespaces", [])),
            pods_total=self.cluster_info.get("pods", {}).get("total", 0),
            pods_running=self.cluster_info.get("pods", {}).get("running", 0),
            pods_failed=self.cluster_info.get("pods", {}).get("failed", 0),
            deployments_total=self.cluster_info.get("workloads", {}).get("deployments", {}).get("total", 0),
            deployments_healthy=self.cluster_info.get("workloads", {}).get("deployments", {}).get("healthy", 0),
            issues=self.issues,
            warnings=self.warnings,
            nodes_details=self.cluster_info.get("nodes", {}).get("details", []),
            top_cpu_consumers=self.cluster_info.get("metrics", {}).get("top_consumers", {}).get("cpu", []),
            rbac_errors=self.rbac_errors[:10]
        )
        
        with open("k8s_investigation_report.html", "w") as f:
            f.write(html_content)
        
        console.print("[green]HTML report saved to k8s_investigation_report.html[/green]")

    def print_report(self):
        """Print the investigation report to console"""
        console.print("\n" + "="*80)
        console.print(Panel.fit(f"[bold green]Kubernetes Cluster Investigation Report[/bold green]", 
                               border_style="green"))
        console.print("="*80)
        
        # Health Score
        health_color = "green" if self.health_score >= 75 else "yellow" if self.health_score >= 50 else "red"
        console.print(f"\n[bold {health_color}]Health Score: {self.health_score}/100 ({self.cluster_info.get('health_status', 'Unknown')})[/bold {health_color}]")
        
        # Cluster Info
        if "version" in self.cluster_info:
            console.print("\n[bold]Cluster Version:[/bold]")
            console.print(f"  Client: {self.cluster_info['version']['client']}")
            console.print(f"  Server: {self.cluster_info['version']['server']}")
        
        # Nodes Summary
        if "nodes" in self.cluster_info:
            nodes = self.cluster_info["nodes"]
            console.print(f"\n[bold]Nodes:[/bold] {nodes['count']} total ({nodes['ready']} ready, {nodes['not_ready']} not ready)")
            
            if self.verbose and nodes["details"]:
                table = Table(title="Node Details")
                table.add_column("Name", style="cyan")
                table.add_column("Status", style="green")
                table.add_column("Roles", style="yellow")
                table.add_column("CPU", style="blue")
                table.add_column("Memory", style="blue")
                table.add_column("Age", style="magenta")
                
                for node in nodes["details"][:10]:
                    status_style = "green" if node["status"] == "Ready" else "red"
                    table.add_row(
                        node["name"],
                        Text(node["status"], style=status_style),
                        ", ".join(node["roles"]) or "worker",
                        f"{node['allocatable']['cpu']}/{node['capacity']['cpu']}",
                        node['allocatable']['memory'],
                        node["age"]
                    )
                console.print(table)
        
        # Resource Metrics
        if self.cluster_info.get("metrics", {}).get("available"):
            console.print("\n[bold]Resource Usage:[/bold]")
            if self.cluster_info["metrics"]["node_metrics"]:
                console.print("  Node Metrics:")
                for nm in self.cluster_info["metrics"]["node_metrics"][:5]:
                    cpu_color = "red" if int(nm["cpu_percent"].rstrip('%')) > 80 else "yellow" if int(nm["cpu_percent"].rstrip('%')) > 60 else "green"
                    mem_color = "red" if int(nm["memory_percent"].rstrip('%')) > 85 else "yellow" if int(nm["memory_percent"].rstrip('%')) > 70 else "green"
                    console.print(f"    {nm['name']}: CPU [{cpu_color}]{nm['cpu_percent']}[/{cpu_color}], Memory [{mem_color}]{nm['memory_percent']}[/{mem_color}]")
        
        # Workloads Summary
        if "workloads" in self.cluster_info:
            console.print("\n[bold]Workloads:[/bold]")
            
            if "deployments" in self.cluster_info["workloads"]:
                deps = self.cluster_info["workloads"]["deployments"]
                console.print(f"  Deployments: {deps['total']} total ({deps['healthy']} healthy, {deps['unhealthy']} unhealthy)")
            
            if "daemonsets" in self.cluster_info["workloads"]:
                ds = self.cluster_info["workloads"]["daemonsets"]
                console.print(f"  DaemonSets: {ds['total']} total ({ds['healthy']} healthy, {ds['unhealthy']} unhealthy)")
            
            if "statefulsets" in self.cluster_info["workloads"]:
                sts = self.cluster_info["workloads"]["statefulsets"]
                console.print(f"  StatefulSets: {sts['total']} total ({sts['healthy']} healthy, {sts['unhealthy']} unhealthy)")
            
            if "jobs" in self.cluster_info["workloads"]:
                jobs = self.cluster_info["workloads"]["jobs"]
                console.print(f"  Jobs: {jobs['total']} total ({jobs['succeeded']} succeeded, {jobs['failed']} failed, {jobs['running']} running)")
            
            if "cronjobs" in self.cluster_info["workloads"]:
                cj = self.cluster_info["workloads"]["cronjobs"]
                console.print(f"  CronJobs: {cj['total']} total ({cj['active']} active, {cj['suspended']} suspended)")
        
        # Pods Summary
        if "pods" in self.cluster_info:
            pods = self.cluster_info["pods"]
            console.print(f"\n[bold]Pods:[/bold] {pods['total']} total")
            console.print(f"  Running: {pods['running']}, Pending: {pods['pending']}, Failed: {pods['failed']}")
            console.print(f"  Container Stats: {pods['container_stats']['total']} total "
                        f"({pods['container_stats']['running']} running, "
                        f"{pods['container_stats']['waiting']} waiting)")
            
            if pods["problematic"]:
                console.print("\n  [yellow]Top pods with restart issues:[/yellow]")
                for pod in pods["problematic"][:5]:
                    console.print(f"    {pod['namespace']}/{pod['name']} - Container: {pod['container']} - Restarts: {pod['restarts']}")
        
        # Networking
        if "networking" in self.cluster_info:
            net = self.cluster_info["networking"]
            console.print("\n[bold]Networking:[/bold]")
            console.print(f"  Ingresses: {net['ingresses']['total']}")
            console.print(f"  Network Policies: {net['network_policies']['total']}")
            if net["ingress_classes"]:
                console.print(f"  Ingress Classes: {', '.join([ic['name'] for ic in net['ingress_classes']])}")
        
        # Storage
        if "storage" in self.cluster_info:
            console.print("\n[bold]Storage:[/bold]")
            
            if "storage_classes" in self.cluster_info["storage"]:
                sc = self.cluster_info["storage"]["storage_classes"]
                console.print(f"  StorageClasses: {sc['total']}")
                default_sc = [s["name"] for s in sc["details"] if s.get("is_default")]
                if default_sc:
                    console.print(f"    Default: {default_sc[0]}")
            
            if "pvs" in self.cluster_info["storage"]:
                pvs = self.cluster_info["storage"]["pvs"]
                console.print(f"  PVs: {pvs['total']} (Available: {pvs['available']}, Bound: {pvs['bound']}, Failed: {pvs['failed']})")
            
            if "pvcs" in self.cluster_info["storage"]:
                pvcs = self.cluster_info["storage"]["pvcs"]
                console.print(f"  PVCs: {pvcs['total']} (Bound: {pvcs['bound']}, Pending: {pvcs['pending']})")
        
        # Configuration
        if "configuration" in self.cluster_info:
            config = self.cluster_info["configuration"]
            console.print("\n[bold]Configuration:[/bold]")
            console.print(f"  ConfigMaps: {config['configmaps']['total']}")
            console.print(f"  Secrets: {config['secrets']['total']}")
            if config["secrets"]["by_type"]:
                top_types = sorted(config["secrets"]["by_type"].items(), key=lambda x: x[1], reverse=True)[:3]
                console.print(f"    Top types: {', '.join([f'{t[0]} ({t[1]})' for t in top_types])}")
        
        # Extensions
        if "extensions" in self.cluster_info:
            ext = self.cluster_info["extensions"]
            if ext["crds"]["total"] > 0:
                console.print("\n[bold]Extensions:[/bold]")
                console.print(f"  CRDs: {ext['crds']['total']}")
                if ext["operators"]:
                    console.print(f"  Detected Operators: {', '.join(ext['operators'][:5])}")
        
        # Events Summary
        if "events" in self.cluster_info:
            events = self.cluster_info["events"]
            if events["error_patterns"]:
                console.print("\n[bold]Event Patterns:[/bold]")
                for pattern, count in events["error_patterns"].items():
                    console.print(f"  {pattern}: {count} occurrences")
        
        # Issues and Warnings Summary
        if self.issues:
            console.print(f"\n[bold red]Critical Issues ({len(self.issues)}):[/bold red]")
            for issue in self.issues[:10]:
                console.print(f"  ❌ {issue}")
        
        if self.warnings:
            console.print(f"\n[bold yellow]Warnings ({len(self.warnings)}):[/bold yellow]")
            for warning in self.warnings[:10]:
                console.print(f"  ⚠️  {warning}")
        
        if not self.issues and not self.warnings:
            console.print("\n[bold green]✅ No critical issues found![/bold green]")
        
        # RBAC Errors
        if self.rbac_errors and self.verbose:
            console.print(f"\n[bold]RBAC Limitations ({len(self.rbac_errors)}):[/bold]")
            for error in self.rbac_errors[:5]:
                console.print(f"  🔒 {error}")
        
        console.print("\n" + "="*80)

    def run_investigation(self):
        """Main execution method with progress tracking"""
        with Progress(
            SpinnerColumn(),
            TextColumn("[progress.description]{task.description}"),
            BarColumn(),
            TaskProgressColumn(),
            console=console,
        ) as progress:
            
            # Check kubectl availability
            task = progress.add_task("Checking kubectl availability...", total=1)
            try:
                result = subprocess.run(["kubectl", "version", "--client"], 
                                      capture_output=True, text=True, timeout=5)
                if result.returncode != 0:
                    console.print("[red]kubectl is not available or not configured properly[/red]")
                    sys.exit(1)
            except Exception as e:
                console.print(f"[red]Error checking kubectl: {e}[/red]")
                sys.exit(1)
            progress.update(task, advance=1)
            
            # Run investigations
            investigations = [
                ("Getting cluster information", self.get_cluster_info),
                ("Analyzing resource metrics", self.get_metrics),
                ("Analyzing namespaces", self.get_namespaces),
                ("Analyzing workloads", self.get_workloads),
                ("Analyzing pods", self.get_pods),
                ("Analyzing services", self.get_services),
                ("Analyzing networking", self.get_networking),
                ("Analyzing storage", self.get_storage),
                ("Analyzing configuration", self.get_config_secrets),
                ("Detecting CRDs and operators", self.get_crds_operators),
                ("Analyzing recent events", self.get_events),
            ]
            
            main_task = progress.add_task("Running investigation...", total=len(investigations))
            
            for description, func in investigations:
                progress.update(main_task, description=description)
                try:
                    func()
                except Exception as e:
                    if self.verbose:
                        console.print(f"[yellow]Error during {description}: {e}[/yellow]")
                progress.update(main_task, advance=1)
            
            # Calculate health score
            progress.update(main_task, description="Calculating health score...")
            self.calculate_health_score()
            self.cluster_info["health_score"] = self.health_score

    def save_reports(self):
        """Save reports in multiple formats"""
        # Save YAML report
        with open("k8s_investigation_report.yaml", "w") as f:
            yaml.dump(self.cluster_info, f, default_flow_style=False, sort_keys=False)
        console.print("[green]YAML report saved to k8s_investigation_report.yaml[/green]")
        
        # Save JSON report
        with open("k8s_investigation_report.json", "w") as f:
            json.dump(self.cluster_info, f, indent=2, default=str)
        console.print("[green]JSON report saved to k8s_investigation_report.json[/green]")
        
        # Generate HTML report if requested
        if self.output_format in ["html", "all"]:
            self.generate_html_report()

@click.command()
@click.option('--output', '-o', type=click.Choice(['console', 'html', 'all']), 
              default='console', help='Output format')
@click.option('--verbose', '-v', is_flag=True, help='Verbose output')
@click.option('--namespace', '-n', multiple=True, help='Specific namespace(s) to analyze')
@click.option('--interactive', '-i', is_flag=True, help='Interactive mode for drilling down')
def main(output, verbose, namespace, interactive):
    """Advanced Kubernetes Cluster Investigation Tool"""
    
    console.print(Panel.fit("[bold cyan]Starting Advanced Kubernetes Cluster Investigation[/bold cyan]", 
                           border_style="cyan"))
    
    investigator = K8sClusterInvestigator(
        output_format=output,
        verbose=verbose,
        namespaces=list(namespace) if namespace else None
    )
    
    # Run investigation
    investigator.run_investigation()
    
    # Print console report
    if output in ["console", "all"]:
        investigator.print_report()
    
    # Save reports
    investigator.save_reports()
    
    # Interactive mode
    if interactive:
        console.print("\n[bold cyan]Interactive Mode[/bold cyan]")
        while True:
            choice = Prompt.ask(
                "\nWhat would you like to investigate further?",
                choices=["pods", "nodes", "events", "metrics", "exit"],
                default="exit"
            )
            
            if choice == "exit":
                break
            elif choice == "pods":
                if investigator.cluster_info.get("pods", {}).get("problematic"):
                    console.print("\n[bold]Problematic Pods:[/bold]")
                    for pod in investigator.cluster_info["pods"]["problematic"]:
                        console.print(f"{pod['namespace']}/{pod['name']}: {pod['restarts']} restarts")
                    
                    pod_name = Prompt.ask("\nEnter pod name to investigate (namespace/pod)")
                    if "/" in pod_name:
                        ns, name = pod_name.split("/", 1)
                        logs = subprocess.run(["kubectl", "logs", name, "-n", ns, "--tail=50"], 
                                            capture_output=True, text=True)
                        if logs.returncode == 0:
                            console.print(f"\n[bold]Recent logs for {pod_name}:[/bold]")
                            console.print(logs.stdout)
            elif choice == "nodes":
                for node in investigator.cluster_info.get("nodes", {}).get("details", []):
                    console.print(f"{node['name']}: {node['status']}")
            elif choice == "events":
                if investigator.cluster_info.get("events", {}).get("recent_critical"):
                    console.print("\n[bold]Recent Critical Events:[/bold]")
                    for event in investigator.cluster_info["events"]["recent_critical"][:10]:
                        console.print(f"{event['object']}: {event['reason']} - {event['message'][:100]}")
            elif choice == "metrics":
                if investigator.cluster_info.get("metrics", {}).get("available"):
                    console.print("\n[bold]Top Resource Consumers:[/bold]")
                    console.print("\nCPU:")
                    for pod in investigator.cluster_info["metrics"]["top_consumers"]["cpu"][:5]:
                        console.print(f"  {pod['namespace']}/{pod['name']}: {pod['cpu']}")
                    console.print("\nMemory:")
                    for pod in investigator.cluster_info["metrics"]["top_consumers"]["memory"][:5]:
                        console.print(f"  {pod['namespace']}/{pod['name']}: {pod['memory']}")
    
    console.print("\n[green]Investigation complete![/green]")
    console.print(f"[bold]Health Score: {investigator.health_score}/100[/bold]")

if __name__ == "__main__":
    main()