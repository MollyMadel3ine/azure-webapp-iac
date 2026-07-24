"""
Minimal FastAPI app proving the infrastructure tiers connect.

Two endpoints:
  /        - hello, confirms the app itself is running
  /health  - opens a real connection to Azure SQL and reports the result.
             A successful response proves: App Service -> VNet integration
             -> private DNS resolution -> private endpoint -> SQL.

Uses pymssql rather than pyodbc: pymssql installs cleanly with pip alone,
while pyodbc depends on a system ODBC driver being present on the host.
For a health check, simpler wins.
"""

import os
import time

import pymssql
from fastapi import FastAPI
from fastapi.responses import JSONresponse

app = FastAPI(title="azure-webapp-iac")

DB_SERVER = os.environ.get("DB_SERVER", "")
DB_NAME = os.environ.get("DB_NAME", "")
DB_USER = os.environ.get("DB_USER", "")
DB_PASSWORD = os.environ.get("DB_PASSWORD", "")


@app.get("/")
def root():
    return {
        "app": "azure-webapp-iac",
        "message": "Infrastructure as Code demo - see /health for the database check",
    }


@app.get("/health")
def health():
    """Attempt a real database round-trip and report timing."""
    started = time.perf_counter()
    try:
        conn = pymssql.connect(
            server=DB_SERVER,
            user=DB_USER,
            password=DB_PASSWORD,
            database=DB_NAME,
            timeout=10,
            login_timeout=10,
        )
        cursor = conn.cursor()
        cursor.execute("SELECT @@VERSION")
        version_row = cursor.fetchone()
        conn.close()

        elapsed_ms = round((time.perf_counter() - started) * 1000)
        return {
            "status": "healthy",
            "database": "connected",
            "latency_ms": elapsed_ms,
            "sql_version": version_row[0].split("\n")[0] if version_row else "unknown",
        }
    except Exception as exc:  # deliberately broad: this is a health probe
        elapsed_ms = round((time.perf_counter() - started) * 1000)
        return JSONResponse(
            status_code=503,
            content={
            "status": "unhealthy",
            "database": "unreachable",
            "latency_ms": elapsed_ms,
            "error": str(exc),
        }
        )