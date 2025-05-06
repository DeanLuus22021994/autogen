# Workflow: Docker Model Integration

## Purpose
Configure and use Docker Model Runner for local development and testing without relying on external API calls.

## Steps

1. **Set Up Docker Model Runner**
   - Ensure Docker Desktop 4.40+ is installed
   - Enable Docker Model Runner in Docker Desktop settings:
     - Navigate to Settings > Features in development > Beta
     - Check "Enable Docker Model Runner"
     - Apply and restart Docker Desktop
2. **Pull Required Models**
   - Pull models using the Docker Model CLI:
     ```bash
     docker model pull ai/mistral-nemo
     docker model pull ai/mxbai-embed-large
     docker model pull ai/smollm2
     docker model pull ai/mistral
     ```
   - Verify models are available:
     ```bash
     docker model list
     ```
3. **Use Models in Development**
   - **Interactive CLI usage**:
     ```bash
     docker model run ai/smollm2
     ```
   - **One-shot prompt**:
     ```bash
     docker model run ai/smollm2 "Write a function to calculate Fibonacci numbers"
     ```
   - **Programmatic API access from within containers**:
     ```bash
     curl http://model-runner.docker.internal/engines/v1/chat/completions \
       -H "Content-Type: application/json" \
       -d '{
         "model": "ai/smollm2",
         "messages": [
           {"role": "system", "content": "You are a helpful assistant."},
           {"role": "user", "content": "Write a function to calculate Fibonacci numbers"}
         ]
       }'
     ```

4. **Integrate with AutoGen**
   - Create configuration connecting AutoGen to local model endpoints
   - Use Docker Model Runner API endpoints for inference
   - Implement fallback to remote APIs when local models are unavailable
5. **Clean Up Resources**
   - Remove models when no longer needed:
     ```bash
     docker model rm ai/model-name
     ```
   - Disable Docker Model Runner if not in use

## Inputs Required
- Docker Desktop 4.40+
- GPU specifications from `.config/host/gpu_settings.xml`
- Model configurations from `.config/host/model_settings.xml`

## Expected Outputs
- Local AI model endpoints
- Reduced dependency on external API calls
- Faster development cycles
- Improved privacy and control over model usage
