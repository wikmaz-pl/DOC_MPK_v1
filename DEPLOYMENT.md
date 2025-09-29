# 🚀 Document Search System - Deployment Guide

Complete deployment guide for different environments and platforms.

## 📋 Prerequisites

### System Requirements
- **CPU**: 2+ cores (4+ recommended)
- **RAM**: 4GB minimum (8GB+ recommended)
- **Storage**: 20GB+ (depending on document collection size)
- **OS**: Linux (Ubuntu 22.04+ LTS recommended)

### Required Software
- Python 3.9+
- Node.js 16+
- MongoDB 5.0+
- Nginx
- Git

## 🎯 Deployment Options

### Option 1: Automated Installation (Recommended)

**Best for**: Fresh servers, quick deployment

```bash
# One-line installation
curl -fsSL https://raw.githubusercontent.com/your-repo/document-search/main/install.sh | sudo bash

# Or download and inspect first
wget https://raw.githubusercontent.com/your-repo/document-search/main/install.sh
sudo chmod +x install.sh
sudo ./install.sh
```

**What it does:**
- Installs all system dependencies
- Creates application user and directories
- Configures MongoDB, Nginx, and Supervisor
- Sets up systemd services
- Creates sample documents
- Configures firewall

**Time**: ~10-15 minutes

---

### Option 2: Manual Installation

**Best for**: Custom configurations, existing infrastructure

#### Step 1: System Preparation
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y
sudo apt install -y python3 python3-pip python3-venv nodejs npm mongodb-server nginx supervisor git curl wget

# CentOS/RHEL/Fedora
sudo dnf update -y
sudo dnf install -y python3 python3-pip nodejs npm mongodb-server nginx supervisor git curl wget
```

#### Step 2: Install Yarn
```bash
sudo npm install -g yarn
```

#### Step 3: Clone Repository
```bash
git clone https://github.com/your-repo/document-search.git
cd document-search
```

#### Step 4: Run Setup Script
```bash
chmod +x setup.sh
sudo ./setup.sh
```

**Time**: ~15-20 minutes

---

### Option 3: Docker Deployment

**Best for**: Containerized environments, development

#### Prerequisites
- Docker 20.10+
- Docker Compose 2.0+

#### Quick Start
```bash
# Clone repository
git clone https://github.com/your-repo/document-search.git
cd document-search

# Start with Docker Compose
docker-compose up -d

# Check status
docker-compose ps

# View logs
docker-compose logs -f
```

#### Custom Configuration
```bash
# Copy and edit environment files
cp .env.example .env
nano .env

# Rebuild and restart
docker-compose down
docker-compose up --build -d
```

**Access**: http://localhost

**Time**: ~5-10 minutes

---

### Option 4: Kubernetes Deployment

**Best for**: Production clusters, scalability

#### Prerequisites
- Kubernetes cluster 1.20+
- kubectl configured
- Helm 3.0+ (optional)

#### Using Kubernetes Manifests
```bash
# Apply manifests
kubectl apply -f k8s/

# Check deployment
kubectl get pods -n docsearch

# Get service URL
kubectl get svc -n docsearch
```

#### Using Helm Chart
```bash
# Add repository
helm repo add docsearch https://charts.yourdomain.com

# Install
helm install docsearch docsearch/document-search \
  --set domain=docs.yourdomain.com \
  --set mongodb.persistence.size=100Gi
```

---

## 🌍 Environment-Specific Configurations

### Development Environment

```bash
# Clone and setup
git clone https://github.com/your-repo/document-search.git
cd document-search

# Backend
cd backend
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
uvicorn server:app --reload --port 8001

# Frontend (new terminal)
cd frontend
yarn install
yarn start
```

**Access**: 
- Frontend: http://localhost:3000
- Backend: http://localhost:8001

### Production Environment

#### 1. Server Hardening
```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Configure firewall
sudo ufw enable
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Disable root login (after setting up key auth)
sudo sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

#### 2. SSL/HTTPS Setup
```bash
# Install Certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com

# Verify auto-renewal
sudo certbot renew --dry-run
```

