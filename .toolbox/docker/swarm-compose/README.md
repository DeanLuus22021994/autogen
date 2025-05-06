# Docker Swarm Compose

This directory contains Docker Swarm Compose configurations and deployment tools for running AutoGen in a distributed Docker Swarm environment with GPU acceleration.

## Directory Structure

- **templates/** - Reusable Docker Compose template definitions for different service types
- **scripts/** - PowerShell scripts for managing Swarm deployments and configurations
- **configs/** - Configuration files for Docker Swarm deployments
- **deployments/** - Generated and customized deployment definitions

## Getting Started

### Prerequisites

- Docker Desktop 4.40+ with Swarm mode enabled
- PowerShell 7.0+
- NVIDIA Container Toolkit (for GPU support)
- Docker Model Runner extension (optional, for AI model integration)

### Setup

1. Initialize Docker Swarm mode:

```powershell
# Initialize a new swarm
docker swarm init

# Or specify network interface if needed
docker swarm init --advertise-addr <IP_ADDRESS>
```

2. Open the workspace in VS Code:

```powershell
code c:\Projects\autogen\.toolbox\docker\swarm-compose\swarm-compose.code-workspace
```

3. Generate a deployment template using the "Generate Swarm Compose Template" task

4. Configure your deployment settings in the `configs/` directory

5. Deploy your stack using the "Deploy Swarm Stack" task

## Available Templates

- **gpu-inference.compose.yml** - Template for GPU-accelerated inference services
- **distributed-training.compose.yml** - Template for distributed model training
- **monitoring-stack.compose.yml** - Monitoring stack with Prometheus and Grafana
- **ramdisk-inference.compose.yml** - High-performance inference with RAM disk optimization
- **mistral-gpu.yml** - Highly optimized Mistral NeMo model on NVIDIA GPUs

## Management Scripts

- **Deploy-SwarmStack.ps1** - Deploy a Docker Swarm stack
- **Remove-SwarmStack.ps1** - Remove a Docker Swarm stack
- **New-SwarmComposeTemplate.ps1** - Generate a new Swarm Compose template
- **Watch-SwarmServices.ps1** - Monitor Swarm services in real-time
- **Set-SwarmServiceScale.ps1** - Scale services up or down
- **Initialize-DockerSwarm.ps1** - Initialize a Docker Swarm environment
- **Initialize-MistralGPURunner.ps1** - Set up optimized Mistral NeMo model on NVIDIA GPUs
- **Setup-MistralModelIntegration.ps1** - Setup integration with Docker Model Runner for Mistral
- **Test-MistralModelIntegration.ps1** - Test the Mistral model integration

## Configuration

Edit configuration files in the `configs/` directory to customize deployments. Reference template:

```json
{
  "stackName": "autogen",
  "deploymentTemplate": "../templates/gpu-inference.compose.yml",
  "environment": {
    "NVIDIA_VISIBLE_DEVICES": "all",
    "MODEL_RUNNER_ENDPOINT": "http://localhost:8080/v1"
  },
  "resources": {
    "cpuLimit": "4",
    "memoryLimit": "8G",
    "gpuLimit": "1"
  },
  "scaling": {
    "initialReplicas": 3,
    "maxReplicas": 10,
    "autoScaling": true
  },
  "networks": {
    "overlay": "autogen-network",
    "attachable": true
  }
}
```

## Integration with Docker Model Runner

This toolbox integrates with Docker Model Runner to enable high-performance AI model inference in a distributed environment. Configure the Model Runner endpoint in your deployment configuration to connect to your AI models.

### Setting up Mistral NeMo GPU integration

1. Ensure Docker Desktop 4.40+ is installed with the Model Runner feature enabled
2. Run the "Setup Mistral Model Integration" task in VS Code
3. Test the integration using the "Test Mistral Model Integration" task
4. Deploy the optimized Mistral model using the "Initialize Mistral GPU Runner" task

The Mistral NeMo integration provides:
- Highly optimized GPU inference with quantization options
- Scalable deployment for multiple GPU nodes
- Integrated monitoring and health checks
- Configurable context length and batch size
- Real-time metrics with Prometheus/Grafana

## Examples

See the `templates/` directory for example configurations and the `deployments/` directory for production-ready deployment files.

## Troubleshooting

If you encounter issues with your Swarm deployment:

1. Check service status with `docker service ls`
2. View service logs with `docker service logs <service_name>`
3. Verify node availability with `docker node ls`
4. Ensure GPU drivers are properly installed and accessible
5. Run the "Monitor Swarm Services" task to view real-time metrics
