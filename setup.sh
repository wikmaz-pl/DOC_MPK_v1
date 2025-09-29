#!/bin/bash

# Document Search System - Manual Setup Script
# Run this after cloning the repository

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_requirements() {
    print_status "Checking system requirements..."
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is not installed"
        exit 1
    fi
    
    # Check Node.js
    if ! command -v node &> /dev/null; then
        print_error "Node.js is not installed"
        exit 1
    fi
    
    # Check MongoDB
    if ! command -v mongod &> /dev/null; then
        print_error "MongoDB is not installed"
        exit 1
    fi
    
    print_success "All requirements met"
}

setup_python_environment() {
    print_status "Setting up Python environment..."
    
    cd backend
    
    # Install Python dependencies
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt
    
    cd ..
    
    print_success "Python environment setup complete"
}

setup_node_environment() {
    print_status "Setting up Node.js environment..."
    
    cd frontend
    
    # Install Node.js dependencies
    if command -v yarn &> /dev/null; then
        yarn install
    else
        npm install
    fi
    
    cd ..
    
    print_success "Node.js environment setup complete"
}

setup_directories() {
    print_status "Setting up directories..."
    
    # Create document directory
    mkdir -p /var/www/html/pdf
    mkdir -p /var/www/html/pdf/{documents,reports,manuals}
    
    # Set permissions
    chown -R www-data:www-data /var/www/html/pdf/
    chmod -R 755 /var/www/html/pdf/
    
    print_success "Directories created"
}

setup_mongodb() {
    print_status "Setting up MongoDB..."
    
    # Start MongoDB service
    systemctl enable mongod
    systemctl start mongod
    
    # Wait for MongoDB to start
    sleep 3
    
    print_success "MongoDB setup complete"
}

create_systemd_services() {
    print_status "Creating systemd services..."
    
    # Backend service
    cat > /etc/systemd/system/docsearch-backend.service << EOF
[Unit]
Description=Document Search Backend
After=network.target mongod.service
Requires=mongod.service

[Service]
Type=simple
User=www-data
WorkingDirectory=$(pwd)/backend
Environment=PATH=/usr/bin:/usr/local/bin
ExecStart=/usr/bin/python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
EOF

    # Frontend service
    cat > /etc/systemd/system/docsearch-frontend.service << EOF
[Unit]
Description=Document Search Frontend
After=network.target

[Service]
Type=simple
User=www-data
WorkingDirectory=$(pwd)/frontend
Environment=PATH=/usr/bin:/usr/local/bin:/usr/local/lib/nodejs/node-v18.17.1-linux-x64/bin
ExecStart=/usr/bin/yarn start
Restart=always
RestartSec=3
Environment=PORT=3000

[Install]
WantedBy=multi-user.target
EOF

    # Main service
    cat > /etc/systemd/system/docsearch.service << EOF
[Unit]
Description=Document Search System
Requires=docsearch-backend.service docsearch-frontend.service
After=docsearch-backend.service docsearch-frontend.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecReload=/bin/systemctl restart docsearch-backend docsearch-frontend

[Install]
WantedBy=multi-user.target
EOF

    # Reload systemd
    systemctl daemon-reload
    
    # Enable services
    systemctl enable docsearch-backend
    systemctl enable docsearch-frontend
    systemctl enable docsearch
    
    print_success "Systemd services created"
}

setup_nginx() {
    print_status "Setting up Nginx..."
    
    # Create Nginx configuration
    cat > /etc/nginx/sites-available/docsearch << 'EOF'
server {
    listen 80;
    server_name _;
    
    client_max_body_size 100M;
    
    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/docsearch /etc/nginx/sites-enabled/
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    nginx -t
    
    # Restart Nginx
    systemctl restart nginx
    
    print_success "Nginx configured"
}

create_sample_data() {
    print_status "Creating sample documents..."
    
    # Create a simple text file
    cat > /var/www/html/pdf/documents/welcome.txt << 'EOF'
Welcome to Document Search System!

This is a sample document to help you get started.

Features:
- Search through multiple document formats
- Real-time search as you type
- Document preview and download
- Organized folder structure

Supported formats:
- PDF files (.pdf)
- Word documents (.docx, .doc)
- Excel spreadsheets (.xlsx, .xls)
- Rich Text Format (.rtf)
- Plain text files (.txt)

Try searching for "document", "search", or "PDF" to see the system in action!
EOF

    # Set permissions
    chown -R www-data:www-data /var/www/html/pdf/
    
    print_success "Sample documents created"
}

start_services() {
    print_status "Starting services..."
    
    # Start backend and frontend
    systemctl start docsearch-backend
    systemctl start docsearch-frontend
    
    # Wait for services to start
    sleep 5
    
    # Check status
    if systemctl is-active --quiet docsearch-backend && systemctl is-active --quiet docsearch-frontend; then
        print_success "All services started successfully"
    else
        print_error "Some services failed to start. Check logs with: journalctl -u docsearch-backend -u docsearch-frontend"
        exit 1
    fi
}

print_completion_message() {
    echo ""
    echo "=============================================="
    echo "   ✅ Setup Complete!"
    echo "=============================================="
    echo ""
    echo "🌐 Access your Document Search System at:"
    echo "   http://$(hostname -I | awk '{print $1}')"
    echo ""
    echo "📁 Document directory: /var/www/html/pdf/"
    echo ""
    echo "🔧 Service commands:"
    echo "   sudo systemctl start docsearch      # Start all services"
    echo "   sudo systemctl stop docsearch       # Stop all services" 
    echo "   sudo systemctl restart docsearch    # Restart all services"
    echo "   sudo systemctl status docsearch-*   # Check service status"
    echo ""
    echo "📝 View logs:"
    echo "   sudo journalctl -u docsearch-backend -f"
    echo "   sudo journalctl -u docsearch-frontend -f"
    echo ""
    echo "📖 Next steps:"
    echo "1. Open the URL above in your browser"
    echo "2. Copy your documents to /var/www/html/pdf/"
    echo "3. Click 'Index Documents' to enable content search"
    echo "4. Start searching!"
    echo ""
}

# Main setup flow
main() {
    echo "=============================================="
    echo "  📚 Document Search System Setup"  
    echo "=============================================="
    echo ""
    
    check_requirements
    setup_python_environment
    setup_node_environment
    setup_directories
    setup_mongodb
    create_systemd_services
    setup_nginx
    create_sample_data
    start_services
    
    print_completion_message
}

# Run setup
main "$@"