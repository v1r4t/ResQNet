# backend/app/main.py
from fastapi import FastAPI
from app.database import pool
from app.modules.incidents.router import router as incidents_router
from app.modules.routing.router import router as routing_router

app = FastAPI(title="ResQNet API", version="1.0.0")
app.include_router(incidents_router)
app.include_router(routing_router)

@app.get("/health")
def health():
    return {"status": "ok", "service": "resqnet-api"}

@app.on_event("startup")
def startup():
    pool.wait()

@app.on_event("shutdown")
def shutdown():
    pool.closeall()
