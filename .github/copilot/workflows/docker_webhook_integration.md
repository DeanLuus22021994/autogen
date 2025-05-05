# Workflow: Docker Model Runner Webhook Integration

## Purpose
Configure event-driven workflows using Docker Model Runner to trigger model inference based on external events.

## Steps

1. **Set Up Docker Model Runner**
   - Follow the standard Docker Model Runner setup steps
   - Ensure the models you need are available with `docker model list`

2. **Configure Webhook Listener**
   - Create a webhook endpoint in your application:

```python
from fastapi import FastAPI, BackgroundTasks, Request
from autogen_extensions.docker.model_client import ModelClient

app = FastAPI()
model_client = ModelClient(model_name="ai/mistral")

@app.post("/webhook/model-inference")
async def model_inference_webhook(request: Request, background_tasks: BackgroundTasks):
    # Get the payload
    payload = await request.json()

    # Extract the prompt and optional parameters
    prompt = payload.get("prompt")
    if not prompt:
        return {"error": "Missing prompt parameter"}

    system_message = payload.get("system_message")
    temperature = payload.get("temperature", 0.7)
    max_tokens = payload.get("max_tokens", 1000)

    # Process the inference in the background
    background_tasks.add_task(
        process_model_inference,
        prompt=prompt,
        system_message=system_message,
        temperature=temperature,
        max_tokens=max_tokens,
        callback_url=payload.get("callback_url")
    )

    return {"status": "processing", "message": "Model inference started"}

async def process_model_inference(prompt, system_message, temperature, max_tokens, callback_url=None):
    try:
        # Get response from model
        response = model_client.complete(
            prompt=prompt,
            system_message=system_message,
            temperature=temperature,
            max_tokens=max_tokens
        )

        result = {"status": "success", "response": response}

        # Send the result to the callback URL if provided
        if callback_url:
            await send_callback(callback_url, result)

        return result
    except Exception as e:
        error_result = {"status": "error", "message": str(e)}
        if callback_url:
            await send_callback(callback_url, error_result)
        return error_result

async def send_callback(url, data):
    # Send the result to the callback URL
    import httpx
    async with httpx.AsyncClient() as client:
        await client.post(url, json=data)
```

3. **Deploy the Webhook Service**
   - Deploy the webhook service with Docker:

```yaml
# docker-compose.yml
version: '3.8'

services:
  webhook-service:
    build: .
    ports:
      - "8000:8000"
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - MODEL_RUNNER_ENDPOINT=http://model-runner.docker.internal/engines/v1/chat/completions
    command: uvicorn main:app --host 0.0.0.0 --port 8000
```

4. **Send Test Webhook Requests**
   - Test the webhook with a sample request:

```bash
curl -X POST http://localhost:8000/webhook/model-inference \
  -H "Content-Type: application/json" \
  -d '{
    "prompt": "Explain Docker Model Runner in simple terms",
    "system_message": "You are a helpful assistant that explains technical concepts simply.",
    "temperature": 0.7,
    "max_tokens": 500,
    "callback_url": "http://requestbin.net/your-request-bin"
  }'
```

5. **Set Up Webhook Triggers**
   - Configure sources that will trigger the webhook:
     - GitHub webhook for repository events
     - Monitoring system alerts
     - User interaction events
     - Scheduled tasks via cron jobs

6. **Implement Rate Limiting and Security**
   - Add authentication to the webhook:

```python
from fastapi import Depends, HTTPException, status
from fastapi.security import APIKeyHeader

API_KEY = "your-secret-api-key"  # Store this securely
api_key_header = APIKeyHeader(name="X-API-Key")

def verify_api_key(api_key: str = Depends(api_key_header)):
    if api_key != API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid API Key"
        )
    return api_key

@app.post("/webhook/model-inference")
async def model_inference_webhook(
    request: Request,
    background_tasks: BackgroundTasks,
    api_key: str = Depends(verify_api_key)
):
    # Existing webhook code...
```

## Inputs Required
- Docker Desktop 4.40+ with Model Runner enabled
- FastAPI and uvicorn installed (`pip install fastapi uvicorn[standard] httpx`)
- The ModelClient implementation from autogen_extensions
- A webhook consumer (service that sends events)
- Optional: A callback receiver for asynchronous responses

## Expected Outputs
- Webhook HTTP endpoint that accepts inference requests
- Background processing of model inference tasks
- Asynchronous callbacks with inference results
- Secured API with authentication

## Advanced Webhook Patterns

### Event Aggregation

Aggregate multiple events before triggering inference:

```python
event_buffer = []
event_lock = asyncio.Lock()

@app.post("/webhook/aggregate")
async def aggregate_events(request: Request):
    event = await request.json()
    async with event_lock:
        event_buffer.append(event)

        # Process if we have enough events or a timeout occurs
        if len(event_buffer) >= 5:  # Process in batches of 5
            events_to_process = event_buffer.copy()
            event_buffer.clear()
            background_tasks.add_task(process_aggregated_events, events_to_process)

    return {"status": "accepted"}

async def process_aggregated_events(events):
    # Combine events into a structured prompt
    combined_prompt = "Process these events:\n\n" + "\n".join(
        [f"Event {i+1}: {event}" for i, event in enumerate(events)]
    )

    # Send to model
    response = model_client.complete(combined_prompt)

    # Process response...
```

### Conditional Webhook Routing

Route to different models based on content:

```python
@app.post("/webhook/router")
async def router_webhook(request: Request, background_tasks: BackgroundTasks):
    payload = await request.json()
    prompt = payload.get("prompt", "")

    # Select model based on content
    if any(keyword in prompt.lower() for keyword in ["code", "function", "program"]):
        model_name = "ai/qwen2-coder"
    elif any(keyword in prompt.lower() for keyword in ["math", "calculate", "equation"]):
        model_name = "ai/mistral-nemo"
    else:
        model_name = "ai/smollm2"

    # Create client with selected model
    client = ModelClient(model_name=model_name)

    # Process with appropriate model...
    background_tasks.add_task(process_with_model, client, prompt, payload.get("callback_url"))

    return {"status": "processing", "model_selected": model_name}
```

## Best Practices
- Implement proper error handling and retries
- Use background tasks for long-running operations
- Add authentication to secure webhook endpoints
- Implement rate limiting to prevent abuse
- Set up monitoring and logging for webhook activity
- Use appropriate status codes in responses
- Validate input data before processing
