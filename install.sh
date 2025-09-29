#!/bin/bash

# Document Search System - Automated Installation Script
# Supports: Ubuntu 22.04+, Debian 12+, CentOS Stream 9+, Rocky Linux 9+

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="document-search"
APP_DIR="/opt/$APP_NAME"
DOCUMENT_DIR="/var/www/html/pdf"
SERVICE_USER="docsearch"

# Logging
LOG_FILE="/tmp/${APP_NAME}-install.log"
exec > >(tee -a $LOG_FILE)
exec 2>&1

print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root (use sudo)"
        exit 1
    fi
}

detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$ID
        OS_VERSION=$VERSION_ID
    else
        print_error "Cannot detect operating system"
        exit 1
    fi
    
    print_status "Detected OS: $OS $OS_VERSION"
}

install_dependencies() {
    print_status "Installing system dependencies..."
    
    case $OS in
        ubuntu|debian)
            apt update
            apt install -y python3 python3-pip python3-venv nodejs npm \
                          mongodb-server nginx supervisor git curl wget \
                          build-essential software-properties-common
            ;;
        centos|rocky|rhel|fedora)
            if command -v dnf >/dev/null 2>&1; then
                dnf update -y
                dnf install -y python3 python3-pip nodejs npm \
                              mongodb-server nginx supervisor git curl wget \
                              gcc gcc-c++ make
            else
                yum update -y
                yum install -y python3 python3-pip nodejs npm \
                              mongodb-server nginx supervisor git curl wget \
                              gcc gcc-c++ make
            fi
            ;;
        *)
            print_error "Unsupported operating system: $OS"
            exit 1
            ;;
    esac
    
    # Install yarn globally
    npm install -g yarn
    
    print_success "System dependencies installed"
}

create_user() {
    if ! id "$SERVICE_USER" &>/dev/null; then
        print_status "Creating service user: $SERVICE_USER"
        useradd --system --shell /bin/false --home $APP_DIR $SERVICE_USER
        print_success "Service user created"
    else
        print_status "Service user $SERVICE_USER already exists"
    fi
}

setup_directories() {
    print_status "Setting up directories..."
    
    # Create application directory
    mkdir -p $APP_DIR
    mkdir -p $APP_DIR/{backend,frontend,logs,config}
    
    # Create document directory
    mkdir -p $DOCUMENT_DIR
    mkdir -p $DOCUMENT_DIR/{documents,reports,manuals}
    
    # Set ownership
    chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
    chown -R www-data:www-data $DOCUMENT_DIR
    
    # Set permissions
    chmod -R 755 $APP_DIR
    chmod -R 755 $DOCUMENT_DIR
    
    print_success "Directories created and configured"
}

