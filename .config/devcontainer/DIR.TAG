#INDEX: C:/Projects/autogen/.config/devcontainer
#GUID: 7c5cfb40-a273-4252-8674-5245bc4fa1fc
#TODO:
  - Complete XML migration for all config files [DONE]
  - Remove legacy .config and .txt files [DONE]
  - Ensure .gitkeep files in all config subdirectories [DONE]
  - Standardize DIR.TAG format for machine readability [DONE]
  - Document Docker image references for local development [DONE]
  - Automate DIR.TAG propagation and update [OUTSTANDING]
  - Migrate from Ollama to Docker Model Runner [OUTSTANDING]

status: PARTIALLY_COMPLETE
updated: 2025-05-06T04:02:50Z
description: |
  All configuration files are now XML. DIR.TAG and .gitkeep files are present.
  Docker Model Runner is documented for AI model integration.

  Refer to Docker Model Runner documentation below:

  # Docker Model Integration

  The following Docker images are used via Docker Model Runner:
  - ai/mistral-nemo - https://hub.docker.com/r/ai/mistral-nemo
  - ai/mxbai-embed-large - https://hub.docker.com/r/ai/mxbai-embed-large
  - ai/smollm2 - https://hub.docker.com/r/ai/smollm2
  - ai/mistral - https://hub.docker.com/r/ai/mistral

  ## Usage
  1. Ensure Docker Desktop 4.40+ is installed
  2. Enable Docker Model Runner in Docker Desktop settings
