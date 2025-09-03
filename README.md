# BIDashboard

Portal de Business Intelligence con dashboard centralizado para visualización de datos y reportes.

## 🏗️ Arquitectura

- **Frontend**: Angular 20.2.x con TypeScript
- **Backend**: Python FastAPI con autenticación JWT
- **Base de Datos**: JSON file-based storage
- **Imágenes**: Sistema de upload con preview

## 🚀 Instalación y Configuración

### Prerequisites
- Node.js 18+
- Python 3.8+
- Angular CLI

### Backend Setup
```bash
cd backend
python -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate
pip install fastapi uvicorn python-multipart passlib bcrypt python-jose
uvicorn main:app --reload
```

### Frontend Setup
```bash
cd frontend
npm install
ng serve
```

## 🔧 Uso

1. Inicia el backend en `http://localhost:8000`
2. Inicia el frontend en `http://localhost:4200`
3. Registra un usuario admin para gestionar tableros
4. Sube y gestiona tus dashboards

## 📁 Estructura del Proyecto

```
BIDashboard/
├── backend/          # API FastAPI
│   ├── main.py      # Servidor principal
│   ├── db.json      # Base de datos
│   └── static/      # Archivos subidos
├── frontend/        # Angular App
│   ├── src/         # Código fuente
│   └── public/      # Assets estáticos
└── README.md        # Este archivo
```

## 🔐 Características

- ✅ Autenticación JWT
- ✅ Upload de imágenes
- ✅ CRUD completo de tableros
- ✅ Categorización
- ✅ Preview de dashboards
- ✅ Control de acceso admin

## 🛠️ Desarrollo

El proyecto usa Angular CLI y FastAPI con hot-reload habilitado para desarrollo rápido.