#### 3. Performance Optimization
```bash
# MongoDB optimization
sudo nano /etc/mongod.conf
# Add:
# storage:
#   wiredTiger:
#     engineConfig:
#       cacheSizeGB: 4

# Nginx optimization  
sudo nano /etc/nginx/nginx.conf
# Increase worker_processes and worker_connections

# System limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf
```

#### 4. Monitoring Setup
```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Setup log rotation
sudo nano /etc/logrotate.d/docsearch
```

### Cloud Platform Deployments

#### AWS EC2
```bash
# Launch EC2 instance (Ubuntu 22.04 LTS)
# Minimum: t3.medium (2 vCPU, 4GB RAM)
# Recommended: t3.large (2 vCPU, 8GB RAM)

# Connect and install
ssh -i your-key.pem ubuntu@your-ec2-ip
curl -fsSL https://raw.githubusercontent.com/your-repo/document-search/main/install.sh | sudo bash

# Configure security groups:
# - HTTP (80) from 0.0.0.0/0
# - HTTPS (443) from 0.0.0.0/0  
# - SSH (22) from your IP
```

#### Google Cloud Platform
```bash
# Create VM instance
gcloud compute instances create docsearch-vm \
  --image-family=ubuntu-2204-lts \
  --image-project=ubuntu-os-cloud \
  --machine-type=e2-standard-2 \
  --boot-disk-size=50GB

# SSH and install
gcloud compute ssh docsearch-vm
curl -fsSL https://raw.githubusercontent.com/your-repo/document-search/main/install.sh | sudo bash

# Configure firewall
gcloud compute firewall-rules create allow-http --allow tcp:80
gcloud compute firewall-rules create allow-https --allow tcp:443
```

#### DigitalOcean Droplet
```bash
# Create droplet (Ubuntu 22.04, 4GB RAM minimum)
# SSH and install
ssh root@your-droplet-ip
curl -fsSL https://raw.githubusercontent.com/your-repo/document-search/main/install.sh | bash

# Configure firewall (if not using DigitalOcean firewall)
ufw allow ssh
ufw allow 80/tcp
ufw allow 443/tcp
ufw enable
```

---

## 📂 Directory Structure After Installation

```
/opt/document-search/          # Application root
├── backend/                   # Python/FastAPI backend
│   ├── server.py             # Main application
│   ├── requirements.txt      # Dependencies
│   └── .env                  # Configuration
├── frontend/                 # React frontend
│   ├── build/                # Production build
│   ├── src/                  # Source code
│   └── package.json          # Dependencies
└── logs/                     # Application logs

/var/www/html/pdf/            # Document storage
├── documents/                # General documents
├── reports/                  # Report files
└── manuals/                  # Manual files

/etc/nginx/sites-available/   # Nginx configuration
/etc/supervisor/conf.d/       # Supervisor configuration
/etc/systemd/system/          # Systemd services
```

---

## ⚙️ Configuration Options

### Environment Variables

#### Backend (.env)
```bash
# Database
MONGO_URL=mongodb://localhost:27017
DB_NAME=document_search

# CORS
CORS_ORIGINS=*

# Document storage
DOCUMENT_PATH=/var/www/html/pdf

# Logging
LOG_LEVEL=INFO
```

#### Frontend (.env)
```bash
# API endpoint
REACT_APP_BACKEND_URL=http://localhost:8001

# Development
REACT_APP_ENV=production
```

### Custom Document Directory
```bash
# Create custom directory
sudo mkdir -p /data/documents
sudo chown -R www-data:www-data /data/documents

# Update backend configuration
sudo nano /opt/document-search/backend/server.py
# Change: DOCUMENT_BASE_PATH = Path("/data/documents")

# Restart services
sudo systemctl restart docsearch
```

### Database Configuration
```bash
# MongoDB with authentication
sudo nano /etc/mongod.conf
# Enable auth and create users

# Update connection string
MONGO_URL=mongodb://username:password@localhost:27017/document_search
```

---

## 🔧 Management & Maintenance

### Service Management
```bash
# Start/stop all services
sudo systemctl start docsearch
sudo systemctl stop docsearch
sudo systemctl restart docsearch

# Individual services
sudo systemctl restart docsearch-backend
sudo systemctl restart docsearch-frontend

# Check status
sudo systemctl status docsearch
```

