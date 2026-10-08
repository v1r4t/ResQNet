# backend/app/main.py
from fastapi import FastAPI
from app.database import pool

app = FastAPI(title="ResQNet API", version="1.0.0")

@app.get("/health")
def health():
    return {"status": "ok", "service": "resqnet-api"}

@app.on_event("startup")
def startup():
    pool.wait()

@app.on_event("shutdown")
def shutdown():
    pool.closeall()
