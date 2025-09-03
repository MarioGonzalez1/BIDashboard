import json
import os
from datetime import datetime, timedelta, timezone
from fastapi import FastAPI, HTTPException, File, UploadFile, Form, Depends, status
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from typing import List, Dict, Any, Optional
from passlib.context import CryptContext
from jose import JWTError, jwt
from pydantic import BaseModel

# --- CONFIGURACIÓN ---
DB_FILE = "db.json"
STATIC_DIR = "static"
IMAGES_DIR = os.path.join(STATIC_DIR, "images")

# JWT Configuration
SECRET_KEY = "your-secret-key-here-change-in-production"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30

# Password hashing
pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Security
security = HTTPBearer()

# Crear directorios si no existen
os.makedirs(IMAGES_DIR, exist_ok=True)

# --- MODELOS PYDANTIC ---
class UserLogin(BaseModel):
    username: str
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class User(BaseModel):
    username: str
    hashed_password: str
    is_admin: bool = False

app = FastAPI(title="BI Dashboard Portal API")

# --- MIDDLEWARE (CORS) ---
# Permite que Angular se comunique con este backend.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:4200"], # Solo permite peticiones desde Angular en desarrollo
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- SERVIR ARCHIVOS ESTÁTICOS ---
# Hace que las imágenes guardadas sean accesibles desde el navegador
app.mount(f"/{STATIC_DIR}", StaticFiles(directory=STATIC_DIR), name=STATIC_DIR)

# --- FUNCIONES AUXILIARES PARA LA BASE DE DATOS JSON ---
def read_db() -> Dict[str, List[Dict[str, Any]]]:
    if not os.path.exists(DB_FILE):
        return {"tableros": []}
    with open(DB_FILE, "r") as f:
        try:
            return json.load(f)
        except json.JSONDecodeError:
            return {"tableros": []}

def write_db(data: Dict[str, List[Dict[str, Any]]]):
    with open(DB_FILE, "w") as f:
        json.dump(data, f, indent=4)

# --- FUNCIONES DE AUTENTICACIÓN ---
def hash_password(password: str) -> str:
    return pwd_context.hash(password)

def verify_password(plain_password: str, hashed_password: str) -> bool:
    return pwd_context.verify(plain_password, hashed_password)

def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.now(timezone.utc) + expires_delta
    else:
        expire = datetime.now(timezone.utc) + timedelta(minutes=15)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt

def get_user_from_db(username: str) -> Optional[Dict]:
    db = read_db()
    users = db.get("users", [])
    for user in users:
        if user["username"] == username:
            return user
    return None

def authenticate_user(username: str, password: str) -> Optional[Dict]:
    user = get_user_from_db(username)
    if not user:
        return None
    if not verify_password(password, user["hashed_password"]):
        return None
    return user

def verify_token(credentials: HTTPAuthorizationCredentials = Depends(security)) -> str:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        username: str = payload.get("sub")
        if username is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Could not validate credentials",
                headers={"WWW-Authenticate": "Bearer"},
            )
        return username
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

def get_current_user(username: str = Depends(verify_token)) -> Dict:
    user = get_user_from_db(username)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    return user

def get_current_admin_user(current_user: Dict = Depends(get_current_user)) -> Dict:
    if not current_user.get("is_admin", False):
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user

# --- ENDPOINTS DE LA API ---

@app.post("/api/login", response_model=Token)
async def login(user_login: UserLogin):
    user = authenticate_user(user_login.username, user_login.password)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user["username"]}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/register")
async def register(user_login: UserLogin):
    db = read_db()
    if "users" not in db:
        db["users"] = []
    
    if get_user_from_db(user_login.username):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    
    hashed_password = hash_password(user_login.password)
    new_user = {
        "username": user_login.username,
        "hashed_password": hashed_password,
        "is_admin": user_login.username == "admin"  # First user named 'admin' gets admin rights
    }
    
    db["users"].append(new_user)
    write_db(db)
    
    return {"message": "User registered successfully"}

@app.get("/api/tableros", response_model=List[Dict[str, Any]])
def get_all_tableros(current_user: Dict = Depends(get_current_user)):
    db = read_db()
    # Asegurarse de que la URL de la imagen es accesible para el frontend
    for tablero in db["tableros"]:
        tablero["url_imagen_preview"] = f"http://127.0.0.1:8000{tablero['url_imagen_preview']}"
    return db["tableros"]

