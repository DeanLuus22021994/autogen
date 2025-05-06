# Docker Model Runner helper functions
model_pull() {
  docker model pull "$@"
}
model_run() {
  docker model run "$@"
}
model_ls() {
  docker model ls
}

echo ""
echo "🚀 Welcome to AutoGen Enhanced DevContainer with Docker Model Runner integration!"
echo ""
echo "📋 Quick commands:"
echo "  • check-model-runner     - Check Docker Model Runner availability"
echo "  • model-runner-check     - Comprehensive check for Docker Model Runner setup"
echo "  • model_pull MODEL_NAME  - Pull a model from Docker Model Runner"
echo "  • model_run MODEL_NAME   - Run a model from Docker Model Runner"
echo "  • model_ls               - List available models"
echo ""
echo "📋 Available models include:"
echo "  • ai/mistral              - Mistral base model"
echo "  • ai/mistral-nemo         - Mistral NeMo-enhanced model"
echo "  • ai/mxbai-embed-large    - MxbAI embedding model"
echo "  • ai/smollm2              - Smol LM2 model"
echo ""
echo "📋 Volumes and persistence:"
echo "  • Python packages: /workspaces/autogen/python/.venv (persistent)"
echo "  • .NET packages: /workspaces/autogen/dotnet/artifacts (persistent)"
echo "  • Model cache: /opt/autogen/models (persistent)"
echo ""
if [ ! -z "$INVOCATION_ID" ]; then
  # Only run this check on first login to avoid performance impact
  check-model-runner
fi