from fastapi import FastAPI, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel
import qrcode
import os
import hashlib
from io import BytesIO

# Load .env if present
from dotenv import load_dotenv
load_dotenv()

app = FastAPI()

# ---------- CORS ----------
FRONTEND_URL_ENV = os.getenv("FRONTEND_URL", "http://localhost:3000")
ALLOWED_ORIGINS = {
    FRONTEND_URL_ENV,
    "http://192.168.1.105:3000",     # your Pi frontend
    "http://raspberrypi.local:3000", # optional
    "http://localhost:3000",
}
app.add_middleware(
    CORSMiddleware,
    allow_origins=list(ALLOWED_ORIGINS),
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------- Local storage ----------
LOCAL_STORAGE_DIR = os.getenv("LOCAL_STORAGE_DIR", "/data/qrs")
os.makedirs(LOCAL_STORAGE_DIR, exist_ok=True)  # ensure directory exists

# Serve files at /qrs/<file.png>
app.mount("/qrs", StaticFiles(directory=LOCAL_STORAGE_DIR), name="qrs")

# ---------- Request model ----------
class QRRequest(BaseModel):
    url: str

# ---------- Endpoint ----------
@app.post("/generate-qr")
@app.post("/generate-qr/")
async def generate_qr(payload: QRRequest, request: Request):
    url = payload.url

    try:
        # Build QR
        qr = qrcode.QRCode(
            version=1,
            error_correction=qrcode.constants.ERROR_CORRECT_L,
            box_size=10,
            border=4,
        )
        qr.add_data(url)
        qr.make(fit=True)
        img = qr.make_image(fill_color="black", back_color="white")

        # Create a stable, safe filename
        digest = hashlib.sha256(url.encode("utf-8")).hexdigest()[:16]
        filename = f"qr_{digest}.png"
        filepath = os.path.join(LOCAL_STORAGE_DIR, filename)

        # Save to disk
        buf = BytesIO()
        img.save(buf, format="PNG")
        with open(filepath, "wb") as f:
            f.write(buf.getvalue())

        # Absolute URL the browser can load
        base = str(request.base_url).rstrip("/")
        file_url = f"{base}/qrs/{filename}"

        return {"qr_code_url": file_url}

    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to generate QR code: {e}")