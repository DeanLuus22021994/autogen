#!/bin/bash
# Sidecar Container Management Script
# This script manages the lifecycle of the development sidecar containers

set -e

# Define base directory
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_COMPOSE_FILE="$BASE_DIR/docker-compose.yml"

# Action to perform
ACTION=""
SERVICE=""
VERBOSE=false
DETACHED=true
FOLLOW_LOGS=false

function show_help {
  echo "AutoGen Sidecar Container Manager"
  echo "--------------------------------"
  echo "Usage: ./manage-sidecars.sh [options] <action> [service]"
  echo ""
  echo "Actions:"
  echo "  start       Start sidecar containers"
  echo "  stop        Stop sidecar containers"
  echo "  restart     Restart sidecar containers"
  echo "  status      Show status of sidecar containers"
  echo "  logs        Show logs from sidecar containers"
  echo "  build       Build sidecar container images"
  echo "  exec        Execute command in a sidecar container"
  echo "  help        Show this help message"
  echo ""
  echo "Services (optional, default is all):"
  echo "  markdown-lint   Markdown linting sidecar"
  echo "  build-cache     Build cache sidecar"
  echo "  build-tools     Build tools sidecar"
  echo ""
  echo "Options:"
  echo "  -v, --verbose   Show verbose output"
  echo "  -f, --foreground  Run in foreground (not detached) for start action"
  echo "  -l, --logs      Follow logs after starting containers"
  echo "  -h, --help      Show this help message"
  echo ""
  echo "Examples:"
  echo "  ./manage-sidecars.sh start                   # Start all sidecar containers"
  echo "  ./manage-sidecars.sh start markdown-lint     # Start only the markdown-lint container"
  echo "  ./manage-sidecars.sh stop                    # Stop all sidecar containers"
  echo "  ./manage-sidecars.sh logs build-tools        # Show logs for the build-tools container"
  echo "  ./manage-sidecars.sh exec build-tools bash   # Run bash in the build-tools container"
  echo ""
}

# Function to check if Docker Compose is available
function check_docker_compose {
  if ! command -v docker-compose &> /dev/null && ! command -v docker compose &> /dev/null; then
    echo "Error: Docker Compose is not installed or not in PATH"
    echo "Please install Docker Compose or make sure it's in your PATH"
    exit 1
  fi
}

# Function to run Docker Compose commands
function docker_compose_cmd {
  # Check if we should use 'docker compose' or 'docker-compose'
  if command -v docker compose &> /dev/null; then
    if [ "$VERBOSE" = true ]; then
      docker compose -f "$DOCKER_COMPOSE_FILE" "$@"
    else
      docker compose -f "$DOCKER_COMPOSE_FILE" "$@" > /dev/null
    fi
  else
    if [ "$VERBOSE" = true ]; then
      docker-compose -f "$DOCKER_COMPOSE_FILE" "$@"
    else
      docker-compose -f "$DOCKER_COMPOSE_FILE" "$@" > /dev/null
    fi
  fi
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    start|stop|restart|status|logs|build|exec|help)
      ACTION="$1"
      shift
      ;;
    markdown-lint|build-cache|build-tools)
      SERVICE="$1"
      shift
      ;;
    -v|--verbose)
      VERBOSE=true
      shift
      ;;
    -f|--foreground)
      DETACHED=false
      shift
      ;;
    -l|--logs)
      FOLLOW_LOGS=true
      shift
      ;;
    -h|--help)
      show_help
      exit 0
      ;;
    *)
      # If it's not a recognized action or option, it's part of a command to exec
      if [ "$ACTION" = "exec" ]; then
        EXEC_CMD=("$@")
        break
      else
        echo "Unknown option or action: $1"
        show_help
        exit 1
      fi
      ;;
  esac
done

# Show help if no action specified
if [ -z "$ACTION" ] || [ "$ACTION" = "help" ]; then
  show_help
  exit 0
fi

# Check if Docker Compose is installed
check_docker_compose

# Execute the requested action
case "$ACTION" in
  start)
    echo "Starting sidecar containers..."
    if [ -n "$SERVICE" ]; then
      echo "Starting $SERVICE..."
      if [ "$DETACHED" = true ]; then
        docker_compose_cmd up -d "$SERVICE"
      else
        docker_compose_cmd up "$SERVICE"
      fi
    else
      if [ "$DETACHED" = true ]; then
        docker_compose_cmd up -d
      else
        docker_compose_cmd up
      fi
    fi

    if [ "$DETACHED" = true ] && [ "$FOLLOW_LOGS" = true ]; then
      if [ -n "$SERVICE" ]; then
        docker_compose_cmd logs -f "$SERVICE"
      else
        docker_compose_cmd logs -f
      fi
    fi

    echo "✅ Sidecar containers started"
    ;;

  stop)
    echo "Stopping sidecar containers..."
    if [ -n "$SERVICE" ]; then
      docker_compose_cmd stop "$SERVICE"
      echo "✅ $SERVICE stopped"
    else
      docker_compose_cmd stop
      echo "✅ All sidecar containers stopped"
    fi
    ;;

  restart)
    echo "Restarting sidecar containers..."
    if [ -n "$SERVICE" ]; then
      docker_compose_cmd restart "$SERVICE"
      echo "✅ $SERVICE restarted"
    else
      docker_compose_cmd restart
      echo "✅ All sidecar containers restarted"
    fi

    if [ "$FOLLOW_LOGS" = true ]; then
      if [ -n "$SERVICE" ]; then
        docker_compose_cmd logs -f "$SERVICE"
      else
        docker_compose_cmd logs -f
      fi
    fi
    ;;

  status)
    echo "Sidecar container status:"
    docker_compose_cmd ps
    ;;

  logs)
    if [ -n "$SERVICE" ]; then
      echo "Showing logs for $SERVICE:"
      docker_compose_cmd logs -f "$SERVICE"
    else
      echo "Showing logs for all sidecar containers:"
      docker_compose_cmd logs -f
    fi
    ;;

  build)
    echo "Building sidecar container images..."
    if [ -n "$SERVICE" ]; then
      docker_compose_cmd build "$SERVICE"
      echo "✅ $SERVICE image built"
    else
      docker_compose_cmd build
      echo "✅ All sidecar container images built"
    fi
    ;;

  exec)
    if [ -z "$SERVICE" ]; then
      echo "Error: Service name is required for exec action"
      show_help
      exit 1
    fi

    if [ ${#EXEC_CMD[@]} -eq 0 ]; then
      echo "Error: Command is required for exec action"
      show_help
      exit 1
    fi

    echo "Executing command in $SERVICE container:"
    echo "  ${EXEC_CMD[*]}"
    docker_compose_cmd exec "$SERVICE" "${EXEC_CMD[@]}"
    ;;

  *)
    echo "Unknown action: $ACTION"
    show_help
    exit 1
    ;;
esac

exit 0
