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
from sqlalchemy.orm import Session
from database_postgres import get_db, User, Dashboard, Employee

# --- CONFIGURACIÓN ---
STATIC_DIR = "static"
IMAGES_DIR = os.path.join(STATIC_DIR, "images")

# JWT Configuration
SECRET_KEY = os.getenv("SECRET_KEY", "your-secret-key-here-change-in-production")
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

app = FastAPI(title="BI Dashboard Portal API - PostgreSQL Edition")

# --- MIDDLEWARE (CORS) ---
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:4200",  # Development
        "http://localhost:4201",  # Alternative port
        "https://*.azurewebsites.net",  # Azure App Service
        os.getenv("FRONTEND_URL", "http://localhost:4200")  # Production URL
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- SERVIR ARCHIVOS ESTÁTICOS ---
app.mount(f"/{STATIC_DIR}", StaticFiles(directory=STATIC_DIR), name=STATIC_DIR)

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

def get_user_from_db(username: str, db: Session) -> Optional[User]:
    return db.query(User).filter(User.username == username).first()

def authenticate_user(username: str, password: str, db: Session) -> Optional[User]:
    user = get_user_from_db(username, db)
    if not user:
        return None
    if not verify_password(password, user.hashed_password):
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

def get_current_user(username: str = Depends(verify_token), db: Session = Depends(get_db)) -> User:
    user = get_user_from_db(username, db)
    if user is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="User not found"
        )
    return user

def get_current_admin_user(current_user: User = Depends(get_current_user)) -> User:
    if not current_user.is_admin:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required"
        )
    return current_user

# --- ENDPOINTS DE LA API ---

@app.post("/api/login", response_model=Token)
async def login(user_login: UserLogin, db: Session = Depends(get_db)):
    user = authenticate_user(user_login.username, user_login.password, db)
    if not user:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect username or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/api/register")
async def register(user_login: UserLogin, db: Session = Depends(get_db)):
    if get_user_from_db(user_login.username, db):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Username already registered"
        )
    
    hashed_password = hash_password(user_login.password)
    new_user = User(
        username=user_login.username,
        hashed_password=hashed_password,
        is_admin=(user_login.username == "admin")  # First user named 'admin' gets admin rights
    )
    
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    
    return {"message": "User registered successfully"}