@app.post("/api/tableros")
async def create_tablero(
    titulo: str = Form(...),
    url_acceso: str = Form(...),
    categoria: str = Form(...),
    subcategoria: str = Form(""),
    descripcion: str = Form(""),
    screenshot: UploadFile = File(...),
    current_user: Dict = Depends(get_current_user)
):
    db = read_db()
    
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    safe_filename = "".join(c for c in screenshot.filename if c.isalnum() or c in ('.', '_')).rstrip()
    image_filename = f"{timestamp}_{safe_filename}"
    image_path = os.path.join(IMAGES_DIR, image_filename)
    
    with open(image_path, "wb") as buffer:
        buffer.write(await screenshot.read())
        
    new_id = max([t["id"] for t in db["tableros"]]) + 1 if db["tableros"] else 1
    
    new_tablero = {
        "id": new_id,
        "titulo": titulo,
        "url_acceso": url_acceso,
        "categoria": categoria,
        "subcategoria": subcategoria,
        "descripcion": descripcion,
        "url_imagen_preview": f"/{STATIC_DIR}/images/{image_filename}"
    }
    
    db["tableros"].append(new_tablero)
    write_db(db)
    
    new_tablero["url_imagen_preview"] = f"http://127.0.0.1:8000{new_tablero['url_imagen_preview']}"
    return new_tablero

@app.put("/api/tableros/{tablero_id}")
async def update_tablero(
    tablero_id: int,
    titulo: str = Form(...),
    url_acceso: str = Form(...),
    categoria: str = Form(...),
    subcategoria: str = Form(""),
    descripcion: str = Form(""),
    screenshot: UploadFile = File(None),
    current_user: Dict = Depends(get_current_user)
):
    db = read_db()
    
    # Find the dashboard to update
    tablero_to_update = None
    for i, tablero in enumerate(db["tableros"]):
        if tablero["id"] == tablero_id:
            tablero_to_update = db["tableros"][i]
            break
    
    if not tablero_to_update:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dashboard not found"
        )
    
    # Update basic fields
    tablero_to_update["titulo"] = titulo
    tablero_to_update["url_acceso"] = url_acceso
    tablero_to_update["categoria"] = categoria
    tablero_to_update["subcategoria"] = subcategoria
    tablero_to_update["descripcion"] = descripcion
    
    # Update screenshot if provided
    if screenshot and screenshot.filename:
        # Delete old image file
        old_image_path = tablero_to_update["url_imagen_preview"].replace("/static/images/", "")
        old_full_path = os.path.join(IMAGES_DIR, old_image_path)
        if os.path.exists(old_full_path):
            os.remove(old_full_path)
        
        # Save new image
        timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
        safe_filename = "".join(c for c in screenshot.filename if c.isalnum() or c in ('.', '_')).rstrip()
        image_filename = f"{timestamp}_{safe_filename}"
        image_path = os.path.join(IMAGES_DIR, image_filename)
        
        with open(image_path, "wb") as buffer:
            buffer.write(await screenshot.read())
        
        tablero_to_update["url_imagen_preview"] = f"/{STATIC_DIR}/images/{image_filename}"
    
    write_db(db)
    
    # Return with full URL
    tablero_to_update["url_imagen_preview"] = f"http://127.0.0.1:8000{tablero_to_update['url_imagen_preview']}"
    return tablero_to_update

@app.delete("/api/tableros/{tablero_id}")
def delete_tablero(
    tablero_id: int,
    current_admin: Dict = Depends(get_current_admin_user)
):
    db = read_db()
    
    # Find and remove the dashboard
    tablero_to_delete = None
    for i, tablero in enumerate(db["tableros"]):
        if tablero["id"] == tablero_id:
            tablero_to_delete = db["tableros"].pop(i)
            break
    
    if not tablero_to_delete:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dashboard not found"
        )
    
    # Delete associated image file
    image_path = tablero_to_delete["url_imagen_preview"].replace("/static/images/", "")
    full_path = os.path.join(IMAGES_DIR, image_path)
    if os.path.exists(full_path):
        os.remove(full_path)
    
    write_db(db)
    return {"message": "Dashboard deleted successfully"}