install_application() {
    print_status "Installing application files..."
    
    # Copy application files
    cp -r backend/* $APP_DIR/backend/
    cp -r frontend/* $APP_DIR/frontend/
    
    # Install Python dependencies
    cd $APP_DIR/backend
    python3 -m pip install -r requirements.txt
    
    # Install Node.js dependencies
    cd $APP_DIR/frontend
    yarn install
    yarn build
    
    # Set ownership
    chown -R $SERVICE_USER:$SERVICE_USER $APP_DIR
    
    print_success "Application installed"
}

configure_environment() {
    print_status "Configuring environment..."
    
    # Backend environment
    cat > $APP_DIR/backend/.env << EOF
MONGO_URL=mongodb://localhost:27017
DB_NAME=document_search
CORS_ORIGINS=*
EOF

    # Frontend environment  
    cat > $APP_DIR/frontend/.env << EOF
REACT_APP_BACKEND_URL=http://localhost
EOF
    
    print_success "Environment configured"
}

setup_mongodb() {
    print_status "Configuring MongoDB..."
    
    # Start and enable MongoDB
    systemctl enable mongod
    systemctl start mongod
    
    # Wait for MongoDB to be ready
    sleep 5
    
    # Create database and user (optional)
    # mongo --eval "db = db.getSiblingDB('document_search'); db.createUser({user: 'docsearch', pwd: 'password', roles: ['readWrite']})" 2>/dev/null || true
    
    print_success "MongoDB configured and started"
}

setup_nginx() {
    print_status "Configuring Nginx..."
    
    # Create nginx configuration
    cat > /etc/nginx/sites-available/$APP_NAME << 'EOF'
server {
    listen 80;
    server_name _;
    
    # Increase client max body size for file uploads
    client_max_body_size 100M;
    
    # Frontend
    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Backend API
    location /api/ {
        proxy_pass http://localhost:8001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        proxy_read_timeout 86400;
    }
    
    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript application/json;
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    rm -f /etc/nginx/sites-enabled/default
    
    # Test configuration
    nginx -t
    
    # Start and enable nginx
    systemctl enable nginx
    systemctl restart nginx
    
    print_success "Nginx configured and started"
}

setup_supervisor() {
    print_status "Configuring Supervisor..."
    
    # Backend supervisor config
    cat > /etc/supervisor/conf.d/${APP_NAME}-backend.conf << EOF
[program:${APP_NAME}-backend]
command=python3 -m uvicorn server:app --host 0.0.0.0 --port 8001
directory=$APP_DIR/backend
user=$SERVICE_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/${APP_NAME}-backend.err.log
stdout_logfile=/var/log/supervisor/${APP_NAME}-backend.out.log
environment=PATH="$APP_DIR/backend/.venv/bin:%(ENV_PATH)s"
EOF

    # Frontend supervisor config
    cat > /etc/supervisor/conf.d/${APP_NAME}-frontend.conf << EOF
[program:${APP_NAME}-frontend]
command=yarn start
directory=$APP_DIR/frontend
user=$SERVICE_USER
autostart=true
autorestart=true
stderr_logfile=/var/log/supervisor/${APP_NAME}-frontend.err.log
stdout_logfile=/var/log/supervisor/${APP_NAME}-frontend.out.log
environment=PATH="/usr/bin:%(ENV_PATH)s",PORT="3000"
EOF

    # Reload supervisor
    supervisorctl reread
    supervisorctl update
    supervisorctl start all
    
    print_success "Supervisor configured and services started"
}

setup_systemd_services() {
    print_status "Creating systemd services..."
    
    # Main service
    cat > /etc/systemd/system/$APP_NAME.service << EOF
[Unit]
Description=Document Search System
After=network.target mongod.service
Wants=mongod.service

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/bin/true
ExecReload=/usr/bin/supervisorctl restart all

[Install]
WantedBy=multi-user.target
EOF

    systemctl daemon-reload
    systemctl enable $APP_NAME
    
    print_success "Systemd services created"
}

create_sample_documents() {
    print_status "Creating sample documents..."
    
    # Create sample PDF using Python
    python3 << 'EOF'
import os
from reportlab.pdfgen import canvas
from reportlab.lib.pagesizes import letter

def create_sample_pdf(filename, title, content):
    try:
        os.makedirs(os.path.dirname(filename), exist_ok=True)
        c = canvas.Canvas(filename, pagesize=letter)
        width, height = letter
        
        # Title
        c.setFont('Helvetica-Bold', 16)
        c.drawString(50, height - 50, title)
        
        # Content
        c.setFont('Helvetica', 12)
        y_position = height - 100
        for line in content:
            c.drawString(50, y_position, line)
            y_position -= 20
            if y_position < 50:
                c.showPage()
                c.setFont('Helvetica', 12)
                y_position = height - 50
        
        c.save()
        print(f"Created: {filename}")
    except Exception as e:
        print(f"Error creating {filename}: {e}")

# Create sample documents
create_sample_pdf('/var/www/html/pdf/documents/sample_document.pdf',
    'Welcome to Document Search System',
    [
        'This is a sample document to demonstrate the search capabilities.',
        'You can search for content inside this PDF file.',
        'The system supports multiple file formats including:',
        '- PDF files for document storage',
        '- Word documents (DOC, DOCX)',
        '- Excel spreadsheets (XLS, XLSX)',
        '- Rich Text Format (RTF) files',
        '- Plain text files (TXT)',
        '',
        'Features:',
        '- Real-time search as you type',
        '- Search by filename or content',
        '- Document preview and download',
        '- Organized folder structure',
        '',
        'Try searching for terms like "search", "document", or "PDF".',
    ])

# Create a text file
with open('/var/www/html/pdf/manuals/getting_started.txt', 'w') as f:
    f.write('''Getting Started Guide

Welcome to the Document Search System!

This powerful tool allows you to:
1. Upload and organize documents in folders
2. Search through document content in real-time
3. Preview documents directly in your browser
4. Download files when needed

To get started:
- Click "Index Documents" to enable content search
- Use the search bar to find documents by name or content
- Navigate folders using the left panel
- Preview documents in the middle panel
- View search results in the right panel

Supported file formats:
- PDF (.pdf) - Full preview support
- Word (.docx, .doc) - Download and view
- Excel (.xlsx, .xls) - Download and view  
- RTF (.rtf) - Download and view
- Text (.txt) - Download and view

Happy searching!
''')

print("Sample documents created successfully!")
EOF
    
    # Set permissions
    chown -R www-data:www-data $DOCUMENT_DIR
    chmod -R 644 $DOCUMENT_DIR/*.pdf 2>/dev/null || true
    chmod -R 644 $DOCUMENT_DIR/*.txt 2>/dev/null || true
    
    print_success "Sample documents created"
}

setup_firewall() {
    print_status "Configuring firewall..."
    
    case $OS in
        ubuntu|debian)
            if command -v ufw >/dev/null 2>&1; then
                ufw --force enable
                ufw allow ssh
                ufw allow 80/tcp
                ufw allow 443/tcp
                print_success "UFW firewall configured"
            fi
            ;;
        centos|rocky|rhel|fedora)
            if command -v firewall-cmd >/dev/null 2>&1; then
                systemctl enable firewalld
                systemctl start firewalld
                firewall-cmd --permanent --add-service=http
                firewall-cmd --permanent --add-service=https
                firewall-cmd --permanent --add-service=ssh
                firewall-cmd --reload
                print_success "Firewalld configured"
            fi
            ;;
    esac
}

create_management_script() {
    print_status "Creating management script..."
    
    cat > /usr/local/bin/docsearch << 'EOF'
#!/bin/bash

APP_NAME="document-search"

case "$1" in
    start)
        echo "Starting Document Search System..."
        systemctl start mongod nginx supervisor
        supervisorctl start all
        echo "Document Search System started"
        ;;
    stop)
        echo "Stopping Document Search System..."
        supervisorctl stop all
        systemctl stop nginx
        echo "Document Search System stopped"
        ;;
    restart)
        echo "Restarting Document Search System..."
        supervisorctl restart all
        systemctl restart nginx
        echo "Document Search System restarted"
        ;;
    status)
        echo "=== System Services ==="
        systemctl status mongod --no-pager -l
        systemctl status nginx --no-pager -l
        echo -e "\n=== Application Services ==="
        supervisorctl status
        ;;
    logs)
        case "$2" in
            backend)
                tail -f /var/log/supervisor/document-search-backend.*.log
                ;;
            frontend)
                tail -f /var/log/supervisor/document-search-frontend.*.log
                ;;
            nginx)
                tail -f /var/log/nginx/access.log
                ;;
            *)
                echo "Usage: docsearch logs [backend|frontend|nginx]"
                ;;
        esac
        ;;
    index)
        echo "Re-indexing documents..."
        curl -X POST http://localhost:8001/api/files/index
        echo -e "\nIndexing completed"
        ;;
    *)
        echo "Usage: docsearch {start|stop|restart|status|logs|index}"
        echo ""
        echo "Commands:"
        echo "  start     - Start all services"
        echo "  stop      - Stop all services"
        echo "  restart   - Restart all services"
        echo "  status    - Show service status"
        echo "  logs      - Show logs (backend|frontend|nginx)"
        echo "  index     - Re-index all documents"
        ;;
esac
EOF
    
    chmod +x /usr/local/bin/docsearch
    
    print_success "Management script created at /usr/local/bin/docsearch"
}

print_final_info() {
    echo ""
    echo "=============================================="
    echo "   🎉 Installation Complete! 🎉"
    echo "=============================================="
    echo ""
    print_success "Document Search System has been successfully installed!"
    echo ""
    echo "📍 Application URL: http://$(hostname -I | awk '{print $1}')"
    echo "📂 Document Directory: $DOCUMENT_DIR"
    echo "⚙️  Application Directory: $APP_DIR"
    echo ""
    echo "🔧 Management Commands:"
    echo "   docsearch start     - Start all services"
    echo "   docsearch stop      - Stop all services" 
    echo "   docsearch restart   - Restart all services"
    echo "   docsearch status    - Check service status"
    echo "   docsearch logs      - View application logs"
    echo "   docsearch index     - Re-index documents"
    echo ""
    echo "📖 Next Steps:"
    echo "1. Open http://$(hostname -I | awk '{print $1}') in your browser"
    echo "2. Copy your documents to $DOCUMENT_DIR"
    echo "3. Click 'Index Documents' to enable content search"
    echo "4. Start searching your documents!"
    echo ""
    echo "📝 Documentation: See README.md for detailed usage instructions"
    echo "🐛 Logs: /var/log/supervisor/${APP_NAME}-*.log"
    echo ""
    print_warning "Don't forget to:"
    print_warning "- Set up SSL/HTTPS for production use"
    print_warning "- Configure authentication if needed"
    print_warning "- Set up regular backups"
    echo ""
}

# Main installation flow
main() {
    echo "=============================================="
    echo "  📚 Document Search System Installer"
    echo "=============================================="
    echo ""
    
    check_root
    detect_os
    
    print_status "Starting installation process..."
    
    install_dependencies
    create_user
    setup_directories
    install_application
    configure_environment
    setup_mongodb
    setup_nginx
    setup_supervisor
    setup_systemd_services
    create_sample_documents
    setup_firewall
    create_management_script
    
    # Final service restart
    systemctl restart nginx
    supervisorctl restart all
    
    print_final_info
}

# Run installation
main "$@"