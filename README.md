# Next.js Deployment Automation Tool

## Overview

The Next.js Deployment Automation Tool is a Bash script designed to automate the deployment of a Next.js project to an Ubuntu VPS. This tool ensures that all necessary dependencies are checked and installed, the project is built, and the application is deployed and managed using PM2. The tool is modular, secure, and includes detailed logging and error handling.

## Key Features

- **Configuration Management:** Uses separate configuration files (`config.json` and `secrets.json`) to store deployment settings and sensitive information.
- **Dependency Checking:** Automatically checks and installs required tools such as Node.js, npm, Git, and PM2.
- **Version Control:** Ensures the correct version of Node.js is installed as specified in the configuration.
- **Repository Cloning:** Clones the Next.js project from a specified GitHub repository.
- **Project Building:** Builds the Next.js project using `npm run build`.
- **File Transfer:** Transfers the built files to the VPS (can be adapted for local to VPS transfers using SCP).
- **PM2 Management:** Stops any existing PM2 processes and starts a new one to run the Next.js application.
- **Status Checking:** Verifies that the application is running correctly.
- **Logging:** Logs all stages of the deployment process, including errors, for traceability and debugging.

## Prerequisites

- **Ubuntu VPS:** Ensure you have an Ubuntu VPS with SSH access.
- **Bash:** The script is written in Bash, so ensure Bash is installed on your VPS.
- **jq:** A lightweight and flexible command-line JSON processor. Install it using:
  ```bash
  sudo apt-get update
  sudo apt-get install -y jq
  ```

## Configuration Files

### `config.json`

This file contains general configuration settings such as the GitHub repository URL, Node.js version, and logging details.

```json
{
  "github": {
    "repository_url": "https://github.com/yourusername/your-nextjs-project.git",
    "branch": "main"
  },
  "node": {
    "required_version": "18.x"
  },
  "pm2": {
    "app_name": "nextjs-app"
  },
  "logging": {
    "log_file": "/var/log/nextjs-deploy.log"
  }
}
```

### `secrets.json`

This file contains sensitive information such as GitHub tokens and SSH keys. Ensure this file is not included in version control.

```json
{
  "github_token": "your_github_token_here",
  "ssh_key": "your_ssh_key_here"
}
```

## How to Use

### Step 1: Clone the Repository

Clone the repository to your local machine or directly to your VPS.

```bash
git clone https://github.com/yourusername/nextjs-deploy.git
cd nextjs-deploy
```

### Step 2: Create Configuration Files

Create the `config.json` and `secrets.json` files with the appropriate settings.

```bash
cp config.json.example config.json
cp secrets.json.example secrets.json
```

Edit the `config.json` and `secrets.json` files with your specific settings.

### Step 3: Make the Script Executable

Make the `deploy.sh` script executable.

```bash
chmod +x deploy.sh
```

### Step 4: Run the Script

Run the script to deploy your Next.js project.

```bash
./deploy.sh
```

## Logging

The script logs all stages of the deployment process, including errors, to the file specified in `config.json`. By default, the log file is located at `/var/log/nextjs-deploy.log`.

## Error Handling

The script includes error handling at each stage to catch and log any issues that occur during the deployment process. If an error is encountered, the script will log the error and exit.

## Security

- **Sensitive Information:** Ensure that `secrets.json` is not included in version control. You can add it to `.gitignore` to prevent accidental commits.
- **SSH Keys:** Use secure methods for managing SSH keys and tokens.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have any improvements or bug fixes.

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.