### Log Management
```bash
# View real-time logs
sudo journalctl -u docsearch-backend -f
sudo journalctl -u docsearch-frontend -f

# View Nginx logs
sudo tail -f /var/log/nginx/access.log
sudo tail -f /var/log/nginx/error.log
```

### Backup & Restore
```bash
# Backup documents
sudo tar -czf backup-documents-$(date +%Y%m%d).tar.gz /var/www/html/pdf/

# Backup database
sudo mongodump --db document_search --out backup-db-$(date +%Y%m%d)

# Restore database
sudo mongorestore --db document_search backup-db-20240101/document_search/
```

### Updates
```bash
# Application updates
cd /opt/document-search
sudo git pull origin main
sudo ./setup.sh

# System updates
sudo apt update && sudo apt upgrade -y
sudo systemctl restart docsearch
```

---

## 🛡️ Security Considerations

### Basic Security
- Change default passwords
- Enable firewall (UFW/firewalld)
- Keep system updated
- Use HTTPS in production
- Implement access controls

### Advanced Security
```bash
# Fail2ban for SSH protection
sudo apt install fail2ban

# Nginx security headers
sudo nano /etc/nginx/sites-available/docsearch
# Add security headers

# MongoDB security
# Enable authentication
# Use TLS/SSL connections
# Network restrictions
```

### Backup Security
```bash
# Encrypt backups
gpg --symmetric --cipher-algo AES256 backup-file.tar.gz

# Secure backup storage
# Use encrypted cloud storage
# Regular backup testing
```

---

## 📊 Monitoring & Performance

### System Monitoring
```bash
# Resource usage
htop
iotop
df -h
free -m

# Network monitoring
nethogs
ss -tuln
```

### Application Monitoring
```bash
# Service status
sudo systemctl status docsearch-*

# MongoDB status
sudo systemctl status mongod
mongo --eval "db.stats()"

# Nginx status
sudo nginx -t
sudo systemctl status nginx
```

### Performance Tuning
```bash
# MongoDB indexing
mongo document_search
db.indexed_files.createIndex({"content": "text"})
db.indexed_files.createIndex({"file_name": 1})

# Nginx worker processes
sudo nano /etc/nginx/nginx.conf
# worker_processes auto;
# worker_connections 1024;
```

---

## 🚨 Troubleshooting

### Common Issues

#### Services Not Starting
```bash
# Check logs
sudo journalctl -u docsearch-backend --no-pager
sudo journalctl -u docsearch-frontend --no-pager

# Check ports
sudo netstat -tlnp | grep :8001
sudo netstat -tlnp | grep :3000

# Restart services
sudo systemctl restart docsearch
```

#### Search Not Working
```bash
# Re-index documents
curl -X POST http://localhost:8001/api/files/index

# Check MongoDB
sudo systemctl status mongod
mongo --eval "db.indexed_files.count()"
```

#### File Access Issues
```bash
# Check permissions
ls -la /var/www/html/pdf/
sudo chown -R www-data:www-data /var/www/html/pdf/
sudo chmod -R 755 /var/www/html/pdf/
```

#### Performance Issues
```bash
# Check system resources
top
free -m
df -h

# Check MongoDB performance
mongo --eval "db.stats()"
mongo --eval "db.indexed_files.stats()"

# Optimize MongoDB
sudo systemctl restart mongod
```

### Getting Help

- **Documentation**: Check README.md
- **Logs**: Always check application logs first
- **Community**: GitHub Issues and Discussions
- **Support**: Email support for critical issues

---

## 📈 Scaling Considerations

### Horizontal Scaling
- Load balancer (Nginx/HAProxy)
- Multiple backend instances
- Shared document storage (NFS/GlusterFS)
- MongoDB replica set

### Vertical Scaling
- Increase server resources
- Optimize database queries
- Enable compression
- Use CDN for static assets

### Cloud Scaling
- Auto Scaling Groups (AWS)
- Managed databases (MongoDB Atlas)
- Container orchestration (Kubernetes)
- Serverless functions for processing

---

**📝 Remember**: Always test deployments in staging environment before production!