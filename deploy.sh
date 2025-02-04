#!/bin/bash

# Load configuration files
CONFIG_FILE="config.json"
SECRETS_FILE="secrets.json"

# Ensure log file directory exists
LOG_DIR="/var/log"
LOG_FILE="$LOG_DIR/nextjs-deploy.log"

if [[ ! -d "$LOG_DIR" ]]; then
  sudo mkdir -p "$LOG_DIR"
  sudo touch "$LOG_FILE"
  sudo chmod 644 "$LOG_FILE"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo "Error: $CONFIG_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

if [[ ! -f "$SECRETS_FILE" ]]; then
  echo "Error: $SECRETS_FILE not found" | tee -a "$LOG_FILE"
  exit 1
fi

# Load configuration
GITHUB_REPO_URL=$(jq -r '.github.repository_url' "$CONFIG_FILE")
GITHUB_BRANCH=$(jq -r '.github.branch' "$CONFIG_FILE")
NODE_VERSION=$(jq -r '.node.required_version' "$CONFIG_FILE")
PM2_APP_NAME=$(jq -r '.pm2.app_name' "$CONFIG_FILE")

# Function to log messages
log() {
  echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Function to handle errors
error() {
  log "Error: $1"
  exit 1
}

# Check System Requirements
log "Checking system requirements..."

# Check Node.js Installation
log "Checking Node.js installation..."
if ! command -v node &> /dev/null; then
  log "Node.js not found. Installing Node.js $NODE_VERSION..."
  curl -fsSL https://deb.nodesource.com/setup_$NODE_VERSION.x | sudo -E bash -
  sudo apt-get install -y nodejs
fi

# Verify Node.js version
if ! node --version | grep -q "$NODE_VERSION"; then
  error "Node.js version mismatch. Expected $NODE_VERSION, found $(node --version)"
fi

# Check npm/yarn Installation
log "Checking npm/yarn installation..."
if ! command -v npm &> /dev/null; then
  error "npm not found. Please install npm."
fi

# Check Git Installation
log "Checking Git installation..."
if ! command -v git &> /dev/null; then
  log "Git not found. Installing Git..."
  sudo apt-get update
  sudo apt-get install -y git
fi

# Check PM2 Installation
log "Checking PM2 installation..."
if ! command -v pm2 &> /dev/null; then
  log "PM2 not found. Installing PM2..."
  sudo npm install -g pm2
fi

# Define project directory
PROJECT_DIR="/var/www/nama-project"

# Ensure project directory exists
if [[ -d "$PROJECT_DIR" ]]; then
  log "Project directory $PROJECT_DIR already exists. Removing old files..."
  sudo rm -rf "$PROJECT_DIR"
fi

sudo mkdir -p "$PROJECT_DIR"

# Clone Repository
log "Cloning repository from $GITHUB_REPO_URL..."
git clone -b "$GITHUB_BRANCH" "$GITHUB_REPO_URL" "$PROJECT_DIR" || error "Failed to clone repository"

# Navigate to project directory
cd "$PROJECT_DIR" || error "Failed to navigate to project directory"

# Install Project Dependencies
log "Installing project dependencies..."
npm install || error "Failed to install project dependencies"

# Build Project
log "Building project..."
npm run build || error "Failed to build project"

# Stop Existing PM2 Process
log "Stopping existing PM2 process..."
pm2 stop "$PM2_APP_NAME" || log "No existing PM2 process found"

# Start New PM2 Process
log "Starting new PM2 process..."
pm2 start npm --name "$PM2_APP_NAME" -- start || error "Failed to start PM2 process"

# Check Application Status
log "Checking application status..."
pm2 status "$PM2_APP_NAME" || error "Failed to check application status"

# Log Success
log "Deployment successful!"

exit 0
