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

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check system package manager
check_package_manager() {
    if command_exists apt-get; then
        echo "apt"
    elif command_exists yum; then
        echo "yum"
    elif command_exists dnf; then
        echo "dnf"
    else
        error_exit "No supported package manager found"
    fi
}

# Function to install system dependencies based on package manager
install_system_package() {
    local package=$1
    local package_manager=$(check_package_manager)
    
    log "INFO" "Installing $package using $package_manager..."
    case $package_manager in
        "apt")
            sudo apt-get install -y "$package" || error_exit "Failed to install $package"
            ;;
        "yum")
            sudo yum install -y "$package" || error_exit "Failed to install $package"
            ;;
        "dnf")
            sudo dnf install -y "$package" || error_exit "Failed to install $package"
            ;;
    esac
}

# Function to check and install core dependencies
check_core_dependencies() {
    log "INFO" "Checking and installing core dependencies..."
    
    # Update package lists if using apt
    if [ "$(check_package_manager)" = "apt" ]; then
        log "INFO" "Updating package lists..."
        sudo apt-get update || error_exit "Failed to update package lists"
    fi
    
    # Array of required system packages and their corresponding commands
    declare -A dependencies=(
        ["curl"]="curl"
        ["git"]="git"
        ["jq"]="jq"
        ["build-essential"]="gcc"
        ["python"]="python3"
        ["wget"]="wget"
    )
    
    # Check and install each dependency
    for package in "${!dependencies[@]}"; do
        if ! command_exists "${dependencies[$package]}"; then
            log "WARN" "${dependencies[$package]} not found. Installing $package..."
            install_system_package "$package"
            log "INFO" "$package installed successfully"
        else
            log "INFO" "${dependencies[$package]} is already installed"
        fi
    done
}

# Function to check and install Node.js and npm
check_nodejs_dependencies() {
    log "INFO" "Checking Node.js and npm..."
    
    # Load Node.js version from config
    local required_node_version
    required_node_version=$(jq -r '.node.required_version' "$CONFIG_FILE")
    
    # Check if Node.js is installed
    if ! command_exists node; then
        log "WARN" "Node.js not found. Installing version $required_node_version..."
        curl -fsSL "https://deb.nodesource.com/setup_${required_node_version}.x" | sudo -E bash - || error_exit "Failed to setup Node.js repository"
        install_system_package "nodejs"
    else
        local current_version
        current_version=$(node -v | cut -d'v' -f2)
        log "INFO" "Node.js version $current_version is installed"
        
        # Check if version matches requirement
        if [[ ! "$current_version" =~ ^"$required_node_version" ]]; then
            log "WARN" "Node.js version mismatch. Updating to version $required_node_version..."
            curl -fsSL "https://deb.nodesource.com/setup_${required_node_version}.x" | sudo -E bash - || error_exit "Failed to setup Node.js repository"
            install_system_package "nodejs"
        fi
    fi
    
    # Check npm installation
    if ! command_exists npm; then
        log "WARN" "npm not found. Installing..."
        install_system_package "npm"
    else
        log "INFO" "npm is already installed"
    fi
}

# Function to check and install PM2
check_pm2_dependency() {
    log "INFO" "Checking PM2..."
    
    if ! command_exists pm2; then
        log "WARN" "PM2 not found. Installing..."
        sudo npm install -g pm2 || error_exit "Failed to install PM2"
        log "INFO" "PM2 installed successfully"
    else
        log "INFO" "PM2 is already installed"
    fi
}

# Function to check all dependencies
check_all_dependencies() {
    log "INFO" "Starting dependency checks..."
    
    # Check core system dependencies
    check_core_dependencies
    
    # Check Node.js and npm
    check_nodejs_dependencies
    
    # Check PM2
    check_pm2_dependency
    
    log "INFO" "All dependencies checked and installed successfully"
}

# Function to setup logging
setup_logging() {
    log "INFO" "Setting up logging..."
    mkdir -p "$LOG_DIR" || error_exit "Failed to create log directory"
    touch "$LOG_FILE" || error_exit "Failed to create log file"
}

# Function to validate configuration files
validate_config_files() {
    log "INFO" "Validating configuration files..."
    if [ ! -f "$CONFIG_FILE" ]; then
        error_exit "Configuration file $CONFIG_FILE not found"
    fi
    if [ ! -f "$SECRETS_FILE" ]; then
        error_exit "Secrets file $SECRETS_FILE not found"
    fi
}

# Function to initialize deployment
init_deployment() {
    log "INFO" "Initializing deployment..."
    
    # Load project directory from config
    local github_repo_url
    github_repo_url=$(jq -r '.github.repository_url' "$CONFIG_FILE")
    local project_name
    project_name=$(basename "$github_repo_url" .git)
    readonly PROJECT_DIR="/var/www/$project_name"
    
    # Ensure project directory exists
    if [ -d "$PROJECT_DIR" ]; then
        log "WARN" "Project directory $PROJECT_DIR already exists. Backing up old files..."
        mkdir -p "$BACKUP_DIR"
        sudo mv "$PROJECT_DIR" "$BACKUP_DIR/$project_name-$TIMESTAMP" || error_exit "Failed to backup old project directory"
    fi
    
    sudo mkdir -p "$PROJECT_DIR"
    sudo chown -R $(whoami):$(whoami) "$PROJECT_DIR"
    
    log "INFO" "Project directory $PROJECT_DIR created successfully"
}

# Function to deploy application
deploy_application() {
    log "INFO" "Deploying application..."
    
    # Load GitHub repository URL and branch from config
    local github_repo_url
    github_repo_url=$(jq -r '.github.repository_url' "$CONFIG_FILE")
    local github_branch
    github_branch=$(jq -r '.github.branch' "$CONFIG_FILE")
    
    # Clone repository
    log "INFO" "Cloning repository from $github_repo_url..."
    git clone -b "$github_branch" "$github_repo_url" "$PROJECT_DIR" || error_exit "Failed to clone repository"
    
    # Navigate to project directory
    cd "$PROJECT_DIR" || error_exit "Failed to navigate to project directory"
    
    # Install project dependencies
    log "INFO" "Installing project dependencies..."
    npm install || error_exit "Failed to install project dependencies"
    
    # Build project
    log "INFO" "Building project..."
    npm run build || error_exit "Failed to build project"
    
    # Stop existing PM2 process
    log "INFO" "Stopping existing PM2 process..."
    pm2 stop "$PM2_APP_NAME" || log "INFO" "No existing PM2 process found"
    
    # Start new PM2 process
    log "INFO" "Starting new PM2 process..."
    pm2 start npm --name "$PM2_APP_NAME" -- start || error_exit "Failed to start PM2 process"
    
    # Check application status
    log "INFO" "Checking application status..."
    pm2 status "$PM2_APP_NAME" || error_exit "Failed to check application status"
}

# Updated main execution
main() {
    setup_logging
    validate_config_files
    
    # Check dependencies first
    check_all_dependencies
    
    # Continue with deployment
    init_deployment
    deploy_application
    log "INFO" "Deployment completed successfully!"
}

# Execute main function
main "$@"
