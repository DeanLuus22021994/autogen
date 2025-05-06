# New-SwarmComposeTemplate.ps1
<#
.SYNOPSIS
    Generates a new Docker Swarm Compose template.

.DESCRIPTION
    This script generates a Docker Swarm Compose template based on predefined templates
    or from scratch, allowing for customization of services, networks, and volumes.

.PARAMETER TemplateName
    The name of the template to generate. Can be one of the predefined templates or 'custom'.

.PARAMETER OutputPath
    The path where the generated template will be saved.

.PARAMETER StackName
    Optional. The name of the stack to use in the template. Default is 'autogen'.

.PARAMETER CustomSettings
    Optional. Path to a JSON file with custom settings to apply to the template.

.EXAMPLE
    .\New-SwarmComposeTemplate.ps1 -TemplateName gpu-inference -OutputPath ..\deployments\my-inference.yml

.EXAMPLE
    .\New-SwarmComposeTemplate.ps1 -TemplateName custom -OutputPath ..\deployments\custom-stack.yml -StackName ml-platform -CustomSettings ..\configs\custom-settings.json
#>
[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [ValidateSet('gpu-inference', 'distributed-training', 'monitoring-stack', 'ramdisk-inference', 'custom')]
    [string]$TemplateName,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [string]$StackName = 'autogen',

    [Parameter(Mandatory = $false)]
    [string]$CustomSettings
)

