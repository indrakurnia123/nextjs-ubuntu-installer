# NextJS Ubuntu Deployment Script

Automated deployment script for NextJS applications on Ubuntu servers. This script handles dependency installation, project setup, and deployment using PM2 process manager.

## Features

- 🔄 Automated dependency management
- 📦 Node.js version management
- 🚀 PM2 process management
- 🔒 Secure deployment practices
- 📝 Comprehensive logging
- 🔄 Backup system for existing deployments
- ⚡ Optimized for Ubuntu environments

## Prerequisites

The script will automatically install missing dependencies, but you'll need:

- Ubuntu server (18.04 or later)
- Root or sudo access
- Basic configuration files (config.json and secrets.json)

## Configuration

### Config File Structure (config.json)

```json
{
  "github": {
    "repository_url": "https://github.com/your-username/your-repo.git",
    "branch": "main"
  },
  "node": {
    "required_version": "18"
  },
  "pm2": {
    "app_name": "nextjs-app"
  },
  "project": {
    "directory": "/var/www/nama-project"
  }
}
```

## Installation

1. Clone this repository:
```bash
git clone https://github.com/your-username/nextjs-ubuntu-installer.git
cd nextjs-ubuntu-installer
```

2. Set up configuration:
```bash
cp config.example.json config.json
# Edit config.json with your settings
nano config.json
```

3. Make the script executable:
```bash
chmod +x deploy.sh
```

4. Run the deployment:
```bash
./deploy.sh
```

## Script Components

The deployment script includes:

- **Dependency Check**: Automatically installs required system packages
- **Node.js Setup**: Installs or updates Node.js to the specified version
- **PM2 Configuration**: Sets up PM2 for process management
- **Git Integration**: Handles repository cloning and updates
- **Backup System**: Creates backups of existing deployments
- **Logging**: Maintains detailed deployment logs

## Directory Structure

```
/var/www/
├── nama-project/          # Main project directory
├── backups/              # Backup directory
│   └── nextjs-app_*     # Timestamped backups
└── logs/                # Log files
```

## Logging

Logs are stored in `/var/log/nextjs-deploy.log` and include:
- Deployment steps
- Error messages
- Installation status
- PM2 process information

## Error Handling

The script includes comprehensive error handling:
- Dependency verification
- Installation status checks
- Process management validation
- Backup confirmation

## Maintenance

### Updating the Application

To update your application:
1. Push changes to your repository
2. Run the deployment script:
```bash
./deploy.sh
```

### Managing PM2 Processes

Common PM2 commands:
```bash
# View all processes
pm2 list

# Restart application
pm2 restart nextjs-app

# View logs
pm2 logs nextjs-app

# Monitor processes
pm2 monit
```

## Troubleshooting

### Common Issues

1. **Permission Denied**
   ```bash
   sudo chmod +x deploy.sh
   ```

2. **Node.js Version Mismatch**
   - Check config.json for correct version
   - Run script again to update Node.js

3. **PM2 Process Errors**
   ```bash
   pm2 delete nextjs-app
   ./deploy.sh
   ```

### Debug Mode

For detailed logs:
```bash
PM2_DEBUG=true ./deploy.sh
```

## Security

- Automated dependency updates
- Secure file permissions
- Backup system
- PM2 process isolation

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Create a Pull Request

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

For support:
1. Check the documentation
2. Review the log files
3. Open an issue on GitHub

## Author

Your Name
- GitHub: [@indrakurnia123](https://github.com/indrakurnia123)
- Email: indrakurnia768@gmail.com