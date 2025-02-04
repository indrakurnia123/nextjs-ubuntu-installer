#!/bin/bash

set -euo pipefail  # Enable strict mode

# Script configuration
readonly CONFIG_FILE="config.json"
readonly SECRETS_FILE="secrets.json"
readonly LOG_DIR="/var/log"
readonly LOG_FILE="$LOG_DIR/nextjs-deploy.log"
readonly TIMESTAMP=$(date '+%Y%m%d_%H%M%S')
readonly BACKUP_DIR="/var/www/backups"

# Color codes for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Function to log messages with timestamp
log() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local color=""
    
    case $level in
        "INFO") color=$GREEN ;;
        "WARN") color=$YELLOW ;;
        "ERROR") color=$RED ;;
    esac
    
    echo -e "${color}${timestamp} - ${level}: ${message}${NC}" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_exit() {
    log "ERROR" "$1"
    if [ -n "${2:-}" ]; then
        log "ERROR" "Command output: $2"
    fi
    exit 1
}

# Function to check and install dependencies
check_dependency() {
    local cmd=$1
    local package=$2
    local install_cmd=${3:-"sudo apt-get install -y $package"}
    
    if ! command -v "$cmd" &> /dev/null; then
        log "WARN" "$cmd not found. Installing $package..."
        eval "$install_cmd" || error_exit "Failed to install $package"
        log "INFO" "$package installed successfully"
    else
        log "INFO" "$cmd is already installed"
    fi
}

# Function to backup existing deployment
backup_existing_deployment() {
    local project_dir=$1
    if [ -d "$project_dir" ]; then
        local backup_path="$BACKUP_DIR/${PM2_APP_NAME}_${TIMESTAMP}"
        log "INFO" "Creating backup at $backup_path"
        mkdir -p "$BACKUP_DIR"
        cp -r "$project_dir" "$backup_path" || error_exit "Failed to create backup"
    fi
}

# Function to validate JSON configuration
validate_config() {
    local config_file=$1
    if ! jq empty "$config_file" 2>/dev/null; then
        error_exit "Invalid JSON in $config_file"
    fi
}

# Setup logging
setup_logging() {
    sudo mkdir -p "$LOG_DIR"
    sudo touch "$LOG_FILE"
    sudo chmod 644 "$LOG_FILE"
    
    # Rotate logs if they get too large
    if [ -f "$LOG_FILE" ] && [ $(stat -f%z "$LOG_FILE" 2>/dev/null || stat -c%s "$LOG_FILE") -gt 10485760 ]; then
        mv "$LOG_FILE" "$LOG_FILE.old"
        touch "$LOG_FILE"
    fi
}

# Initialize deployment
init_deployment() {
    log "INFO" "Starting deployment process"
    
    # Check required files
    for file in "$CONFIG_FILE" "$SECRETS_FILE"; do
        [ -f "$file" ] || error_exit "$file not found"
        validate_config "$file"
    done
    
    # Load configuration
    GITHUB_REPO_URL=$(jq -r '.github.repository_url' "$CONFIG_FILE")
    GITHUB_BRANCH=$(jq -r '.github.branch' "$CONFIG_FILE")
    NODE_VERSION=$(jq -r '.node.required_version' "$CONFIG_FILE")
    PM2_APP_NAME=$(jq -r '.pm2.app_name' "$CONFIG_FILE")
    PROJECT_DIR=$(jq -r '.project.directory' "$CONFIG_FILE")
    
    # Validate required variables
    [[ -n "$GITHUB_REPO_URL" ]] || error_exit "GitHub repository URL not configured"
    [[ -n "$GITHUB_BRANCH" ]] || error_exit "GitHub branch not configured"
    [[ -n "$NODE_VERSION" ]] || error_exit "Node.js version not configured"
    [[ -n "$PM2_APP_NAME" ]] || error_exit "PM2 app name not configured"
    [[ -n "$PROJECT_DIR" ]] || error_exit "Project directory not configured"
}

# Install system dependencies
install_dependencies() {
    log "INFO" "Installing system dependencies..."
    
    # Update package list
    sudo apt-get update || error_exit "Failed to update package list"
    
    # Check and install required dependencies
    check_dependency "jq" "jq"
    check_dependency "git" "git"
    check_dependency "curl" "curl"
    
    # Install Node.js if not present or version mismatch
    if ! command -v node &> /dev/null || ! node --version | grep -q "$NODE_VERSION"; then
        log "INFO" "Installing Node.js $NODE_VERSION..."
        curl -fsSL "https://deb.nodesource.com/setup_${NODE_VERSION}.x" | sudo -E bash - || error_exit "Failed to setup Node.js repository"
        sudo apt-get install -y nodejs || error_exit "Failed to install Node.js"
    fi
    
    # Install PM2 globally
    check_dependency "pm2" "pm2" "sudo npm install -g pm2"
}

# Deploy application
deploy_application() {
    log "INFO" "Starting application deployment..."
    
    # Backup existing deployment
    backup_existing_deployment "$PROJECT_DIR"
    
    # Prepare project directory
    sudo rm -rf "$PROJECT_DIR"
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown -R $(whoami):$(whoami) "$PROJECT_DIR"
    
    # Clone repository
    git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO_URL" "$PROJECT_DIR" || error_exit "Failed to clone repository"
    cd "$PROJECT_DIR" || error_exit "Failed to navigate to project directory"
    
    # Install dependencies and build
    log "INFO" "Installing project dependencies..."
    if [ -f "package-lock.json" ]; then
        npm ci || error_exit "Failed to install dependencies"
    else
        npm install || error_exit "Failed to install dependencies"
    fi
    
    log "INFO" "Building project..."
    npm run build || error_exit "Failed to build project"
    
    # Update PM2 process
    log "INFO" "Updating PM2 process..."
    pm2 delete "$PM2_APP_NAME" 2>/dev/null || true
    pm2 start npm --name "$PM2_APP_NAME" -- start || error_exit "Failed to start PM2 process"
    pm2 save || error_exit "Failed to save PM2 process list"
    
    # Setup PM2 startup
    pm2 startup systemd || error_exit "Failed to setup PM2 startup"
    sudo env PATH="$PATH" pm2 startup systemd -u $(whoami) --hp "$HOME"
}

# Main execution
main() {
    setup_logging
    init_deployment
    install_dependencies
    deploy_application
    log "INFO" "Deployment completed successfully!"
}

# Execute main function
main "$@"