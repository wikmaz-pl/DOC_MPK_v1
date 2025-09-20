from fastapi import FastAPI, APIRouter, HTTPException
from fastapi.responses import FileResponse
from dotenv import load_dotenv
from starlette.middleware.cors import CORSMiddleware
from motor.motor_asyncio import AsyncIOMotorClient
import os
import logging
from pathlib import Path
from pydantic import BaseModel, Field
from typing import List, Optional, Dict, Any
import uuid
from datetime import datetime
import PyPDF2
import asyncio
import aiofiles

ROOT_DIR = Path(__file__).parent
load_dotenv(ROOT_DIR / '.env')

# MongoDB connection
mongo_url = os.environ['MONGO_URL']
client = AsyncIOMotorClient(mongo_url)
db = client[os.environ['DB_NAME']]

# Create the main app without a prefix
app = FastAPI()

# Create a router with the /api prefix
api_router = APIRouter(prefix="/api")

# PDF base path
PDF_BASE_PATH = Path("/var/www/html/pdf")

# Models
class FileItem(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    name: str
    path: str
    type: str  # 'file' or 'folder'
    size: Optional[int] = None
    modified: Optional[datetime] = None
    parent_path: str

class SearchResult(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    file_path: str
    file_name: str
    content_match: Optional[str] = None
    match_type: str  # 'filename' or 'content'

class IndexedFile(BaseModel):
    id: str = Field(default_factory=lambda: str(uuid.uuid4()))
    file_path: str
    file_name: str
    content: str
    indexed_at: datetime = Field(default_factory=lambda: datetime.now())

# Utility functions
def get_file_info(file_path: Path) -> Dict[str, Any]:
    """Get file information"""
    try:
        stat = file_path.stat()
        return {
            "name": file_path.name,
            "path": str(file_path),
            "type": "folder" if file_path.is_dir() else "file",
            "size": stat.st_size if file_path.is_file() else None,
            "modified": datetime.fromtimestamp(stat.st_mtime),
            "parent_path": str(file_path.parent)
        }
    except Exception as e:
        logger.error(f"Error getting file info for {file_path}: {e}")
        return None

async def extract_pdf_text(file_path: Path) -> str:
    """Extract text content from PDF"""
    try:
        text = ""
        async with aiofiles.open(file_path, 'rb') as file:
            content = await file.read()
            
        # Use PyPDF2 to extract text
        import io
        pdf_reader = PyPDF2.PdfReader(io.BytesIO(content))
        
        for page in pdf_reader.pages:
            text += page.extract_text() + "\n"
            
        return text.strip()
    except Exception as e:
        logger.error(f"Error extracting text from {file_path}: {e}")
        return ""

# API Routes
@api_router.get("/")
async def root():
    return {"message": "PDF Search System API"}

@api_router.get("/files/tree")
async def get_file_tree(path: str = ""):
    """Get folder structure and files"""
    try:
        current_path = PDF_BASE_PATH / path if path else PDF_BASE_PATH
        
        if not current_path.exists():
            raise HTTPException(status_code=404, detail="Path not found")
        
        items = []
        
        # Get all items in current directory
        try:
            for item_path in sorted(current_path.iterdir()):
                if item_path.name.startswith('.'):
                    continue
                    
                file_info = get_file_info(item_path)
                if file_info:
                    # For relative path calculation
                    relative_path = str(item_path.relative_to(PDF_BASE_PATH))
                    file_info["path"] = relative_path
                    file_info["parent_path"] = str(item_path.parent.relative_to(PDF_BASE_PATH)) if item_path.parent != PDF_BASE_PATH else ""
                    
                    items.append(FileItem(**file_info))
                    
        except PermissionError:
            raise HTTPException(status_code=403, detail="Permission denied")
            
        return {"items": items, "current_path": path}
        
    except Exception as e:
        logger.error(f"Error getting file tree: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/files/serve/{file_path:path}")
async def serve_pdf(file_path: str):
    """Serve PDF file for preview"""
    try:
        full_path = PDF_BASE_PATH / file_path
        
        if not full_path.exists() or not full_path.is_file():
            raise HTTPException(status_code=404, detail="File not found")
            
        if not full_path.suffix.lower() == '.pdf':
            raise HTTPException(status_code=400, detail="Only PDF files are supported")
            
        return FileResponse(
            path=str(full_path),
            media_type='application/pdf',
            filename=full_path.name
        )
        
    except Exception as e:
        logger.error(f"Error serving file {file_path}: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.post("/files/index")
async def index_pdfs():
    """Index all PDF files for content search"""
    try:
        indexed_count = 0
        
        # Clear existing index
        await db.indexed_files.delete_many({})
        
        # Walk through all PDF files
        for pdf_path in PDF_BASE_PATH.rglob("*.pdf"):
            try:
                # Extract text content
                content = await extract_pdf_text(pdf_path)
                
                if content:
                    # Store in database
                    indexed_file = IndexedFile(
                        file_path=str(pdf_path.relative_to(PDF_BASE_PATH)),
                        file_name=pdf_path.name,
                        content=content
                    )
                    
                    await db.indexed_files.insert_one(indexed_file.dict())
                    indexed_count += 1
                    
                    logger.info(f"Indexed: {pdf_path.name}")
                    
            except Exception as e:
                logger.error(f"Error indexing {pdf_path}: {e}")
                continue
                
        return {"message": f"Indexed {indexed_count} PDF files"}
        
    except Exception as e:
        logger.error(f"Error during indexing: {e}")
        raise HTTPException(status_code=500, detail=str(e))

@api_router.get("/search")
async def search_files(q: str, limit: int = 50):
    """Search files by name and content"""
    try:
        if not q or len(q.strip()) < 2:
            return {"results": []}
            
        search_term = q.strip().lower()
        results = []
        
        # Search by filename
        for pdf_path in PDF_BASE_PATH.rglob("*.pdf"):
            if search_term in pdf_path.name.lower():
                results.append(SearchResult(
                    file_path=str(pdf_path.relative_to(PDF_BASE_PATH)),
                    file_name=pdf_path.name,
                    match_type="filename"
                ))
        
        # Search by content in indexed files
        content_matches = await db.indexed_files.find({
            "content": {"$regex": search_term, "$options": "i"}
        }).to_list(limit)
        
        for match in content_matches:
            # Extract snippet around match
            content = match.get("content", "")
            lower_content = content.lower()
            match_index = lower_content.find(search_term)
            
            if match_index >= 0:
                start = max(0, match_index - 100)
                end = min(len(content), match_index + 100)
                snippet = content[start:end]
                
                # Check if already in results (from filename search)
                existing = next((r for r in results if r.file_path == match["file_path"]), None)
                if existing:
                    existing.content_match = f"...{snippet}..."
                    existing.match_type = "both"
                else:
                    results.append(SearchResult(
                        file_path=match["file_path"],
                        file_name=match["file_name"],
                        content_match=f"...{snippet}...",
                        match_type="content"
                    ))
        
        # Limit results
        results = results[:limit]
        
        return {"results": results, "total": len(results)}
        
    except Exception as e:
        logger.error(f"Error searching: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# Include the router in the main app
app.include_router(api_router)

app.add_middleware(
    CORSMiddleware,
    allow_credentials=True,
    allow_origins=os.environ.get('CORS_ORIGINS', '*').split(','),
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure logging
logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)

@app.on_event("shutdown")
async def shutdown_db_client():
    client.close()