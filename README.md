# 📚 Document Search System

A powerful, Google-like document search system that indexes and searches through multiple file formats including PDF, Word, Excel, RTF, and text files with real-time content search capabilities.

## 🌟 Features

- **Multi-Format Support**: PDF, DOCX/DOC, XLSX/XLS, RTF, TXT files
- **Real-time Search**: Search by filename and document content
- **3-Panel Interface**: File browser, document preview, search results
- **Content Indexing**: Fast full-text search across all documents
- **Document Preview**: Built-in viewers and download options
- **Responsive Design**: Works on desktop and mobile devices

## 📋 System Requirements

### Recommended Linux Distributions

**Primary Recommendations:**
- **Ubuntu 22.04 LTS** or **Ubuntu 24.04 LTS** (Recommended)
- **Debian 12** (Bookworm)
- **CentOS Stream 9** or **Rocky Linux 9**

**Also Compatible:**
- Fedora 38+
- openSUSE Leap 15.5+
- Linux Mint 21+

### Hardware Requirements

**Minimum:**
- 2 CPU cores
- 4 GB RAM
- 10 GB disk space
- Network connectivity

**Recommended:**
- 4+ CPU cores
- 8+ GB RAM
- 50+ GB disk space (for document storage)
- SSD storage for better performance

## 🚀 Quick Installation

### Option 1: Automated Installation (Recommended)

```bash
# Download and run the installation script
curl -fsSL https://raw.githubusercontent.com/your-repo/document-search/main/install.sh | bash

# Or download first, then run
wget https://raw.githubusercontent.com/your-repo/document-search/main/install.sh
chmod +x install.sh
sudo ./install.sh
```

### Option 2: Manual Installation

#### Step 1: Update System
```bash
# Ubuntu/Debian
sudo apt update && sudo apt upgrade -y

# CentOS/Rocky Linux/Fedora
sudo dnf update -y
```

#### Step 2: Install System Dependencies
```bash
# Ubuntu/Debian
sudo apt install -y python3 python3-pip python3-venv nodejs npm mongodb-server nginx supervisor git curl

# CentOS/Rocky Linux/Fedora  
sudo dnf install -y python3 python3-pip nodejs npm mongodb-server nginx supervisor git curl
```

#### Step 3: Install Yarn
```bash
npm install -g yarn
```

#### Step 4: Clone Repository
```bash
git clone https://github.com/your-repo/document-search.git
cd document-search
```

#### Step 5: Run Setup Script
```bash
chmod +x setup.sh
sudo ./setup.sh
```

## 📁 Directory Structure

```
/opt/document-search/          # Application root
├── backend/                   # FastAPI backend
│   ├── server.py             # Main application
│   ├── requirements.txt      # Python dependencies
│   └── .env                  # Backend configuration
├── frontend/                 # React frontend  
│   ├── src/                  # Source code
│   ├── package.json          # Node dependencies
│   └── .env                  # Frontend configuration
├── documents/                # Document storage (configurable)
├── logs/                     # Application logs
├── config/                   # Configuration files
└── scripts/                  # Utility scripts
```

## ⚙️ Configuration

### Document Storage Location

By default, documents are stored in `/var/www/html/pdf/`. To change this:

1. Edit backend configuration:
```bash
sudo nano /app/backend/.env
```

2. Update the document path in `server.py`:
```python
DOCUMENT_BASE_PATH = Path("/your/custom/path/documents")
```

3. Create the directory and set permissions:
```bash
sudo mkdir -p /your/custom/path/documents
sudo chown -R www-data:www-data /your/custom/path/documents
sudo chmod -R 755 /your/custom/path/documents
```

4. Restart services:
```bash
sudo supervisorctl restart backend
```

### Database Configuration

MongoDB configuration in `/app/backend/.env`:
```bash
MONGO_URL=mongodb://localhost:27017
DB_NAME=test_database
```

## 🔧 Management Commands

### Service Control
```bash
# Start/restart services
sudo supervisorctl start all
sudo supervisorctl restart all
sudo supervisorctl stop all

# Individual services
sudo supervisorctl restart backend
sudo supervisorctl restart frontend

# Check status
sudo supervisorctl status
```

### View Logs
```bash
# Backend logs
tail -f /var/log/supervisor/backend.*.log

# Frontend logs  
tail -f /var/log/supervisor/frontend.*.log
```

## 📖 Usage Guide

### 1. Initial Setup
1. **Access the application**: Open http://your-server-ip in your browser
2. **Add documents**: Copy your PDF, Word, Excel, RTF, and text files to `/var/www/html/pdf/`
3. **Index documents**: Click the "Index Documents" button to enable content search

### 2. File Management
```bash
# Add documents to the system
sudo cp /path/to/your/documents/* /var/www/html/pdf/

# Set proper permissions
sudo chown -R www-data:www-data /var/www/html/pdf/
sudo chmod -R 644 /var/www/html/pdf/

# Organize in folders (optional)
sudo mkdir -p /var/www/html/pdf/{contracts,reports,manuals,policies}
```

### 3. Using the Interface

**File Browser (Left Panel):**
- Navigate through folders by clicking on them
- Click on any supported file to preview it

**Document Preview (Middle Panel):**
- View selected documents
- Download files or open in browser
- PDF files display inline, others show download options

**Search Results (Right Panel):**
- Search by filename or content
- Click on results to preview documents
- Clear search with the X button

### 4. Search Features

**Search Types:**
- **Filename search**: Find files by name (e.g., "contract", "report")
- **Content search**: Find text inside documents (e.g., "project timeline")
- **Combined search**: Results show both filename and content matches

**Search Tips:**
- Minimum 2 characters required
- Search is case-insensitive
- Use specific terms for better results
- Content search requires documents to be indexed first

## 🛠️ Troubleshooting

### Common Issues

#### 1. Application Not Loading
```bash
# Check if services are running
sudo supervisorctl status

# Restart services
sudo supervisorctl restart all
```

#### 2. Search Not Working
```bash
# Re-index documents
curl -X POST http://localhost:8001/api/files/index

# Check MongoDB
sudo systemctl status mongod
```

#### 3. File Access Issues
```bash
# Check document directory permissions
ls -la /var/www/html/pdf/
sudo chown -R www-data:www-data /var/www/html/pdf/
sudo chmod -R 755 /var/www/html/pdf/
```

### Log Locations
- **Backend logs**: `/var/log/supervisor/backend.*.log`
- **Frontend logs**: `/var/log/supervisor/frontend.*.log`

## API Endpoints

- `GET /api/` - Health check
- `GET /api/files/tree` - Get file/folder structure
- `GET /api/files/serve/{path}` - Serve document files
- `POST /api/files/index` - Index all documents for search
- `GET /api/search?q={query}` - Search documents by name and content

## 📊 Supported File Formats

| Format | Extension | Icon | Preview | Content Search |
|--------|-----------|------|---------|----------------|
| PDF | .pdf | 📄 | ✅ Inline | ✅ Yes |
| Excel | .xlsx, .xls | 📊 | ❌ Download | ✅ Yes |
| Word | .docx, .doc | 📝 | ❌ Download | ✅ Yes |
| RTF | .rtf | 📝 | ❌ Download | ✅ Yes |
| Text | .txt | 📃 | ❌ Download | ✅ Yes |

## 🔐 Security Notes

- Documents are served directly from the filesystem
- No authentication is currently implemented
- Consider implementing access controls for production use
- Use HTTPS in production environments

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes and test thoroughly
4. Submit a pull request with detailed description

## 📄 License

MIT License - see LICENSE file for details.

---

**Made with ❤️ for efficient document management**
