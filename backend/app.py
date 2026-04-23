"""
Voice Snippet backend — local-only FastAPI wrapper around mlx-whisper + Ollama.

Two endpoints, both bound to 127.0.0.1:
  POST /transcribe     multipart audio -> {"text": "..."}
  POST /voice-format   {text, style, instruction?} -> {"text": "..."}
"""

from __future__ import annotations

import os
import tempfile

import httpx
import mlx_whisper
from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel

WHISPER_MODEL = os.environ.get("WHISPER_MODEL", "distil-whisper-large-v3")
OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://127.0.0.1:11434")
OLLAMA_FAST_MODEL = os.environ.get("OLLAMA_FAST_MODEL", "gemma3:1b")

WHISPER_REPO = f"mlx-community/{WHISPER_MODEL}"

STYLE_PROMPTS = {
    "clean": (
        "Rewrite the user's dictated text. Remove filler words (um, uh, like, you know), "
        "fix obvious speech-to-text errors, and add punctuation. Preserve the meaning and "
        "tone exactly. Return only the rewritten text with no preamble."
    ),
    "bullets": (
        "Convert the user's dictated text into a tight bulleted list. One idea per bullet, "
        "no nesting unless strictly necessary. Return only the bullets."
    ),
    "email": (
        "Rewrite the user's dictated text as the body of a friendly, professional email. "
        "No subject line, no greeting, no signature — just the body. Return only the body."
    ),
    "formal": (
        "Rewrite the user's dictated text in a polished, formal business register. "
        "Keep the meaning intact. Return only the rewritten text."
    ),
    "notes": (
        "Convert the user's dictated text into meeting-style notes with short headers "
        "and bullets under each. Return only the notes."
    ),
    "tweet": (
        "Rewrite the user's dictated text as a single punchy tweet under 280 characters. "
        "No hashtags unless present in the original. Return only the tweet."
    ),
}

app = FastAPI(title="voice-snippet-backend")


class FormatRequest(BaseModel):
    text: str
    style: str
    instruction: str | None = None


@app.get("/health")
def health() -> dict:
    return {"ok": True, "whisper": WHISPER_REPO, "ollama_model": OLLAMA_FAST_MODEL}


@app.post("/transcribe")
async def transcribe(audio: UploadFile = File(...)) -> dict:
    suffix = os.path.splitext(audio.filename or "")[1] or ".m4a"
    with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as tmp:
        tmp.write(await audio.read())
        tmp_path = tmp.name
    try:
        result = mlx_whisper.transcribe(tmp_path, path_or_hf_repo=WHISPER_REPO)
        return {"text": (result.get("text") or "").strip()}
    finally:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass


@app.post("/voice-format")
async def voice_format(req: FormatRequest) -> dict:
    system = STYLE_PROMPTS.get(req.style)
    if system is None:
        raise HTTPException(status_code=400, detail=f"unknown style: {req.style}")
    if req.instruction:
        system = f"{system}\n\nExtra instruction from the user: {req.instruction}"

    payload = {
        "model": OLLAMA_FAST_MODEL,
        "stream": False,
        "messages": [
            {"role": "system", "content": system},
            {"role": "user", "content": req.text},
        ],
        "options": {"temperature": 0.2},
    }
    async with httpx.AsyncClient(timeout=120) as client:
        try:
            r = await client.post(f"{OLLAMA_URL}/api/chat", json=payload)
        except httpx.HTTPError as e:
            raise HTTPException(status_code=502, detail=f"ollama unreachable: {e}") from e
    if r.status_code != 200:
        raise HTTPException(status_code=502, detail=f"ollama {r.status_code}: {r.text[:200]}")
    data = r.json()
    return {"text": (data.get("message", {}).get("content") or "").strip()}


if __name__ == "__main__":
    import uvicorn

    port = int(os.environ.get("PORT", "8003"))
    uvicorn.run(app, host="127.0.0.1", port=port, log_level="info")
