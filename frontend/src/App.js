import React, { useState, useEffect, useCallback } from 'react';
import axios from 'axios';
import './App.css';

const BACKEND_URL = process.env.REACT_APP_BACKEND_URL;
const API = `${BACKEND_URL}/api`;

const App = () => {
  const [currentPath, setCurrentPath] = useState('');
  const [fileTree, setFileTree] = useState([]);
  const [selectedFile, setSelectedFile] = useState(null);
  const [searchQuery, setSearchQuery] = useState('');
  const [searchResults, setSearchResults] = useState([]);
  const [isSearching, setIsSearching] = useState(false);
  const [isIndexing, setIsIndexing] = useState(false);
  const [loading, setLoading] = useState(false);
  const [expandedFolders, setExpandedFolders] = useState(new Set());

  // Load file tree
  const loadFileTree = useCallback(async (path = '') => {
    setLoading(true);
    try {
      const response = await axios.get(`${API}/files/tree?path=${encodeURIComponent(path)}`);
      setFileTree(response.data.items);
      setCurrentPath(response.data.current_path);
    } catch (error) {
      console.error('Error loading file tree:', error);
    } finally {
      setLoading(false);
    }
  }, []);

  // Search files
  const searchFiles = useCallback(async (query) => {
    if (!query || query.length < 2) {
      setSearchResults([]);
      return;
    }

    setIsSearching(true);
    try {
      const response = await axios.get(`${API}/search?q=${encodeURIComponent(query)}&limit=50`);
      setSearchResults(response.data.results);
    } catch (error) {
      console.error('Error searching files:', error);
      setSearchResults([]);
    } finally {
      setIsSearching(false);
    }
  }, []);

  // Debounced search
  useEffect(() => {
    const timer = setTimeout(() => {
      if (searchQuery) {
        searchFiles(searchQuery);
      } else {
        setSearchResults([]);
      }
    }, 300);

    return () => clearTimeout(timer);
  }, [searchQuery, searchFiles]);

  // Index PDFs
  const indexPDFs = async () => {
    setIsIndexing(true);
    try {
      await axios.post(`${API}/files/index`);
      alert('PDF indexing completed! Content search is now available.');
    } catch (error) {
      console.error('Error indexing PDFs:', error);
      alert('Error indexing PDFs. Please check the console.');
    } finally {
      setIsIndexing(false);
    }
  };

  // Handle folder click
  const handleFolderClick = (folderPath) => {
    if (expandedFolders.has(folderPath)) {
      setExpandedFolders(prev => {
        const newSet = new Set(prev);
        newSet.delete(folderPath);
        return newSet;
      });
    } else {
      setExpandedFolders(prev => new Set([...prev, folderPath]));
      loadFileTree(folderPath);
    }
  };

  // Get file icon based on extension
  const getFileIcon = (fileName) => {
    const extension = fileName.toLowerCase().split('.').pop();
    const iconMap = {
      'pdf': '📄',
      'xlsx': '📊',
      'xls': '📊', 
      'docx': '📝',
      'doc': '📝',
      'rtf': '📝',
      'txt': '📃'
    };
    return iconMap[extension] || '📄';
  };

  // Check if file is supported
  const isSupportedFile = (fileName) => {
    const extension = fileName.toLowerCase().split('.').pop();
    return ['pdf', 'xlsx', 'xls', 'docx', 'doc', 'rtf', 'txt'].includes(extension);
  };

  // Handle file selection
  const handleFileSelect = (file) => {
    console.log('File selected:', file);
    if (file.type === 'file' && isSupportedFile(file.name)) {
      console.log('Setting selected file:', file);
      setSelectedFile(file);
    } else {
      console.log('File is not supported or is not a file type');
    }
  };

  // Load initial file tree
  useEffect(() => {
    loadFileTree();
  }, [loadFileTree]);

  const renderFileTree = (items, level = 0) => {
    return items
      .sort((a, b) => {
        // Folders first, then files
        if (a.type !== b.type) {
          return a.type === 'folder' ? -1 : 1;
        }
        return a.name.localeCompare(b.name);
      })
      .map((item) => (
        <div key={item.id} className={`file-item level-${level}`}>
          <div
            className={`file-item-content ${item.type === 'folder' ? 'folder' : 'file'} ${
              selectedFile?.id === item.id ? 'selected' : ''
            }`}
            onClick={() => item.type === 'folder' ? handleFolderClick(item.path) : handleFileSelect(item)}
          >
            <span className="file-icon">
              {item.type === 'folder' ? 
                (expandedFolders.has(item.path) ? '📂' : '📁') : 
                getFileIcon(item.name)
              }
            </span>
            <span className="file-name">{item.name}</span>
            {item.type === 'file' && item.size && (
              <span className="file-size">
                {(item.size / 1024).toFixed(1)}KB
              </span>
            )}
          </div>
        </div>
      ));
  };

  const renderSearchResults = () => {
    if (!searchQuery) return null;

    return (
      <div className="search-results">
        <div className="search-header">
          <h3>Search Results ({searchResults.length})</h3>
          {isSearching && <div className="loading-spinner">🔍</div>}
        </div>
        {searchResults.length === 0 && !isSearching && searchQuery.length >= 2 && (
          <div className="no-results">No files found matching "{searchQuery}"</div>
        )}
        {searchResults.map((result) => (
          <div
            key={result.id}
            className={`search-result-item ${selectedFile?.path === result.file_path ? 'selected' : ''}`}
            onClick={() => {
              // Create proper file object for search results
              const fileObj = {
                id: result.id,
                name: result.file_name,
                path: result.file_path,
                type: 'file'
              };
              console.log('Selecting file from search:', fileObj);
              handleFileSelect(fileObj);
            }}
          >
            <div className="result-filename">{getFileIcon(result.file_name)} {result.file_name}</div>
            <div className="result-path">{result.file_path}</div>
            {result.content_match && (
              <div className="result-snippet">
                {result.content_match}
              </div>
            )}
            <div className="result-type">
              Match: {result.match_type === 'both' ? 'Filename & Content' : 
                     result.match_type === 'filename' ? 'Filename' : 'Content'}
            </div>
          </div>
        ))}
      </div>
    );
  };

  return (
    <div className="app">
      {/* Header with Search */}
      <header className="app-header">
        <div className="header-content">
          <h1 className="app-title">📚 PDF Search System</h1>
          <div className="search-container">
            <input
              type="text"
              className="search-input"
              placeholder="Search files by name or content..."
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
            {isSearching && <div className="search-loading">🔍</div>}
          </div>
          <button 
            className="index-button"
            onClick={indexPDFs}
            disabled={isIndexing}
          >
            {isIndexing ? '⏳ Indexing...' : '🔄 Index PDFs'}
          </button>
        </div>
      </header>

      {/* Main Content */}
      <div className="main-content">
        {/* Left Panel - PDF Preview */}
        <div className="left-panel">
          {selectedFile ? (
            <div className="pdf-preview">
              <div className="preview-header">
                <h3>📄 {selectedFile.name}</h3>
                <div className="preview-path">{selectedFile.path}</div>
              </div>
              <div className="pdf-viewer">
                <iframe
                  src={`${API}/files/serve/${encodeURIComponent(selectedFile.path)}#toolbar=1&navpanes=1&scrollbar=1`}
                  title={selectedFile.name}
                  width="100%"
                  height="100%"
                  frameBorder="0"
                  onLoad={() => console.log('PDF iframe loaded')}
                  onError={() => console.log('PDF iframe error')}
                />
                <div className="pdf-fallback">
                  <p>PDF not displaying properly? 
                    <a 
                      href={`${API}/files/serve/${encodeURIComponent(selectedFile.path)}`}
                      target="_blank"
                      rel="noopener noreferrer"
                      className="pdf-link"
                    >
                      Open PDF in new tab
                    </a>
                  </p>
                </div>
              </div>
            </div>
          ) : (
            <div className="no-selection">
              <div className="no-selection-content">
                <h2>🔍 PDF Search System</h2>
                <p>Select a PDF file from the right panel to preview it here</p>
                <div className="instructions">
                  <h3>How to use:</h3>
                  <ul>
                    <li>🔍 Use the search bar to find files by name or content</li>
                    <li>📁 Click folders on the right to expand them</li>
                    <li>📄 Click PDF files to preview them here</li>
                    <li>🔄 Click "Index PDFs" to enable content search</li>
                  </ul>
                </div>
              </div>
            </div>
          )}
        </div>

        {/* Right Panel - File Browser */}
        <div className="right-panel">
          {searchQuery ? renderSearchResults() : (
            <div className="file-browser">
              <div className="browser-header">
                <h3>📁 File Browser</h3>
                {currentPath && (
                  <div className="current-path">
                    📍 {currentPath || 'Root'}
                  </div>
                )}
                {loading && <div className="loading-spinner">⏳</div>}
              </div>
              
              {currentPath && (
                <div className="navigation">
                  <button 
                    className="nav-button"
                    onClick={() => {
                      const parentPath = currentPath.split('/').slice(0, -1).join('/');
                      loadFileTree(parentPath);
                    }}
                  >
                    ⬆️ Back
                  </button>
                </div>
              )}

              <div className="file-tree">
                {renderFileTree(fileTree)}
              </div>
            </div>
          )}
        </div>
      </div>
    </div>
  );
};

export default App;