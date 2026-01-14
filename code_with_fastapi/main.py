from fastapi import FastAPI, UploadFile, File, HTTPException, Body, Header, Depends
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
from typing import List, Dict, Any, Optional
import json
import os
import shutil
import hashlib
import uuid
import uvicorn

app = FastAPI()

# ==========================================
# 1. CONFIGURATION
# ==========================================

ORIGINS = ["*"]

app.add_middleware(
    CORSMiddleware,
    allow_origins=ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

DATA_FILE = "database.json"
ADMIN_FILE = "admin.json"
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

app.mount("/uploads", StaticFiles(directory=UPLOAD_DIR), name="uploads")

active_tokens = set()

# ==========================================
# 2. DEFAULT DATA (YOUR CV SEED)
# ==========================================
# This data is used only if database.json does not exist.
DEFAULT_DATA = {
    "personal": {
        "name": "Assami BAGA",
        "title": "Ingénieur IA & Full Stack",
        "availability": "Disponible dès octobre 2026",
        "email": "bagaassami09@gmail.com",
        "phone": "07 53 49 67 71",
        "location": "Thiais (94320), Ile de france",
        "linkedin": "assami-baga",
        "social": "bagus_full_stack",
        "summary": "Étudiant en dernière année du cycle d'ingénieur en informatique à l'EILCO, je suis à la recherche active d'un CDI. Mon objectif est d'exploiter ma passion pour la technologie en participant à la conception et au développement d'applications de haute qualité.",
        "photoUrl": "",
        "cvUrl": ""
    },
    "softSkills": ["Polyvalence", "Efficacité", "Créativité", "Adaptabilité", "Collaboration", "Autonomie", "Curiosité"],
    "languages": ["Français", "Anglais"],
    "education": [
        { "degree": "Diplôme d'ingénieur en Ingénierie Logicielle et IA", "school": "EILCO, Calais, France", "date": "Depuis septembre 2023" },
        { "degree": "Certifications: PUPA, LCB-FT, HDS, ISO 27001", "school": "CDC Informatique, Bagneux", "date": "Jan 2025 - Déc 2025" },
        { "degree": "RGPD, Protection des données, Sécurité incendie", "school": "CDC Informatique, Bagneux", "date": "Jan 2024 - Déc 2024" },
        { "degree": "Technologie IP, SQL, Linux, Scripting Shell", "school": "Essitech, Ouagadougou", "date": "Juin 2023" },
        { "degree": "Licence en Ingénierie des Systèmes d'Information", "school": "ESI, Burkina Faso", "date": "Oct 2019 - Fév 2023" }
    ],
    "experience": [
        {
            "role": "Ingénieur Exploitation",
            "company": "CDC Informatique, Bagneux",
            "date": "Depuis septembre 2024",
            "tasks": ["Participer à un travail collaboratif", "Réalisation de PYMQCOPY", "Réalisation d'un Référentiel des Services Flux (en cours)"]
        },
        {
            "role": "Bénévolat (Accompagnement scolaire)",
            "company": "AFEV Calais",
            "date": "Sept 2023 - Sept 2024",
            "tasks": ["Accompagnement des jeunes en difficulté scolaire", "Création de lien dans les quartiers populaires"]
        },
        {
            "role": "Software Engineer",
            "company": "Orange & Smile, Ouagadougou",
            "date": "Sept 2022 - Sept 2023",
            "tasks": ["Développement d'un Système Intelligent de Conception des Produits", "Participation au développement de MySpace (Frontend)", "Participation au développement de BourseFondation (Backend)"]
        }
    ],
    "techSkills": [
        { "cat": "Dev Multiplateforme", "tools": "HTML, CSS, JS, TS, SASS, Bootstrap, Tailwind, WordPress, Flutter Flow, Java, Pygame, JavaFX, Angular, React, Kotlin, Docker" },
        { "cat": "API RESTFUL", "tools": "NodeJS, ExpressJS, Spring, FastAPI, Laravel, Keycloak, JWT, Postman, Git, Swagger" },
        { "cat": "Conception & Modeling", "tools": "UML, Merise, Scrum, Power AMC, Adobe XD, Figma, JSON, XML" },
        { "cat": "Data & AI", "tools": "CNN, RNN, TensorFlow, Scikit-learn, PyTorch, YOLO, Pandas, NumPy, Matplotlib, Power BI" },
        { "cat": "Databases", "tools": "MySQL, MariaDB, PostgreSQL, Oracle Database, SQL Server" },
        { "cat": "Languages", "tools": "C, Java, Javascript, Python, R, PHP, Kotlin, Bash, Arduino, VHDL" }
    ],
    "projects": [
        { "name": "Blue Attendance", "desc": "Liste de présence électronique via Bluetooth (App Mobile).", "tech": "Java, Xml, FastAPI, Android Studio", "link": "#" },
        { "name": "PNP+", "desc": "Système Intelligent de Conception des Produits et Promotions.", "tech": "Angular, Spring boot, SQL", "link": "#" },
        { "name": "Myspace", "desc": "Plateforme SaaS complète.", "tech": "React, Node.js, PostgreSQL", "link": "#" },
        { "name": "BourseFondation", "desc": "Plateforme SaaS complète.", "tech": "React, Node.js, PostgreSQL", "link": "#" },
        { "name": "UI Calculator", "desc": "Application web UI UX Design.", "tech": "HTML, CSS, SCSS", "link": "#" },
        { "name": "UI Keyboard", "desc": "Application web UI UX Design.", "tech": "HTML, CSS, SCSS", "link": "#" },
        { "name": "Projet IOT", "desc": "Plateforme SaaS complète IOT.", "tech": "React, Node.js, PostgreSQL", "link": "#" },
        { "name": "ESI Website", "desc": "Site web statique de l'ESI.", "tech": "HTML, CSS, Bootstrap", "link": "#" },
        { "name": "Checkers Game", "desc": "Jeu de dames en mode console.", "tech": "C, Linux", "link": "#" },
        { "name": "Todo List", "desc": "Todo-list avec auth et email verification.", "tech": "PHP, Laravel, Voyager", "link": "#" },
        { "name": "Technology Transfer", "desc": "Plateforme de transfert de technologies.", "tech": "HTML, CSS, Bootstrap, MySql", "link": "#" },
        { "name": "Spare", "desc": "Suivi budgétaire (synchro bancaire).", "tech": "React, Node.js, Firebase", "link": "#" },
        { "name": "PYMQCOPY", "desc": "Recopie de messages MQ source vers destinations.", "tech": "Python, MQ Series, Bash", "link": "#" }
    ],
    "certifications": [
        { "name": "C", "link": "#" }, { "name": "HTML", "link": "#" }, { "name": "CSS", "link": "#" },
        { "name": "Javascript", "link": "#" }, { "name": "Java", "link": "#" }, { "name": "PHP", "link": "#" },
        { "name": "SQL", "link": "#" }, { "name": "Python for Beginner", "link": "#" },
        { "name": "Python Data Structures", "link": "#" }, { "name": "Coding marketers", "link": "#" },
        { "name": "Responsive Web Design", "link": "#" }, { "name": "Intro référentiel HDS & ISO 27001", "link": "#" },
        { "name": "Sensibilisation PUPA", "link": "#" }, { "name": "Fondamentaux de la LCB-FT", "link": "#" },
        { "name": "RGPD - Protection données", "link": "#" }, { "name": "Classification et protection données", "link": "#" },
        { "name": "Déontologie code", "link": "#" }, { "name": "Evacuation et sécurité incendie", "link": "#" }
    ]
}

# ==========================================
# 3. UTILITIES & INITIALIZATION
# ==========================================

def initialize_database():
    """Create database.json with DEFAULT_DATA if it doesn't exist."""
    if not os.path.exists(DATA_FILE):
        print("⚡ No database found. Creating new database.json with default data...")
        with open(DATA_FILE, "w", encoding="utf-8") as f:
            json.dump(DEFAULT_DATA, f, indent=4, ensure_ascii=False)
    else:
        print("✅ Database found. Loading existing data.")

def get_admin_hash():
    default_hash = "240be518fabd2724ddb6f04eeb1da5967448d7e831c08c8fa822809f74c720a9" # admin123
    if not os.path.exists(ADMIN_FILE):
        with open(ADMIN_FILE, "w") as f:
            json.dump({"hash": default_hash}, f)
        return default_hash
    with open(ADMIN_FILE, "r") as f:
        data = json.load(f)
        return data.get("hash", default_hash)

def save_admin_hash(new_hash):
    with open(ADMIN_FILE, "w") as f:
        json.dump({"hash": new_hash}, f)

def hash_password(password: str):
    return hashlib.sha256(password.encode()).hexdigest()

def verify_token(x_token: str = Header(None)):
    if x_token not in active_tokens:
        raise HTTPException(status_code=401, detail="Invalid token")
    return x_token

class PortfolioData(BaseModel):
    personal: Dict[str, Any]
    softSkills: List[str]
    languages: List[str]
    education: List[Dict[str, Any]]
    experience: List[Dict[str, Any]]
    techSkills: List[Dict[str, Any]]
    projects: List[Dict[str, Any]]
    certifications: List[Dict[str, Any]]

class LoginRequest(BaseModel):
    password: str

class ChangePasswordRequest(BaseModel):
    old_password: str
    new_password: str

# ==========================================
# 4. ENDPOINTS
# ==========================================

@app.on_event("startup")
async def startup_event():
    initialize_database()

@app.get("/api/data")
def get_data():
    if not os.path.exists(DATA_FILE):
        return {}
    with open(DATA_FILE, "r", encoding="utf-8") as f:
        return json.load(f)

@app.post("/api/login")
def login(request: LoginRequest):
    stored_hash = get_admin_hash()
    if hash_password(request.password) == stored_hash:
        token = str(uuid.uuid4())
        active_tokens.add(token)
        return {"token": token, "message": "Success"}
    raise HTTPException(status_code=401, detail="Password incorrect")

@app.post("/api/logout")
def logout(x_token: str = Header(None)):
    if x_token in active_tokens:
        active_tokens.remove(x_token)
    return {"message": "Logged out"}

@app.post("/api/change-password")
def change_password(request: ChangePasswordRequest):
    stored_hash = get_admin_hash()
    if hash_password(request.old_password) != stored_hash:
        raise HTTPException(status_code=401, detail="Old password incorrect")
    save_admin_hash(hash_password(request.new_password))
    active_tokens.clear()
    return {"message": "Password changed"}

@app.post("/api/data")
def save_data(data: PortfolioData, token: str = Depends(verify_token)):
    with open(DATA_FILE, "w", encoding="utf-8") as f:
        json.dump(data.dict(), f, indent=4, ensure_ascii=False)
    return {"message": "Saved"}

@app.post("/api/upload")
def upload_file(file: UploadFile = File(...), token: str = Depends(verify_token)):
    file_location = f"{UPLOAD_DIR}/{file.filename}"
    with open(file_location, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
    return {"url": f"/uploads/{file.filename}"}

if __name__ == "__main__":
    port = int(os.environ.get("PORT", 8000))
    uvicorn.run(app, host="0.0.0.0", port=port)