@app.get("/api/tableros", response_model=List[Dict[str, Any]])
def get_all_tableros(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    dashboards = db.query(Dashboard).all()
    tableros = []
    for dashboard in dashboards:
        tablero = {
            "id": dashboard.id,
            "titulo": dashboard.titulo,
            "url_acceso": dashboard.url_acceso,
            "categoria": dashboard.categoria,
            "subcategoria": dashboard.subcategoria or "",
            "descripcion": dashboard.descripcion or "",
            "url_imagen_preview": f"http://127.0.0.1:8000{dashboard.url_imagen_preview}" if dashboard.url_imagen_preview else ""
        }
        tableros.append(tablero)
    return tableros

@app.post("/api/tableros")
async def create_tablero(
    titulo: str = Form(...),
    url_acceso: str = Form(...),
    categoria: str = Form(...),
    subcategoria: str = Form(""),
    descripcion: str = Form(""),
    screenshot: UploadFile = File(...),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    timestamp = datetime.now().strftime("%Y%m%d%H%M%S")
    safe_filename = "".join(c for c in screenshot.filename if c.isalnum() or c in ('.', '_')).rstrip()
    image_filename = f"{timestamp}_{safe_filename}"
    image_path = os.path.join(IMAGES_DIR, image_filename)
    
    with open(image_path, "wb") as buffer:
        buffer.write(await screenshot.read())
    
    new_dashboard = Dashboard(
        titulo=titulo,
        url_acceso=url_acceso,
        categoria=categoria,
        subcategoria=subcategoria,
        descripcion=descripcion,
        url_imagen_preview=f"/{STATIC_DIR}/images/{image_filename}",
        created_by=current_user.id
    )
    
    db.add(new_dashboard)
    db.commit()
    db.refresh(new_dashboard)
    
    return {
        "id": new_dashboard.id,
        "titulo": new_dashboard.titulo,
        "url_acceso": new_dashboard.url_acceso,
        "categoria": new_dashboard.categoria,
        "subcategoria": new_dashboard.subcategoria,
        "descripcion": new_dashboard.descripcion,
        "url_imagen_preview": f"http://127.0.0.1:8000{new_dashboard.url_imagen_preview}"
    }

@app.put("/api/tableros/{tablero_id}")
async def update_tablero(
    tablero_id: int,
    titulo: str = Form(...),
    url_acceso: str = Form(...),
    categoria: str = Form(...),
    subcategoria: str = Form(""),
    descripcion: str = Form(""),
    screenshot: UploadFile = File(None),
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    dashboard = db.query(Dashboard).filter(Dashboard.id == tablero_id).first()
    if not dashboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dashboard not found"
        )
    
    # Update basic fields
    dashboard.titulo = titulo
    dashboard.url_acceso = url_acceso
    dashboard.categoria = categoria
    dashboard.subcategoria = subcategoria
    dashboard.descripcion = descripcion
    
    # Update screenshot if provided
    if screenshot and screenshot.filename:
        # Delete old image file
        if dashboard.url_imagen_preview:
            old_image_path = dashboard.url_imagen_preview.replace(f"/{STATIC_DIR}/images/", "")
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
        
        dashboard.url_imagen_preview = f"/{STATIC_DIR}/images/{image_filename}"
    
    db.commit()
    db.refresh(dashboard)
    
    return {
        "id": dashboard.id,
        "titulo": dashboard.titulo,
        "url_acceso": dashboard.url_acceso,
        "categoria": dashboard.categoria,
        "subcategoria": dashboard.subcategoria,
        "descripcion": dashboard.descripcion,
        "url_imagen_preview": f"http://127.0.0.1:8000{dashboard.url_imagen_preview}" if dashboard.url_imagen_preview else ""
    }

@app.delete("/api/tableros/{tablero_id}")
def delete_tablero(
    tablero_id: int,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    dashboard = db.query(Dashboard).filter(Dashboard.id == tablero_id).first()
    if not dashboard:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Dashboard not found"
        )
    
    # Delete associated image file
    if dashboard.url_imagen_preview:
        image_path = dashboard.url_imagen_preview.replace(f"/{STATIC_DIR}/images/", "")
        full_path = os.path.join(IMAGES_DIR, image_path)
        if os.path.exists(full_path):
            os.remove(full_path)
    
    db.delete(dashboard)
    db.commit()
    
    return {"message": "Dashboard deleted successfully"}

# --- EMPLOYEE ENDPOINTS ---
@app.get("/api/employees")
def get_employees(current_user: User = Depends(get_current_user), db: Session = Depends(get_db)):
    employees = db.query(Employee).all()
    return [
        {
            "id": emp.id,
            "firstName": emp.first_name,
            "lastName": emp.last_name,
            "email": emp.email,
            "phone": emp.phone,
            "department": emp.department,
            "position": emp.position,
            "salary": emp.salary,
            "hireDate": emp.hire_date.isoformat(),
            "status": emp.status
        }
        for emp in employees
    ]

@app.post("/api/employees")
def create_employee(
    employee_data: dict,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    new_employee = Employee(
        first_name=employee_data["firstName"],
        last_name=employee_data["lastName"],
        email=employee_data["email"],
        phone=employee_data.get("phone"),
        department=employee_data["department"],
        position=employee_data["position"],
        salary=employee_data["salary"],
        hire_date=datetime.fromisoformat(employee_data["hireDate"].replace("Z", "+00:00")),
        status=employee_data.get("status", "active"),
        created_by=current_user.id
    )
    
    db.add(new_employee)
    db.commit()
    db.refresh(new_employee)
    
    return {"message": "Employee created successfully", "id": new_employee.id}

@app.delete("/api/employees/{employee_id}")
def delete_employee(
    employee_id: int,
    current_admin: User = Depends(get_current_admin_user),
    db: Session = Depends(get_db)
):
    employee = db.query(Employee).filter(Employee.id == employee_id).first()
    if not employee:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Employee not found"
        )
    
    db.delete(employee)
    db.commit()
    
    return {"message": "Employee deleted successfully"}