function Get-TemplateContent {
    param (
        [string]$TemplateName,
        [string]$StackName
    )

    $templateContent = ""

    switch ($TemplateName) {
        'gpu-inference' {
            $templateContent = @"
# GPU Inference Stack for $StackName
# Generated: $(Get-Date)
# This template is optimized for GPU-accelerated inference with Docker Swarm
version: '3.8'

services:
  inference:
    image: \${INFERENCE_IMAGE:-nvidia/cuda:12.0.1-base-ubuntu22.04}
    deploy:
      replicas: \${INFERENCE_REPLICAS:-3}
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: \${GPU_COUNT:-1}
              capabilities: [gpu]
      restart_policy:
        condition: on-failure
        max_attempts: 3
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - MODEL_PATH=/models
      - LOG_LEVEL=INFO
    volumes:
      - models:/models
      - inference_cache:/cache
    networks:
      - autogen-network

  api:
    image: \${API_IMAGE:-model-api:latest}
    deploy:
      replicas: \${API_REPLICAS:-2}
      resources:
        limits:
          cpus: '2'
          memory: 4G
      restart_policy:
        condition: any
        max_attempts: 5
      update_config:
        parallelism: 1
        delay: 5s
        order: start-first
    ports:
      - "\${API_PORT:-8080}:8080"
    environment:
      - INFERENCE_ENDPOINT=http://inference:9000
      - AUTH_ENABLED=\${AUTH_ENABLED:-false}
    networks:
      - autogen-network
    depends_on:
      - inference

networks:
  autogen-network:
    driver: overlay
    attachable: true

volumes:
  models:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: \${MODEL_DIR:-/path/to/models}
  inference_cache:
    driver: local
"@
        }
        'distributed-training' {
            $templateContent = @"
# Distributed Training Stack for $StackName
# Generated: $(Get-Date)
# This template is optimized for distributed model training with Docker Swarm
version: '3.8'

services:
  master:
    image: \${TRAINING_IMAGE:-pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime}
    command: ["python", "-m", "torch.distributed.run", "--nproc_per_node=1", "--nnodes=\${WORKER_COUNT:-2}", "--node_rank=0", "--master_addr=master", "--master_port=29500", "/app/train.py"]
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: \${GPU_COUNT:-1}
              capabilities: [gpu]
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - TRAINING_CONFIG=/app/config.yaml
    volumes:
      - training_data:/data
      - checkpoints:/checkpoints
      - ./scripts:/app
    networks:
      - training-network

  worker:
    image: \${TRAINING_IMAGE:-pytorch/pytorch:2.0.1-cuda11.7-cudnn8-runtime}
    command: ["python", "-m", "torch.distributed.run", "--nproc_per_node=1", "--nnodes=\${WORKER_COUNT:-2}", "--node_rank={{.Task.Slot}}", "--master_addr=master", "--master_port=29500", "/app/train.py"]
    deploy:
      replicas: \${WORKER_COUNT:-2}
      placement:
        constraints:
          - node.role == worker
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: \${GPU_COUNT:-1}
              capabilities: [gpu]
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - TRAINING_CONFIG=/app/config.yaml
    volumes:
      - training_data:/data
      - checkpoints:/checkpoints
      - ./scripts:/app
    networks:
      - training-network
    depends_on:
      - master

  tensorboard:
    image: \${TENSORBOARD_IMAGE:-tensorflow/tensorflow:2.12.0}
    command: ["tensorboard", "--logdir=/logs", "--bind_all"]
    deploy:
      replicas: 1
      placement:
        constraints:
          - node.role == manager
    ports:
      - "\${TENSORBOARD_PORT:-6006}:6006"
    volumes:
      - checkpoints:/logs
    networks:
      - training-network

networks:
  training-network:
    driver: overlay
    attachable: true

volumes:
  training_data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: \${DATA_DIR:-/path/to/data}
  checkpoints:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: \${CHECKPOINT_DIR:-/path/to/checkpoints}
"@
        }
        'monitoring-stack' {
            $templateContent = @"
# Monitoring Stack for $StackName
# Generated: $(Get-Date)
# This template sets up Prometheus, Grafana, and Node Exporter for monitoring
version: '3.8'

services:
  prometheus:
    image: \${PROMETHEUS_IMAGE:-prom/prometheus:v2.45.0}
    command:
      - --config.file=/etc/prometheus/prometheus.yml
      - --storage.tsdb.path=/prometheus
      - --web.console.libraries=/usr/share/prometheus/console_libraries
      - --web.console.templates=/usr/share/prometheus/consoles
      - --web.enable-lifecycle
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: '1'
          memory: 2G
    ports:
      - "\${PROMETHEUS_PORT:-9090}:9090"
    volumes:
      - ./configs/prometheus.yml:/etc/prometheus/prometheus.yml
      - prometheus_data:/prometheus
    networks:
      - monitoring-network

  grafana:
    image: \${GRAFANA_IMAGE:-grafana/grafana:10.0.3}
    deploy:
      placement:
        constraints:
          - node.role == manager
      resources:
        limits:
          cpus: '1'
          memory: 1G
    ports:
      - "\${GRAFANA_PORT:-3000}:3000"
    environment:
      - GF_SECURITY_ADMIN_USER=\${GRAFANA_USER:-admin}
      - GF_SECURITY_ADMIN_PASSWORD=\${GRAFANA_PASSWORD:-admin}
      - GF_USERS_ALLOW_SIGN_UP=false
    volumes:
      - grafana_data:/var/lib/grafana
    networks:
      - monitoring-network
    depends_on:
      - prometheus

  node-exporter:
    image: \${NODE_EXPORTER_IMAGE:-prom/node-exporter:v1.6.0}
    deploy:
      mode: global
      resources:
        limits:
          cpus: '0.2'
          memory: 256M
    command:
      - --path.procfs=/host/proc
      - --path.sysfs=/host/sys
      - --collector.filesystem.ignored-mount-points=^/(sys|proc|dev|host|etc)($$|/)
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - monitoring-network

  cadvisor:
    image: \${CADVISOR_IMAGE:-gcr.io/cadvisor/cadvisor:v0.47.2}
    deploy:
      mode: global
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
    networks:
      - monitoring-network

  dcgm-exporter:
    image: \${DCGM_EXPORTER_IMAGE:-nvidia/dcgm-exporter:3.1.7-3.1.4-ubuntu20.04}
    deploy:
      mode: global
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    command: -f /etc/dcgm-exporter/default-counters.csv
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
    networks:
      - monitoring-network

networks:
  monitoring-network:
    driver: overlay
    attachable: true

volumes:
  prometheus_data:
    driver: local
  grafana_data:
    driver: local
"@
        }
        'ramdisk-inference' {
            $templateContent = @"
# High-Performance RAM Disk Inference Stack for $StackName
# Generated: $(Get-Date)
# This template is optimized for high-speed inference using RAM disk and GPU acceleration
version: '3.8'

services:
  ramdisk-setup:
    image: \${INIT_IMAGE:-ubuntu:22.04}
    command: >
      bash -c "mkdir -p /ramdisk/models &&
               cp -r /models/* /ramdisk/models/ &&
               echo 'RAM disk populated with models' &&
               tail -f /dev/null"
    deploy:
      replicas: 1
      restart_policy:
        condition: none
      placement:
        constraints:
          - node.role == manager
    volumes:
      - models:/models
      - ramdisk:/ramdisk
    networks:
      - inference-network

  inference:
    image: \${INFERENCE_IMAGE:-nvidia/cuda:12.0.1-base-ubuntu22.04}
    deploy:
      replicas: \${INFERENCE_REPLICAS:-3}
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: \${GPU_COUNT:-1}
              capabilities: [gpu]
      restart_policy:
        condition: on-failure
      update_config:
        parallelism: 1
        delay: 10s
        order: start-first
    environment:
      - NVIDIA_VISIBLE_DEVICES=all
      - MODEL_PATH=/ramdisk/models
      - USE_RAMDISK=true
      - MAX_BATCH_SIZE=\${MAX_BATCH_SIZE:-32}
      - INFERENCE_PRECISION=\${INFERENCE_PRECISION:-fp16}
    volumes:
      - ramdisk:/ramdisk
    networks:
      - inference-network
    depends_on:
      - ramdisk-setup

  api-gateway:
    image: \${API_IMAGE:-nginx:alpine}
    deploy:
      replicas: \${API_REPLICAS:-2}
      resources:
        limits:
          cpus: '1'
          memory: 1G
      restart_policy:
        condition: any
    ports:
      - "\${API_PORT:-8080}:80"
    volumes:
      - ./configs/nginx.conf:/etc/nginx/conf.d/default.conf
    networks:
      - inference-network
    depends_on:
      - inference

networks:
  inference-network:
    driver: overlay
    attachable: true

volumes:
  models:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: \${MODEL_DIR:-/path/to/models}
  ramdisk:
    driver: local
    driver_opts:
      type: tmpfs
      device: tmpfs
      o: "size=\${RAMDISK_SIZE:-16G},uid=1000"
"@
        }
        'custom' {
            $templateContent = @"
# Custom Stack for $StackName
# Generated: $(Get-Date)
# Edit this template according to your requirements
version: '3.8'

services:
  # Define your services here
  app:
    image: \${APP_IMAGE:-alpine:latest}
    command: ["echo", "Custom stack deployed successfully"]
    deploy:
      replicas: \${REPLICAS:-1}
      resources:
        limits:
          cpus: '0.5'
          memory: 512M
      restart_policy:
        condition: on-failure
    networks:
      - app-network

networks:
  app-network:
    driver: overlay
    attachable: true

# Define volumes if needed
# volumes:
#   data:
#     driver: local
"@
        }
    }

    return $templateContent
}

function Apply-CustomSettings {
    param (
        [string]$TemplateContent,
        [string]$CustomSettingsPath
    )

    if (-not (Test-Path $CustomSettingsPath)) {
        Write-Error "Custom settings file not found: $CustomSettingsPath"
        exit 1
    }

    try {
        $customSettings = Get-Content -Path $CustomSettingsPath -Raw | ConvertFrom-Json

        # Apply custom settings based on properties in the JSON file
        if ($customSettings.PSObject.Properties.Name -contains "serviceReplicas") {
            foreach ($service in $customSettings.serviceReplicas.PSObject.Properties) {
                $regex = "(\s+$($service.Name):.*[\r\n]+\s+deploy:[\r\n]+\s+replicas:)\s+\\\$\{[^\}]+\}|-\d+"
                $replacement = "`$1 $($service.Value)"
                $TemplateContent = $TemplateContent -replace $regex, $replacement
            }
        }

        if ($customSettings.PSObject.Properties.Name -contains "ports") {
            foreach ($port in $customSettings.ports.PSObject.Properties) {
                $regex = "(\s+- "")\\$\{$($port.Name):-\d+\}(:\d+"")"
                $replacement = "`$1$($port.Value)`$2"
                $TemplateContent = $TemplateContent -replace $regex, $replacement
            }
        }

        if ($customSettings.PSObject.Properties.Name -contains "images") {
            foreach ($image in $customSettings.images.PSObject.Properties) {
                $regex = "(\s+image: )\\$\{$($image.Name):-[^\}]+\}"
                $replacement = "`$1$($image.Value)"
                $TemplateContent = $TemplateContent -replace $regex, $replacement
            }
        }

        if ($customSettings.PSObject.Properties.Name -contains "environment") {
            foreach ($env in $customSettings.environment) {
                # Find the service section
                $serviceRegex = "(\s+$($env.service):(?:(?!\s+\w+:).)*)"
                if ($TemplateContent -match $serviceRegex) {
                    $serviceSection = $Matches[1]

                    # Check if environment section exists
                    if ($serviceSection -match "\s+environment:") {
                        # Add to existing environment section
                        $envRegex = "(\s+environment:(?:(?!\s+\w+:).)*))"
                        $envSection = ""
                        if ($serviceSection -match $envRegex) {
                            $envSection = $Matches[1]
                            $newEnvLine = "      - $($env.name)=$($env.value)"
                            $replacement = "$envSection$newEnvLine`n"
                            $TemplateContent = $TemplateContent -replace $envRegex, $replacement
                        }
                    } else {
                        # Add new environment section
                        $replacement = "$serviceSection`n    environment:`n      - $($env.name)=$($env.value)"
                        $TemplateContent = $TemplateContent -replace $serviceRegex, $replacement
                    }
                }
            }
        }

        # Add custom networks if specified
        if ($customSettings.PSObject.Properties.Name -contains "networks") {
            $networksSection = "`nnetworks:"
            foreach ($network in $customSettings.networks) {
                $networksSection += "`n  $($network.name):`n    driver: $($network.driver)"
                if ($network.PSObject.Properties.Name -contains "attachable" -and $network.attachable) {
                    $networksSection += "`n    attachable: true"
                }
                if ($network.PSObject.Properties.Name -contains "options") {
                    $networksSection += "`n    driver_opts:"
                    foreach ($option in $network.options.PSObject.Properties) {
                        $networksSection += "`n      $($option.Name): $($option.Value)"
                    }
                }
            }
            # Add or replace existing networks section
            if ($TemplateContent -match "networks:(.|\n)*$") {
                $TemplateContent = $TemplateContent -replace "networks:(.|\n)*$", $networksSection
            } else {
                $TemplateContent += "`n$networksSection"
            }
        }
    } catch {
        Write-Error "Error applying custom settings: $_"
        exit 1
    }

    return $TemplateContent
}

# Main script
try {
    $templateContent = Get-TemplateContent -TemplateName $TemplateName -StackName $StackName

    # Apply custom settings if provided
    if ($CustomSettings -and (Test-Path $CustomSettings)) {
        $templateContent = Apply-CustomSettings -TemplateContent $templateContent -CustomSettingsPath $CustomSettings
    }

    # Create parent directory if it doesn't exist
    $outputDir = Split-Path -Parent $OutputPath
    if (-not (Test-Path $outputDir)) {
        New-Item -Path $outputDir -ItemType Directory -Force | Out-Null
    }

    # Save the template
    $templateContent | Out-File -FilePath $OutputPath -Encoding utf8 -Force

    Write-Host "Template generated successfully: $OutputPath" -ForegroundColor Green
    Write-Host "You can now edit this template or deploy it directly" -ForegroundColor Cyan
} catch {
    Write-Error "Error generating template: $_"
    exit 1
}
