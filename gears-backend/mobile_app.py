"""
mobile_app.py  —  The Gears Mobile Backend (Flask)
========================================================
FIXES APPLIED:
  1. resolve_media_url() — handles Tkinter filename-only paths using FLASK_BASE_URL
  2. get_published_articles() — removed normalize_media() overwrite after resolve_media_url()
  3. get_article_by_id()     — same fix
  4. get_articles()          — same fix
  5. get_my_articles()       — same fix
  6. get_submitted_articles() — removed broken RPC, direct DB query lang (status='pending')
  7. app.run() — changed to host="0.0.0.0" para accessible sa network
"""

from flask import Flask, request, jsonify, send_from_directory, url_for
from flask_cors import CORS
from flask_mail import Mail, Message
from werkzeug.security import generate_password_hash, check_password_hash
from werkzeug.utils import secure_filename
from datetime import datetime
from flask_limiter import Limiter
from flask_limiter.util import get_remote_address
import os
import magic
import io
import traceback
import subprocess
import uuid
import tempfile
import random
import string
import json
from PIL import Image
from datetime import datetime, timezone

from supabase.client import create_client
from dotenv import load_dotenv


def supabase_safe_call(func, retries=3, delay=0.5):
    import time
    for i in range(retries):
        try:
            return func()
        except OSError as e:
            if "10035" in str(e):
                print("[SAFE_RETRY] WinError 10035, retrying...")
                time.sleep(delay)
                continue
            raise
    print("[SAFE_RETRY] FAILED after retries")
    raise e


load_dotenv()

SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_ANON_KEY = os.getenv("SUPABASE_ANON_KEY")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY")
supabase = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)

app = Flask(__name__)
CORS(app)


import os

WEB_UPLOADS = r"C:\Users\Jasper\Downloads\The_Gears_Web\Web_TheGears\static\uploads"
MOBILE_UPLOADS = os.path.join(
    os.path.dirname(os.path.abspath(__file__)), "static", "uploads"
)

# ── Define limiter MUNA bago ang mga routes na gumagamit nito ────────────────
limiter = Limiter(
    get_remote_address,
    app=app,
    default_limits=["200 per day", "50 per hour"],

)

# ── STATIC FILE SERVING — exempt na sa limiter via exempt_when ───────────────
@app.route("/static/uploads/<path:filename>")
def serve_media(filename):
    if os.path.exists(os.path.join(MOBILE_UPLOADS, filename)):
        folder = MOBILE_UPLOADS
    elif os.path.exists(os.path.join(WEB_UPLOADS, filename)):
        folder = WEB_UPLOADS
    else:
        print(f"[serve_media] File not found: {filename}")
        return jsonify({"error": f"File not found: {filename}"}), 404

    response = send_from_directory(folder, filename)
    response.headers["Access-Control-Allow-Origin"] = "*"
    return response

import time

# ── STATUS CONSTANTS ──────────────────────────────────────────────────────────
STATUS_DRAFT          = "draft"
STATUS_PENDING        = "pending"
STATUS_APPROVED       = "approved"
STATUS_NEEDS_REVISION = "needs_revision"
STATUS_REJECTED       = "rejected"
PUBLISHED_STATUSES    = ["approved", "published"]

# ── FIX 1: FLASK BASE URL para sa images mula sa Tkinter/Web ─────────────────
# Kinukuha sa .env — palitan ang IP kung magbago ang network
FLASK_BASE_URL      = os.getenv("FLASK_BASE_URL", "http://10.181.116.8:5000")
SUPABASE_STORAGE_BASE = f"https://vkllnewjkagdmqdclywg.supabase.co/storage/v1/object/public"


# ── HELPERS ───────────────────────────────────────────────────────────────────

def normalize_category(cat):
    if isinstance(cat, dict):
        return cat.get("name", "")
    elif isinstance(cat, str):
        return cat
    return ""


def normalize_media(raw):
    """
    Internal helper — ginagamit lang para i-detect ang format.
    HUWAG gamitin bilang final output sa API responses —
    gamitin ang resolve_media_url() para sa full URLs.
    """
    if raw is None:
        return []
    if isinstance(raw, dict):
        fps = raw.get("file_paths", [])
        if fps:
            return [{"url": f, "type": "image"} for f in fps if f]
        return []
    if isinstance(raw, list):
        result = []
        for item in raw:
            if isinstance(item, dict):
                result.append(item)
            elif isinstance(item, str) and item:
                result.append({"url": item, "type": "image"})
        return result
    if isinstance(raw, str):
        v = raw.strip()
        if not v:
            return []
        try:
            parsed = json.loads(v)
            return normalize_media(parsed)
        except Exception:
            return []
    return []


def _clean_filename(f):
    """
    Alisin ang full path (Windows o Unix), ibalik ang filename lang.
    Halimbawa:
      "C:\\Users\\user\\uploads\\photo.jpg" → "photo.jpg"
      "/home/user/uploads/photo.jpg"        → "photo.jpg"
      "photo.jpg"                           → "photo.jpg"
    """
    if not f:
        return ""
    f = str(f).strip()
    # Windows full path: C:\... o C:/...
    if len(f) > 2 and f[1] == ":":
        f = f.replace("\\", "/").split("/")[-1]
    # Unix full path o backslash lang
    elif f.startswith("/") or "\\" in f:
        f = f.replace("\\", "/").split("/")[-1]
    return f


def resolve_media_url(raw):
    """
    FIX: I-convert ang anumang media format sa full public URLs para sa Flutter.

    Apat na format na kino-cover:
      1. Tkinter JSONB dict:
            {"author": "...", "photographer": "...", "file_paths": ["photo.jpg"]}
            → http://10.181.116.8
            :5000/static/uploads/photo.jpg

      2. Mobile list of dicts:
            [{"url": "https://supabase.../photo.jpg", "type": "image"}]
            → hindi babaguhin, buong URL na

      3. Legacy flat list:
            ["photo.jpg"] o ["https://supabase.../photo.jpg"]
            → idadagdag ang Flask URL kung filename lang

      4. JSON string ng alinman sa tatlo sa itaas
            → i-parse muna, tapos i-process
    """
    items = []

    if raw is None:
        return []

    # ── Format 1: Tkinter JSONB dict ─────────────────────────────────────────
    if isinstance(raw, dict):
        fps = raw.get("file_paths", [])
        for f in fps:
            filename = _clean_filename(f)
            if not filename:
                continue
            if filename.startswith("http"):
                url = filename
            else:
                # Subukan muna sa avatars (para sa profile pics)
                # Para sa article media, main uploads folder
                url = f"{FLASK_BASE_URL}/static/uploads/{filename}"
            items.append({"url": url, "thumbnail": url, "type": "image"})
        return items

    # ── Format 2 & 3: list ───────────────────────────────────────────────────
    if isinstance(raw, list):
        for item in raw:
            if isinstance(item, dict):
                url   = item.get("url", "")
                thumb = item.get("thumbnail", url)
                itype = item.get("type", "image")

                if url and not url.startswith("http"):
                    # Supabase storage path (walang full domain)
                    url   = f"{SUPABASE_STORAGE_BASE}/article_media/{url}"
                    thumb = url

                if url:
                    items.append({
                        "url":       url,
                        "thumbnail": thumb or url,
                        "type":      itype,
                    })

            elif isinstance(item, str) and item.strip():
                filename = _clean_filename(item)
                if not filename:
                    continue
                if filename.startswith("http"):
                    url = filename
                else:
                    url = f"{FLASK_BASE_URL}/static/uploads/{filename}"
                items.append({"url": url, "thumbnail": url, "type": "image"})

        return items

    # ── Format 4: JSON string ─────────────────────────────────────────────────
    if isinstance(raw, str):
        v = raw.strip()
        if not v:
            return []
        try:
            parsed = json.loads(v)
            return resolve_media_url(parsed)
        except Exception:
            # Plain filename string
            filename = _clean_filename(v)
            if filename and not filename.startswith("http"):
                url = f"{FLASK_BASE_URL}/static/uploads/{filename}"
                return [{"url": url, "thumbnail": url, "type": "image"}]

    return []


def now_utc():
    return datetime.now(timezone.utc).isoformat()


app.config["MAX_CONTENT_LENGTH"] = 20 * 1024 * 1024  # 20 MB
app.config["RATELIMIT_STORAGE_URI"] = "redis://localhost:6379"
app.config.update(
    MAIL_SERVER=os.getenv("MAIL_SERVER"),
    MAIL_PORT=int(os.getenv("MAIL_PORT", 587)),
    MAIL_USE_TLS=os.getenv("MAIL_USE_TLS", "True") == "True",
    MAIL_USERNAME=os.getenv("MAIL_USERNAME"),
    MAIL_PASSWORD=os.getenv("MAIL_PASSWORD")
)

mail = Mail(app)
ALLOWED_EXTENSIONS = {"png", "jpg", "jpeg", "gif", "webp", "mp4", "mov"}


def allowed_file(filename):
    return "." in filename and filename.rsplit(".", 1)[1].lower() in ALLOWED_EXTENSIONS


def send_email(recipient, subject, body):
    try:
        msg = Message(
            subject=subject,
            sender=app.config["MAIL_USERNAME"],
            recipients=[recipient],
            body=body,
        )
        mail.send(msg)
    except Exception as e:
        print(f"[send_email] Error: {e}")


def get_user_by_email(email):
    result = supabase.table("users").select("*").eq("email", email).execute()
    if result.data:
        return result.data[0]
    return None


def format_author_name(user):
    first  = (user.get("first_name") or "").strip()
    middle = (user.get("middle_name") or "").strip()
    last   = (user.get("last_name") or "").strip()
    if middle:
        return f"{first} {middle[0].upper()}. {last}".strip()
    return f"{first} {last}".strip()


def get_full_name(user):
    parts = [
        (user.get("first_name") or "").strip(),
        (user.get("middle_name") or "").strip(),
        (user.get("last_name") or "").strip(),
    ]
    return " ".join(p for p in parts if p)


def create_notification(user_id, type, title, message,
                        article_id=None, comment_id=None):
    try:
        supabase.table("notifications").insert({
            "user_id":    user_id,
            "type":       type,
            "title":      title,
            "message":    message,
            "article_id": article_id,
            "comment_id": comment_id,
            "is_read":    False,
            "created_at": now_utc()
        }).execute()
    except Exception as e:
        print(f"[create_notification] Error: {e}")


def log_activity(user_id, action, description):
    try:
        timestamp = datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")
        supabase.table("activity_logs").insert({
            "user_id":     user_id,
            "action":      action,
            "description": description,
            "created_at":  timestamp
        }).execute()
    except Exception as e:
        print(f"[log_activity] Error: {e}")


# ══════════════════════════════════════════════════════════════════════════════
# AUTH ROUTES (walang pagbabago)
# ══════════════════════════════════════════════════════════════════════════════

@limiter.limit("3 per hour")
@app.route("/register", methods=["POST"])
def register():
    try:
        data        = request.get_json()
        first_name  = data.get("first_name")
        middle_name = data.get("middle_name")
        last_name   = data.get("last_name")
        gender      = data.get("gender")
        birthday    = data.get("birthday")
        email       = data.get("email")
        password    = data.get("password")

        if not all([first_name, last_name, gender, birthday, email, password]):
            return jsonify({"message": "Missing required fields"}), 400

        existing_user_res = supabase.table("users").select("*").eq("email", email).execute()
        existing_user = existing_user_res.data[0] if existing_user_res.data else None

        if existing_user and existing_user.get("is_verified"):
            return jsonify({"message": "Email already exists"}), 409

        if existing_user and not existing_user.get("is_verified"):
            new_code = "".join(random.choices(string.digits, k=6))
            supabase.table("users").update({
                "verification_code": new_code
            }).eq("email", email).execute()
            send_email(email, "New Verification Code",
                       f"Hello {existing_user['first_name']}!\n\n"
                       f"Your new verification code is: {new_code}")
            return jsonify({"message": "New verification code sent!"}), 200

        hashed_pw = generate_password_hash(password)
        code      = "".join(random.choices(string.digits, k=6))

        supabase.table("users").insert({
            "first_name":        first_name,
            "middle_name":       middle_name,
            "last_name":         last_name,
            "gender":            gender,
            "birthday":          birthday,
            "email":             email,
            "password":          hashed_pw,
            "role":              "user",
            "status":            "pending",
            "is_verified":       False,
            "verified":          0,           # ← ADD THIS
            "comment_status":    "pending",   # ← ADD THIS
            "is_eic":            False,
            "verification_code": code
        }).execute()
        full = get_full_name({
            "first_name": first_name, "middle_name": middle_name,
            "last_name": last_name
        })
        log_activity(None, "User Registration", f"{full} registered an account.")

        send_email(email, "The Gears Verification Code",
                   f"Hello {first_name}!\n\nYour verification code is: {code}\n\n"
                   "Please verify your account.")

        return jsonify({"message": "Verification code sent!"}), 200

    except Exception as e:
        print("[register] Error:", e)
        return jsonify({"message": "Server error"}), 500


@limiter.limit("3 per hour")
@app.route("/forgot-password", methods=["POST"])
def forgot_password():
    try:
        data  = request.get_json()
        email = data.get("email")
        if not email:
            return jsonify({"message": "Email required"}), 400

        user = supabase.table("users").select("first_name").eq("email", email).execute()
        if not user.data:
            return jsonify({"message": "No account found"}), 404

        new_code = "".join(random.choices(string.digits, k=6))
        supabase.table("users").update({
            "verification_code": new_code
        }).eq("email", email).execute()

        send_email(email, "Password Reset Code",
                   f"Hello {user.data[0]['first_name']}!\nYour reset code is: {new_code}")
        log_activity(None, "Password Reset Requested",
                     f"Reset code requested for {email}.")
        return jsonify({"message": "Reset code sent"}), 200

    except Exception as e:
        print("[forgot_password] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/reset-password", methods=["POST"])
def reset_password():
    try:
        data         = request.get_json()
        email        = data.get("email")
        new_password = data.get("new_password")
        if not email or not new_password:
            return jsonify({"message": "Missing fields"}), 400

        hashed_pw = generate_password_hash(new_password)
        supabase.table("users").update({
            "password":          hashed_pw,
            "verification_code": None
        }).eq("email", email).execute()

        log_activity(None, "Password Reset", f"Password reset for {email}")
        return jsonify({"message": "Password reset successfully"}), 200

    except Exception as e:
        print("[reset_password] Error:", e)
        return jsonify({"message": "Server error"}), 500


@limiter.limit("5 per hour")
@app.route("/verify", methods=["POST"])
def verify():
    try:
        data  = request.get_json()
        email = data.get("email")
        code  = data.get("code")
        if not email or not code:
            return jsonify({"message": "Missing fields"}), 400

        user_res = supabase.table("users").select("*").eq("email", email).execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        user = user_res.data[0]

        if user["is_verified"]:
            return jsonify({"message": "Account already verified"}), 400
        if user["verification_code"] != code:
            return jsonify({"message": "Invalid code"}), 400

        check_super   = supabase.table("users").select("id").eq("role", "superadmin").execute()
        first_account = len(check_super.data) == 0

        if first_account:
            role   = "superadmin"
            status = "approved"
            is_eic = True
        else:
            role   = "user"
            status = "pending"
            is_eic = False

        updated = supabase.table("users").update({
    "role":              role,
    "status":            status,
    "is_verified":       True,
    "verified":          1,           # ← ADD THIS
    "comment_status":    "pending",   # ← ADD THIS
    "is_eic":            is_eic,
    "verification_code": None
}).eq("email", email).execute()

        new_user_id = updated.data[0]["id"]
        full = get_full_name(updated.data[0])
        log_activity(new_user_id, "Email Verified", f"{full} verified their account.")

        return jsonify({"message": "Email verified!"}), 200

    except Exception as e:
        print("[verify] Error:", e)
        return jsonify({"message": "Server error"}), 500


@limiter.limit("5 per hour")
@app.route("/verify-reset", methods=["POST"])
def verify_reset():
    try:
        data  = request.get_json()
        email = data.get("email")
        code  = data.get("code")
        if not email or not code:
            return jsonify({"message": "Missing fields"}), 400

        user = supabase.table("users").select("verification_code").eq("email", email).execute()
        if not user.data:
            return jsonify({"message": "User not found"}), 404

        stored_code = user.data[0].get("verification_code")
        if not stored_code:
            return jsonify({"message": "No reset code found"}), 404
        if stored_code != code:
            return jsonify({"message": "Invalid code"}), 400

        log_activity(None, "Password Reset Code Verified",
                     f"{email} verified reset code.")
        return jsonify({"message": "Code verified"}), 200

    except Exception as e:
        print("[verify_reset] Error:", e)
        return jsonify({"message": "Server error"}), 500


@limiter.limit("3 per hour")
@app.route("/resend-code", methods=["POST"])
def resend_code():
    try:
        data  = request.get_json()
        email = data.get("email")
        if not email:
            return jsonify({"message": "Email required"}), 400

        new_code = "".join(random.choices(string.digits, k=6))
        result   = supabase.table("users").select("*").eq("email", email).execute()
        if not result.data:
            return jsonify({"message": "Email not found"}), 404

        user        = result.data[0]
        first_name  = user.get("first_name", "")
        is_verified = user.get("is_verified")

        supabase.table("users").update({
            "verification_code": new_code
        }).eq("email", email).execute()

        if not is_verified:
            send_email(email, "New Verification Code",
                       f"Hello {first_name},\n\nYour new verification code is: {new_code}")
            log_activity(None, "Verification Code Resent",
                         f"Verification code resent to {email}")
            return jsonify({"message": "New verification code sent"}), 200

        send_email(email, "New Reset Code",
                   f"Hello {first_name},\n\nYour password reset code is: {new_code}")
        log_activity(None, "Reset Code Resent",
                     f"Password reset code resent to {email}")
        return jsonify({"message": "Reset code resent"}), 200

    except Exception as e:
        print("[resend_code] Error:", e)
        return jsonify({"message": "Server error"}), 500


@limiter.limit("5 per minute")
@app.route("/login", methods=["POST"])
def login():
    try:
        data     = request.get_json()
        email    = data.get("email")
        password = data.get("password")
        if not email or not password:
            return jsonify({"message": "Missing fields"}), 400

        result = supabase.table("users").select("*").eq("email", email).execute()
        if not result.data:
            return jsonify({"message": "Invalid credentials"}), 401

        user = result.data[0]

        if not check_password_hash(user["password"], password):
            return jsonify({"message": "Invalid password"}), 401

        if not user["is_verified"]:
            return jsonify({
                "message":            "Email not verified",
                "is_verified":        0,
                "needs_verification": True,
                "email":              user["email"]
            }), 200

        log_activity(user["id"], "Login", f"{get_full_name(user)} logged in.")

        return jsonify({
            "id":                  user["id"],
            "full_name":           get_full_name(user),
            "email":               user["email"],
            "role":                user["role"],
            "status":              user["status"],
            "is_verified":         1,
            "profile_picture":     user.get("profile_picture"),
            "profile_picture_url": user.get("profile_picture"),
            "needs_verification":  False
        }), 200

    except Exception as e:
        print("[login] Error:", e)
        return jsonify({"message": "Server error"}), 500


# ══════════════════════════════════════════════════════════════════════════════
# DASHBOARD STATS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/dashboard-stats", methods=["GET"])
def dashboard_stats():
    try:
        total_users = (
            supabase_safe_call(lambda: supabase.table("users")
                .select("*", count="exact").eq("role", "user").execute()).count or 0
        )
        total_admins = (
            supabase_safe_call(lambda: supabase.table("users")
                .select("*", count="exact").eq("role", "admin").execute()).count or 0
        )
        approved_users = (
            supabase_safe_call(lambda: supabase.table("users")
                .select("*", count="exact").eq("status", "approved").eq("role", "user").execute()).count or 0
        )
        pending_users = (
            supabase_safe_call(lambda: supabase.table("users")
                .select("*", count="exact").eq("status", "pending").eq("role", "user").execute()).count or 0
        )
        total_articles = (
            supabase_safe_call(lambda: supabase.table("articles")
                .select("*", count="exact")
                .in_("status", ["approved", "published"])
                .eq("is_deleted", False)
                .execute()).count or 0
        )
        pending_reviews = (
            supabase_safe_call(lambda: supabase.table("articles")
                .select("*", count="exact").eq("status", STATUS_PENDING).eq("is_deleted", False).execute()).count or 0
        )

        return jsonify({
            "total_users":     total_users,
            "total_admins":    total_admins,
            "approved_users":  approved_users,
            "pending_users":   pending_users,
            "articles":        total_articles,
            "pending_reviews": pending_reviews
        }), 200

    except Exception as e:
        print("[dashboard_stats] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# PROFILE UPDATES
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/update-profile-info", methods=["POST"])
def update_profile_info():
    try:
        data        = request.get_json(force=True, silent=True) or {}
        email       = data.get("email")
        first_name  = data.get("first_name")
        middle_name = data.get("middle_name")
        last_name   = data.get("last_name")

        if not email:
            return jsonify({"message": "Email required"}), 400

        update_data = {}
        if first_name  is not None: update_data["first_name"]  = first_name
        if middle_name is not None: update_data["middle_name"] = middle_name
        if last_name   is not None: update_data["last_name"]   = last_name

        supabase.table("users").update(update_data).eq("email", email).execute()
        return jsonify({"message": "Profile updated successfully"}), 200

    except Exception as e:
        print("[update_profile_info] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/change-password", methods=["POST"])
def change_password():
    try:
        data         = request.get_json(force=True, silent=True) or {}
        email        = data.get("email")
        old_password = data.get("old_password")
        new_password = data.get("new_password")

        if not all([email, old_password, new_password]):
            return jsonify({"message": "Missing fields"}), 400

        user_res = supabase.table("users").select("*").eq("email", email).execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        user = user_res.data[0]
        if not check_password_hash(user["password"], old_password):
            return jsonify({"message": "Incorrect old password"}), 400

        hashed = generate_password_hash(new_password)
        supabase.table("users").update({"password": hashed}).eq("email", email).execute()
        return jsonify({"message": "Password changed successfully"}), 200

    except Exception as e:
        print("[change_password] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/update-email", methods=["POST"])
def update_email():
    try:
        data      = request.get_json(force=True, silent=True) or {}
        old_email = data.get("old_email")
        new_email = data.get("new_email")

        if not all([old_email, new_email]):
            return jsonify({"message": "Missing fields"}), 400

        exists = supabase.table("users").select("id").eq("email", new_email).execute()
        if exists.data:
            return jsonify({"message": "Email already taken"}), 409

        supabase.table("users").update({"email": new_email}).eq("email", old_email).execute()
        return jsonify({"message": "Email updated successfully"}), 200

    except Exception as e:
        print("[update_email] Error:", e)
        return jsonify({"message": "Server error"}), 500


# ══════════════════════════════════════════════════════════════════════════════
# USER MANAGEMENT
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/approve-user", methods=["POST"])
def approve_user():
    try:
        data           = request.get_json()
        target_email   = data.get("target_email")
        approver_email = data.get("approver_email")

        approver = get_user_by_email(approver_email)
        if not approver or approver["role"] != "superadmin":
            return jsonify({"message": "Unauthorized"}), 403

        target_result = supabase.table("users").select("*").eq("email", target_email).execute()
        if not target_result.data:
            return jsonify({"message": "User not found"}), 404

        target = target_result.data[0]

        supabase.table("users").update({
            "status":         "approved",
            "comment_status": "accepted",
        }).eq("email", target_email).execute()

        create_notification(
            user_id=target["id"],
            type="status",
            title="Account Approved",
            message="Your account has been approved and you now have full access."
        )

        approver_name = get_full_name(approver)
        target_name   = get_full_name(target)

        log_activity(approver["id"], "User Approved",
                     f"{approver_name} approved user '{target_name}' ({target_email}).")

        send_email(target_email, "Your Gears Account Is Approved",
                   f"Hello {target_name},\n\nYour account has been approved!\n— The Gears Team")

        return jsonify({"message": f"{target_email} approved"}), 200

    except Exception as e:
        print("[approve_user] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/disapprove-user", methods=["POST"])
def disapprove_user():
    try:
        data           = request.get_json() or {}
        target_email   = data.get("target_email")
        approver_email = data.get("approver_email")

        if not approver_email:
            return jsonify({"message": "Missing approver_email"}), 400
        if not target_email:
            return jsonify({"message": "Missing target_email"}), 400

        approver = get_user_by_email(approver_email)
        if not approver or not (
            approver.get("role") == "superadmin" or approver.get("is_eic") == 1
        ):
            return jsonify({"message": "Unauthorized"}), 403

        target_result = supabase.table("users").select("*").eq("email", target_email).execute()
        if not target_result.data:
            return jsonify({"message": "User not found"}), 404

        target = target_result.data[0]

        supabase.table("users").update({
            "status":         STATUS_REJECTED,
            "comment_status": "rejected",
        }).eq("email", target_email).execute()

        supabase.table("notifications").insert({
            "user_id":    target["id"],
            "type":       "admin",
            "title":      "Account Disapproved",
            "message":    "Your account was not approved. Please check your registration details.",
            "article_id": None,
            "comment_id": None
        }).execute()

        approver_name = get_full_name(approver)
        target_name   = get_full_name(target)

        log_activity(approver["id"], "User Disapproved",
                     f"{approver_name} disapproved user '{target_name}' ({target_email}).")

        send_email(target_email, "Your Account Was Disapproved",
                   f"Hello {target_name},\n\nYour account was not approved.\n— The Gears Team")

        return jsonify({"message": f"{target_email} disapproved"}), 200

    except Exception as e:
        print("[disapprove_user] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/transfer-eic", methods=["POST"])
def transfer_eic():
    try:
        data       = request.get_json()
        from_email = data["from_email"]
        to_email   = data["to_email"]

        sender_result = supabase.table("users").select("is_eic").eq("email", from_email).execute()
        if not sender_result.data or sender_result.data[0]["is_eic"] is not True:
            return jsonify({"message": "Unauthorized"}), 403

        supabase.table("users").update({"is_eic": False}).eq("email", from_email).execute()
        supabase.table("users").update({"is_eic": True}).eq("email", to_email).execute()

        return jsonify({"message": "EIC authority transferred"}), 200

    except Exception as e:
        print("[transfer_eic] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/make-superadmin", methods=["POST"])
def make_superadmin():
    try:
        data           = request.get_json()
        approver_email = data.get("approver_email")
        target_email   = data.get("target_email")

        approver = get_user_by_email(approver_email)
        if not approver or approver.get("is_eic") != True:
            return jsonify({"message": "Only the Editor-in-Chief can add Editorial Board members"}), 403

        target_result = supabase.table("users").select("*").eq("email", target_email).execute()
        if not target_result.data:
            return jsonify({"message": "User not found"}), 404

        target = target_result.data[0]

        supabase.table("users").update({"role": "superadmin"}).eq("email", target_email).execute()

        create_notification(
            user_id=target["id"],
            type="status",
            title="Promotion",
            message="You are now a Superadmin."
        )

        approver_name = get_full_name(approver)
        target_name   = get_full_name(target)

        log_activity(approver["id"], "Promoted to Superadmin",
                     f"{approver_name} promoted '{target_name}' to SUPERADMIN.")

        return jsonify({"message": f"{target_email} promoted to superadmin"}), 200

    except Exception as e:
        print("[make_superadmin] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/create-admin", methods=["POST"])
def create_admin():
    try:
        data          = request.get_json()
        first_name    = data.get("first_name")
        middle_name   = data.get("middle_name", "")
        last_name     = data.get("last_name")
        email         = data.get("email")
        creator_email = data.get("creator_email")

        if not all([first_name, last_name, email, creator_email]):
            return jsonify({"message": "Missing fields"}), 400

        creator = get_user_by_email(creator_email)
        if not creator or creator["role"] != "superadmin":
            return jsonify({"message": "Unauthorized"}), 403

        exists = supabase.table("users").select("id").eq("email", email).execute()
        if exists.data:
            return jsonify({"message": "Email already exists"}), 409

        raw_password = "".join(random.choices(string.ascii_letters + string.digits, k=10))
        hashed_pw    = generate_password_hash(raw_password)

        supabase.table("users").insert({
            "first_name":  first_name,
            "middle_name": middle_name,
            "last_name":   last_name,
            "gender":      "N/A",
            "birthday":    "2000-01-01",
            "email":       email,
            "password":    hashed_pw,
            "role":        "admin",
            "status":      "approved",
            "is_verified": True
        }).execute()

        send_email(email, "Your Admin Account for The Gears",
                   f"Hello {first_name},\n\n"
                   f"Your admin account has been created.\n\n"
                   f"Email: {email}\n"
                   f"Temporary Password: {raw_password}\n\n"
                   f"Please log in and change your password immediately.\n\n"
                   f"– The Gears Team")

        creator_name = get_full_name(creator)
        log_activity(creator["id"], "Admin Created",
                     f"{creator_name} created admin account for "
                     f"{first_name} {last_name} ({email}).")

        return jsonify({"message": "Admin created successfully"}), 200

    except Exception as e:
        print("[create_admin] Error:", e)
        return jsonify({"message": "Server error"}), 500


@app.route("/make-admin", methods=["POST"])
def make_admin():
    try:
        data           = request.get_json()
        target_email   = data.get("target_email")
        approver_email = data.get("approver_email")

        approver = get_user_by_email(approver_email)
        if not approver or approver["role"] != "superadmin":
            return jsonify({"message": "Unauthorized"}), 403

        target_result = supabase.table("users").select("*").eq("email", target_email).execute()
        if not target_result.data:
            return jsonify({"message": "User not found"}), 404

        target = target_result.data[0]

        supabase.table("users").update({
            "role":   "admin",
            "status": "approved"
        }).eq("email", target_email).execute()

        create_notification(
            user_id=target["id"],
            type="status",
            title="Promotion",
            message="You have been promoted to Admin."
        )

        approver_name = get_full_name(approver)
        target_name   = get_full_name(target)

        log_activity(approver["id"], "Promoted to Admin",
                     f"{approver_name} promoted '{target_name}' to ADMIN.")

        send_email(target_email, "You Are Now an Admin",
                   f"Hello {target_name},\n\nYou are now an Admin in The Gears!\n— The Gears Team")

        return jsonify({"message": f"{target_email} is now admin"}), 200

    except Exception as e:
        print("[make_admin] Error:", e)
        return jsonify({"message": "Server error"}), 500


# ══════════════════════════════════════════════════════════════════════════════
# CATEGORIES
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/add-category", methods=["POST"])
def add_category():
    try:
        data        = request.get_json()
        admin_email = data.get("admin_email")
        name        = data.get("name")
        icon        = data.get("icon")
        color       = data.get("color")

        admin = get_user_by_email(admin_email)
        # ✅ i-allow ang superadmin AT admin
        if not admin or admin["role"] not in ["superadmin", "admin"]:
            return jsonify({"message": "Unauthorized"}), 403

        supabase.table("categories").insert({
            "name":          name,
            "icon":          icon,
            "color":         color,
            "display_order": 999
        }).execute()

        admin_name = get_full_name(admin)
        log_activity(admin["id"], "Category Added",
                     f"{admin_name} added category '{name}'.")

        return jsonify({"message": "Category added successfully"}), 200

    except Exception as e:
        print("[add_category] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/get-categories", methods=["GET"])
def get_categories():
    try:
        result = supabase.table("categories") \
            .select("*") \
            .order("display_order", desc=False) \
            .order("name", desc=False) \
            .execute()
        return jsonify(result.data), 200
    except Exception as e:
        print("[get_categories] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/update-category/<int:id>", methods=["POST"])
def update_category(id):
    try:
        data        = request.get_json()
        admin_email = data.get("admin_email")
        name        = data.get("name")
        icon        = data.get("icon")
        color       = data.get("color")

        admin = get_user_by_email(admin_email)
        if not admin or admin["role"] not in ["superadmin", "admin"]:
            return jsonify({"message": "Unauthorized"}), 403

        old = supabase.table("categories").select("name").eq("id", id).execute()
        if not old.data:
            return jsonify({"message": "Category not found"}), 404

        old_name = old.data[0]["name"]

        supabase.table("categories").update({
            "name": name, "icon": icon, "color": color
        }).eq("id", id).execute()

        admin_name = get_full_name(admin)
        log_activity(admin["id"], "Category Updated",
                     f"{admin_name} updated category '{old_name}' → '{name}'.")

        return jsonify({"message": "Category updated"}), 200

    except Exception as e:
        print("[update_category] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/delete-category/<int:id>", methods=["POST"])
def delete_category(id):
    try:
        data        = request.get_json(silent=True) or {}
        admin_email = (data.get("admin_email")
                       or request.form.get("admin_email")
                       or request.args.get("admin_email"))

        if not admin_email:
            return jsonify({"message": "admin_email required"}), 400

        admin = get_user_by_email(admin_email)
        if not admin or admin["role"] not in ["superadmin", "admin"]:
                return jsonify({"message": "Unauthorized"}), 403

        cat_res = supabase.table("categories").select("name").eq("id", id).execute()
        if not cat_res.data:
            return jsonify({"message": "Category not found"}), 404

        cat_name = cat_res.data[0]["name"]

        supabase.table("articles").update(
            {"category": "Uncategorized"}
        ).eq("category", cat_name).execute()

        supabase.table("categories").delete().eq("id", id).execute()

        admin_name = get_full_name(admin)
        log_activity(admin["id"], "Category Deleted",
                     f"{admin_name} deleted category '{cat_name}'.")

        return jsonify({"message": "Category deleted successfully"}), 200

    except Exception as e:
        print("[delete_category] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/reorder-categories", methods=["POST"])
def reorder_categories():
    try:
        data         = request.get_json()
        admin_email  = data.get("admin_email")
        category_ids = data.get("category_ids")

        admin = get_user_by_email(admin_email)
        # ✅ i-allow ang superadmin AT admin
        if not admin or admin["role"] not in ["superadmin", "admin"]:
            return jsonify({"message": "Unauthorized"}), 403

        for pos, cid in enumerate(category_ids, start=1):
            supabase.table("categories").update(
                {"display_order": pos}
            ).eq("id", cid).execute()

        admin_name = get_full_name(admin)
        log_activity(admin["id"], "Categories Reordered",
                     f"{admin_name} reordered categories.")

        return jsonify({"message": "Categories reordered successfully"}), 200

    except Exception as e:
        print("[reorder_categories] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# ARTICLES — may media fixes lahat
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/autosave-article", methods=["POST"])
def autosave_article():
    try:
        data        = request.get_json()
        article_id  = data.get("article_id")
        email       = data.get("email")
        headline    = data.get("headline")
        content     = data.get("content")
        category    = data.get("category")
        is_magazine = data.get("is_magazine")

        user_res = supabase.table("users").select("id").eq("email", email).single().execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        author_id = user_res.data["id"]
        now       = datetime.now(timezone.utc).isoformat()

        if article_id:
            article_res = supabase.table("articles") \
                .select("status, headline, content, category, is_magazine") \
                .eq("id", article_id) \
                .eq("author_id", author_id) \
                .single().execute()

            if not article_res.data:
                return jsonify({"message": "Article not found"}), 404

            article        = article_res.data
            current_status = article.get("status", "draft")

            payload = {
                "updated_at": now,
                "content": content if content is not None else article["content"],
            }

            if current_status == STATUS_DRAFT:
                if headline    is not None: payload["headline"]    = headline
                if category    is not None: payload["category"]    = category
                if is_magazine is not None: payload["is_magazine"] = is_magazine

            supabase.table("articles").update(payload).eq("id", article_id).execute()
            return jsonify({"message": "Autosaved", "article_id": article_id}), 200

        if not headline and not content:
            return jsonify({"message": "Nothing to save"}), 400

        insert_res = supabase.table("articles").insert({
            "author_id":   author_id,
            "headline":    headline or "",
            "content":     content or "",
            "category":    category or "Uncategorized",
            "is_magazine": is_magazine or False,
            "media":       [],
            "status":      STATUS_DRAFT,
            "is_deleted":  False,
            "created_at":  now,
            "updated_at":  now,
        }).execute()

        new_id = insert_res.data[0]["id"]
        return jsonify({"message": "Draft created", "article_id": new_id}), 200

    except Exception as e:
        print("[autosave_article] Error:", e)
        return jsonify({"message": "Server error", "error": str(e)}), 500


@app.route("/save-article", methods=["POST"])
def save_article():
    try:
        article_id   = request.form.get("article_id")
        headline     = request.form.get("headline")
        category     = request.form.get("category")
        content      = request.form.get("content")
        author_email = request.form.get("email")
        status       = request.form.get("status", STATUS_DRAFT)
        is_magazine  = request.form.get("is_magazine") == "1"

        if not all([headline, category, content, author_email]):
            return jsonify({"message": "Missing required fields"}), 400

        user_res = supabase.table("users").select("*").eq("email", author_email).execute()
        if not user_res.data or user_res.data[0]["role"] not in ["admin", "superadmin"]:
            return jsonify({"message": "Unauthorized"}), 403

        user      = user_res.data[0]
        author_id = user["id"]
        now       = datetime.now(timezone.utc).isoformat()

        existing_media = []
        if article_id:
            media_res = supabase.table("articles").select("media").eq("id", article_id).execute()
            if media_res.data:
                existing_media = media_res.data[0].get("media", []) or []

        uploaded_media = []
        files = request.files.getlist("media")

        FFMPEG = os.getenv("FFMPEG_PATH", r"C:\Users\Jasper\Downloads\The_Gears_Mobile\ffmpeg-8.0.1-essentials_build\bin\ffmpeg.exe")
        

        for file in files:
            if not file or not file.filename:
                continue

            filename   = secure_filename(file.filename)
            file_bytes = file.read()
            mime       = magic.from_buffer(file_bytes, mime=True)
            is_image   = mime.startswith("image/")
            is_video   = mime.startswith("video/")

            timestamp   = datetime.now().strftime("%Y%m%d_%H%M%S_%f")
            unique_name = f"article_{timestamp}_{filename}"

            if is_image:
                try:
                    img       = Image.open(io.BytesIO(file_bytes))
                    optimized = io.BytesIO()
                    img.save(optimized, format="JPEG", optimize=True, quality=80)
                    file_bytes = optimized.getvalue()
                except Exception as e:
                    print("Image optimization error:", e)

                supabase.storage.from_("article_media").upload(
                    unique_name, file_bytes, {"content-type": mime})
                img_url = supabase.storage.from_("article_media").get_public_url(unique_name)
                uploaded_media.append({
                    "url": img_url, "thumbnail": img_url, "type": "image"
                })

            if is_video:
                supabase.storage.from_("article_media").upload(
                    unique_name, file_bytes, {"content-type": mime})
                video_url = supabase.storage.from_("article_media").get_public_url(unique_name)

                temp_dir   = tempfile.gettempdir()
                temp_video = os.path.join(temp_dir, unique_name)
                temp_thumb = os.path.join(temp_dir, unique_name + "_thumb.jpg")

                with open(temp_video, "wb") as f:
                    f.write(file_bytes)

                ffmpeg_cmd = [FFMPEG, "-y", "-i", temp_video,
                              "-ss", "00:00:01", "-vframes", "1", temp_thumb]
                result = subprocess.run(ffmpeg_cmd,
                                        stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                        text=True)

                thumb_url = None
                if os.path.exists(temp_thumb):
                    with open(temp_thumb, "rb") as f:
                        thumb_bytes = f.read()
                    thumb_name = f"{unique_name}_thumb.jpg"
                    supabase.storage.from_("article_media").upload(
                        thumb_name, thumb_bytes, {"content-type": "image/jpeg"})
                    thumb_url = supabase.storage.from_("article_media").get_public_url(thumb_name)

                uploaded_media.append({
                    "url": video_url,
                    "thumbnail": thumb_url or video_url,
                    "type": "video"
                })

        final_media = existing_media + uploaded_media

        if article_id:
            supabase.table("articles").update({
                "headline":    headline,
                "content":     content,
                "category":    category,
                "media":       final_media,
                "status":      status,
                "is_magazine": is_magazine,
                "updated_at":  now
            }).eq("id", article_id).execute()
            return jsonify({"message": "Article updated", "article_id": article_id}), 200

        insert = supabase.table("articles").insert({
            "headline":    headline,
            "content":     content,
            "category":    category,
            "author_id":   author_id,
            "media":       final_media,
            "status":      status,
            "is_magazine": is_magazine,
            "is_deleted":  False,
            "created_at":  now,
            "updated_at":  now
        }).execute()

        new_id = insert.data[0]["id"]
        return jsonify({"message": "Article created", "article_id": new_id}), 200

    except Exception as e:
        print("[save_article] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/soft-delete-article/<int:article_id>", methods=["POST"])
def soft_delete_article(article_id):
    try:
        res = supabase.table("articles").select("id, headline") \
            .eq("id", article_id).single().execute()
        if not res.data:
            return jsonify({"error": "Article not found"}), 404

        article = res.data
        supabase.table("articles").update({
            "is_deleted": True, "status": STATUS_DRAFT
        }).eq("id", article_id).execute()

        log_activity(None, "Article Deleted",
                     f"Article '{article['headline']}' was moved to Trash.")
        return jsonify({"message": "Article moved to Trash"}), 200

    except Exception as e:
        print("[soft_delete_article] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/restore-article/<int:article_id>", methods=["POST"])
def restore_article(article_id):
    try:
        res = supabase.table("articles").select("id, headline, author_id") \
            .eq("id", article_id).single().execute()
        if not res.data:
            return jsonify({"error": "Article not found"}), 404

        article = res.data
        supabase.table("articles").update({
            "is_deleted": False, "status": STATUS_DRAFT
        }).eq("id", article_id).execute()

        create_notification(
            user_id=article["author_id"],
            type="article",
            title="Article Restored",
            message=f"Your article '{article['headline']}' was restored from Trash.",
            article_id=article_id
        )

        log_activity(None, "Article Restored",
                     f"Article '{article['headline']}' was restored from Trash.")
        return jsonify({"message": "Article restored"}), 200

    except Exception as e:
        print("[restore_article] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/submit-article-for-approval/<int:article_id>", methods=["POST"])
def submit_article_for_approval(article_id):
    try:
        data         = request.get_json()
        author_email = data.get("author_email")

        if not author_email:
            return jsonify({"message": "Author email required"}), 400

        user_res = supabase.table("users").select("*").eq("email", author_email).execute()
        if not user_res.data:
            return jsonify({"message": "Unauthorized or article not found"}), 403

        user = user_res.data[0]
        if user["role"] not in ["admin", "superadmin"]:
            return jsonify({"message": "Only admins can submit articles"}), 403

        article_res = supabase.table("articles").select("*").eq("id", article_id).execute()
        if not article_res.data:
            return jsonify({"message": "Article not found"}), 404

        article = article_res.data[0]
        now     = datetime.now(timezone.utc).isoformat()

        supabase.table("articles").update({
            "status":     STATUS_PENDING,
            "updated_at": now
        }).eq("id", article_id).execute()

        full_name = get_full_name(user)
        log_activity(user["id"], "Article Submitted",
                     f"{full_name} submitted article '{article['headline']}' for approval.")

        superadmins = supabase.table("users").select("id") \
            .eq("role", "superadmin").execute().data
        for sa in superadmins:
            create_notification(
                user_id=sa["id"],
                type="article",
                title="New Article Submitted",
                message=f"{full_name} submitted '{article['headline']}' for approval.",
                article_id=article_id
            )

        return jsonify({"message": "Article submitted"}), 200

    except Exception as e:
        print("[submit_article_for_approval] Error:", e)
        return jsonify({"error": str(e)}), 500


# ── FIX 2: get_submitted_articles — direktang query, walang RPC ───────────────
@app.route("/get-submitted-articles", methods=["GET"])
def get_submitted_articles():
    """
    FIX: Inalis ang RPC call na posibleng hardcoded pa rin ang lumang
    'submitted' status sa loob ng Supabase function.
    Direktang query na ngayon — kino-cover ang articles mula sa
    mobile, web (app.py), at Tkinter na pareho na sa 'pending' status.
    """
    try:
        res = (
            supabase.table("articles")
            .select("*, users(first_name, middle_name, last_name)")
            .eq("status", STATUS_PENDING)
            .eq("is_deleted", False)
            .order("updated_at", desc=True)
            .execute()
        )
        articles = res.data or []

        for a in articles:
            user             = a.get("users") or {}
            a["author_name"] = get_full_name(user) if user else format_author_name(a)
            a["category"]    = normalize_category(a.get("category"))
            # FIX: gamitin ang resolve_media_url para sa full URLs
            a["media"]       = resolve_media_url(a.get("media"))
            if "created_at" in a: a["created_at"] = str(a["created_at"])
            if "updated_at" in a: a["updated_at"] = str(a["updated_at"])

        return jsonify(articles), 200

    except Exception as e:
        print("[get_submitted_articles] Error:", e)
        return jsonify({"error": str(e)}), 500


# ── FIX 3: get_published_articles — tanggalin ang normalize_media overwrite ───
@app.route("/get-published-articles", methods=["GET"])
def get_published_articles():
    """
    FIX: Ang normalize_media() ay na-overwrite ang resolve_media_url() result.
    Ngayon resolve_media_url() lang ang tinatawag — isang beses lang.
    """
    try:
        res = (
            supabase.table("articles")
            .select(
                "id, headline, content, category, media, is_magazine, "
                "created_at, updated_at, author_id, "
                "users(first_name, middle_name, last_name)"
            )
            .in_("status", PUBLISHED_STATUSES)
            .eq("is_deleted", False)
            .order("created_at", desc=True)
            .execute()
        )

        articles = []
        for a in res.data:
            a["category"]    = normalize_category(a.get("category"))
            user             = a.get("users") or {}
            a["author_name"] = format_author_name(user)
            # FIX: resolve_media_url() ISANG BESES LANG — walang normalize_media() pagkatapos
            a["media"]       = resolve_media_url(a.get("media"))
            articles.append(a)

        return jsonify(articles), 200

    except Exception as e:
        print("[get_published_articles] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/approve-and-publish-article/<int:article_id>", methods=["POST"])
def approve_and_publish_article(article_id):
    try:
        data           = request.get_json()
        approver_email = data.get("approver_email")

        approver = get_user_by_email(approver_email)
        if not approver or approver["role"] != "superadmin":
            return jsonify({"message": "Unauthorized"}), 403

        article_res = supabase.table("articles").select("*").eq("id", article_id).execute()
        if not article_res.data:
            return jsonify({"message": "Article not found"}), 404

        article = article_res.data[0]
        now     = datetime.now(timezone.utc).isoformat()

        supabase.table("articles").update({
            "status":      STATUS_APPROVED,
            "updated_at":  now,
            "is_magazine": article["is_magazine"],
            "feedback":    None
        }).eq("id", article_id).execute()

        author_res = supabase.table("users").select("*") \
            .eq("id", article["author_id"]).execute()
        author = author_res.data[0]

        send_email(author["email"],
                   "Your Article Has Been Published!",
                   f"Hello {author['first_name']},\n\n"
                   f"Your article '{article['headline']}' has been approved and published.\n\n"
                   "— The Gears Editorial Team")

        create_notification(
            user_id=article["author_id"],
            type="article",
            title="Article Published",
            message=f"Your article '{article['headline']}' has been approved and published.",
            article_id=article_id
        )

        approver_name = get_full_name(approver)
        log_activity(approver["id"], "Article Approved",
                     f"{approver_name} approved and published article '{article['headline']}'.")

        return jsonify({"message": "Article published"}), 200

    except Exception as e:
        print("[approve_and_publish_article] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/reject-article-for-revision/<int:article_id>", methods=["POST"])
def reject_article_for_revision(article_id):
    try:
        data              = request.get_json()
        approver_email    = data.get("approver_email")
        feedback          = data.get("feedback", "").strip()
        highlighted_texts = data.get("highlighted_texts", [])

        if not feedback:
            return jsonify({"message": "Feedback is required"}), 400

        approver = get_user_by_email(approver_email)
        if not approver or not approver.get("id") or approver["role"] != "superadmin":
            return jsonify({"message": "Unauthorized"}), 403

        approver_id = approver["id"]

        article_res = supabase.table("articles").select("*").eq("id", article_id).execute()
        if not article_res.data:
            return jsonify({"message": "Article not found"}), 404

        article = article_res.data[0]
        now     = datetime.now(timezone.utc).isoformat()

        supabase.table("articles").update({
            "status":            STATUS_NEEDS_REVISION,
            "feedback":          feedback,
            "revision_notes":    feedback,
            "highlighted_texts": highlighted_texts,
            "feedback_given_at": now,
            "feedback_given_by": approver_id,
            "updated_at":        now
        }).eq("id", article_id).execute()

        author_res = supabase.table("users").select("*") \
            .eq("id", article["author_id"]).execute()
        author = author_res.data[0]

        send_email(author["email"],
                   "Your Article Needs Revision – The Gears",
                   f"Hello {author['first_name']},\n\n"
                   f"Your article '{article['headline']}' needs revision.\n\n"
                   f"EDITOR FEEDBACK:\n{feedback}\n\n"
                   "— The Gears Editorial Team")

        approver_name = get_full_name(approver)
        log_activity(approver_id, "Article Revision Requested",
                     f"{approver_name} requested revision for article '{article['headline']}'")

        updated = supabase.table("articles").select("*") \
            .eq("id", article_id).execute().data[0]

        return jsonify({"message": "Revision request sent", "article": updated}), 200

    except Exception as e:
        print("[reject_article_for_revision] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/resubmit-article/<int:article_id>", methods=["POST"])
def resubmit_article(article_id):
    try:
        data         = request.get_json()
        author_email = data.get("author_email")
        content      = data.get("content")

        user_res = supabase.table("users").select("*").eq("email", author_email).execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        user = user_res.data[0]
        if user["role"] not in ["admin", "superadmin"]:
            return jsonify({"message": "Unauthorized"}), 403

        now         = datetime.now(timezone.utc).isoformat()
        article_res = supabase.table("articles").select("*").eq("id", article_id).execute()
        article     = article_res.data[0]

        supabase.table("articles").update({
            "content":           content,
            "status":            STATUS_PENDING,
            "updated_at":        now,
            "feedback":          None,
            "revision_notes":    None,
            "highlighted_texts": []
        }).eq("id", article_id).execute()

        superadmins = supabase.table("users").select("id") \
            .eq("role", "superadmin").execute().data
        for sa in superadmins:
            create_notification(
                user_id=sa["id"],
                type="article",
                title="Article Resubmitted",
                message=f"{get_full_name(user)} resubmitted '{article['headline']}' for approval.",
                article_id=article_id
            )

        return jsonify({"message": "Article resubmitted"}), 200

    except Exception as e:
        print("[resubmit_article] Error:", e)
        return jsonify({"message": "Server error", "error": str(e)}), 500


# ── FIX 4: get_articles — tanggalin ang normalize_media overwrite ─────────────
@app.route("/get-articles", methods=["GET"])
def get_articles():
    try:
        res = supabase.table("articles").select(
            "id, headline, content, category, media, status, is_magazine, "
            "created_at, updated_at, author_id, "
            "users(first_name, middle_name, last_name)"
        ).eq("is_deleted", False).order("created_at", desc=True).execute()

        articles = []
        for a in res.data:
            a["category"]    = normalize_category(a.get("category"))
            user             = a.get("users") or {}
            a["author_name"] = format_author_name(user)
            # FIX: resolve lang, walang normalize pagkatapos
            a["media"]       = resolve_media_url(a.get("media"))
            articles.append(a)

        return jsonify(articles), 200

    except Exception as e:
        print("[get_articles] Error:", e)
        return jsonify({"error": "Server error"}), 500


# ── FIX 5: get_article_by_id — tanggalin ang normalize_media overwrite ────────
@app.route("/get-article/<int:article_id>", methods=["GET"])
def get_article_by_id(article_id):
    try:
        res = supabase.table("articles").select(
            "id, headline, content, category, media, status, is_magazine, "
            "created_at, updated_at, feedback, highlighted_texts, "
            "author_id, users(first_name, middle_name, last_name)"
        ).eq("id", article_id).eq("is_deleted", False).single().execute()

        article = res.data
        if not article:
            return jsonify({"error": "Article not found"}), 404

        user                         = article.get("users") or {}
        article["author_name"]       = format_author_name(user)
        cat                          = article.get("category")
        article["category"]          = cat.get("name", "") if isinstance(cat, dict) else (cat or "")
        # FIX: resolve_media_url() lang — walang normalize_media() pagkatapos
        article["media"]             = resolve_media_url(article.get("media"))
        article["highlighted_texts"] = article.get("highlighted_texts") or []
        article["feedback"]          = article.get("feedback") or ""

        comments_res = supabase.table("comments").select(
            "id, user_id, comment, parent_id, created_at, "
            "users(first_name, middle_name, last_name)"
        ).eq("article_id", article_id).order("created_at").execute()

        comments = comments_res.data or []
        for c in comments:
            u                = c.get("users") or {}
            c["author_name"] = format_author_name(u)

        article["comments"] = comments
        return jsonify(article), 200

    except Exception as e:
        print("[get_article_by_id] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/search-articles/<query>", methods=["GET"])
def search_articles(query):
    try:
        res = supabase.table("articles") \
            .select("id, headline, content, category, media, status, is_magazine, created_at, updated_at") \
            .ilike("headline", f"%{query}%") \
            .eq("is_deleted", False) \
            .execute()

        articles = res.data or []
        for a in articles:
            a["category"] = normalize_category(a.get("category"))
            a["media"]    = resolve_media_url(a.get("media"))

        return jsonify(articles), 200

    except Exception as e:
        print("[search_articles] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/get-articles-by-category/<string:category>", methods=["GET"])
def get_articles_by_category(category):
    try:
        res = supabase.table("articles") \
            .select("id, headline, content, category, media, status, is_magazine, created_at, updated_at") \
            .eq("category", category) \
            .eq("is_deleted", False) \
            .execute()

        articles = res.data or []
        for a in articles:
            a["category"] = normalize_category(a.get("category"))
            a["media"]    = resolve_media_url(a.get("media"))

        return jsonify(articles), 200

    except Exception as e:
        print("[get_articles_by_category] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/edit-article/<int:article_id>", methods=["PATCH"])
def edit_article(article_id):
    try:
        data          = request.get_json()
        update_fields = {}

        if "headline"    in data: update_fields["headline"]    = data["headline"]
        if "content"     in data: update_fields["content"]     = data["content"]
        if "category"    in data: update_fields["category"]    = data["category"]
        if "media"       in data: update_fields["media"]       = data["media"]
        if "is_magazine" in data: update_fields["is_magazine"] = data["is_magazine"]

        update_fields["updated_at"] = datetime.now(timezone.utc).isoformat()

        supabase.table("articles").update(update_fields) \
            .eq("id", article_id).eq("is_deleted", False).execute()

        return jsonify({"message": "Article updated successfully"}), 200

    except Exception as e:
        print("[edit_article] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/archive-article/<int:article_id>", methods=["PATCH"])
def archive_article(article_id):
    try:
        supabase.table("articles").update({"is_deleted": True}) \
            .eq("id", article_id).execute()
        return jsonify({"message": "Article archived"}), 200
    except Exception as e:
        print("[archive_article] Error:", e)
        return jsonify({"error": "Server error"}), 500


@app.route("/delete-article/<int:id>", methods=["POST"])
def delete_article(id):
    try:
        data          = request.get_json()
        deleter_email = data.get("deleter_email")

        deleter = get_user_by_email(deleter_email)
        if not deleter:
            return jsonify({"message": "User not found"}), 404
        if deleter["role"] not in ["admin", "superadmin"]:
            return jsonify({"message": "Unauthorized"}), 403

        article = supabase.table("articles").select("*").eq("id", id).execute()
        if not article.data:
            return jsonify({"message": "Article not found"}), 404

        supabase.table("articles").update({"is_deleted": True}).eq("id", id).execute()

        log_activity(deleter["id"], "Article Deleted",
                     f"{get_full_name(deleter)} deleted article '{article.data[0]['headline']}'.")

        return jsonify({"message": "Article deleted"}), 200

    except Exception as e:
        print("[delete_article] Error:", e)
        return jsonify({"error": str(e)}), 500


# ── FIX 6: get_my_articles — tanggalin ang normalize_media overwrite ──────────
@app.route("/get-my-articles/<email>", methods=["GET"])
def get_my_articles(email):
    try:
        user_res = supabase.table("users").select("id") \
            .eq("email", email).single().execute()
        if not user_res.data:
            return jsonify({"error": "User not found"}), 404

        author_id = user_res.data["id"]

        res = supabase.table("articles").select(
            "id, headline, content, category, status, media, "
            "highlighted_texts, feedback, is_magazine, created_at, updated_at"
        ).eq("author_id", author_id).order("updated_at", desc=True).execute()

        articles = []
        for a in res.data:
            cat = a.get("category")
            a["category"]          = cat.get("name", "") if isinstance(cat, dict) else (cat or "")
            # FIX: resolve_media_url() lang — walang normalize_media() pagkatapos
            a["media"]             = resolve_media_url(a.get("media"))
            a["highlighted_texts"] = a.get("highlighted_texts") or []
            a["feedback"]          = a.get("feedback") or ""
            articles.append(a)

        return jsonify(articles), 200

    except Exception as e:
        print("[get_my_articles] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# COMMENTS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/add-comment", methods=["POST"])
def add_comment():
    try:
        data       = request.get_json()
        article_id = data.get("article_id")
        user_id    = data.get("user_id")
        content    = data.get("content")
        parent_id  = data.get("parent_id")

        if not all([article_id, user_id, content]):
            return jsonify({"error": "Missing fields"}), 400

        user_res = supabase.table("users") \
            .select("id, first_name, middle_name, last_name, role, status, comment_status, is_view_only") \
            .eq("id", user_id).limit(1).execute()

        if not user_res.data:
            return jsonify({"error": "User not found"}), 404

        user      = user_res.data[0]
        user_name = get_full_name(user)

        if user.get("is_view_only") is True:
            return jsonify({"error": "You are in view-only mode and cannot comment"}), 403

        status         = (user.get("status") or "").lower()
        role           = (user.get("role") or "").lower()
        comment_status = (user.get("comment_status") or "").lower()

        is_admin    = role in ["admin", "superadmin"]
        can_comment = is_admin or comment_status == "accepted" or status == "approved"

        if not can_comment:
            return jsonify({"error": "Account not approved for commenting"}), 403

        article = supabase.table("articles") \
            .select("id, headline, author_id") \
            .eq("id", article_id).limit(1).execute()

        if not article.data:
            return jsonify({"error": "Article not found"}), 404

        article_data  = article.data[0]
        article_owner = article_data["author_id"]
        headline      = article_data["headline"]

        insert_res = supabase.table("comments").insert({
            "article_id": article_id,
            "user_id":    user_id,
            "comment":    content,
            "parent_id":  parent_id
        }).execute()

        new_comment_id = insert_res.data[0]["id"]

        if user_id != article_owner:
            create_notification(
                user_id=article_owner,
                type="comment",
                title="New Comment",
                message=f"{user_name} commented on your article '{headline}'.",
                article_id=article_id,
                comment_id=new_comment_id
            )

        if parent_id:
            parent_res = supabase.table("comments").select("user_id").eq(
                "id", parent_id).execute()
            if parent_res.data:
                parent_user_id = parent_res.data[0]["user_id"]
                if parent_user_id not in [user_id, article_owner]:
                    create_notification(
                        user_id=parent_user_id,
                        type="comment",
                        title="New Reply",
                        message=f"{user_name} replied to your comment.",
                        article_id=article_id,
                        comment_id=new_comment_id
                    )

        log_activity(user_id, "Comment Added",
                     f"{user_name} commented on '{headline}'.")

        return jsonify({"message": "Comment added"}), 200

    except Exception as e:
        print("[add_comment] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/get-comments/<int:article_id>", methods=["GET"])
def get_comments(article_id):
    try:
        result = supabase_safe_call(
            lambda: supabase.rpc(
                "get_nested_comments", {"articleid": article_id}
            ).execute()
        )
        data = result.data or []

        if isinstance(data, dict) and "comments" in data:
            data = data["comments"] or []

        def traverse_and_format(nodes):
            for n in nodes:
                user             = n.get("users") or {}
                n["author_name"] = format_author_name(user)
                if "replies" in n and isinstance(n["replies"], list):
                    traverse_and_format(n["replies"])

        traverse_and_format(data)
        return jsonify(data), 200

    except Exception as e:
        print(f"[get_comments] Error: {e}")
        return jsonify({"error": str(e)}), 500


@app.route("/add-reply", methods=["POST"])
def add_reply():
    try:
        data       = request.get_json()
        article_id = data.get("article_id")
        parent_id  = data.get("parent_id")
        user_id    = data.get("user_id")
        content    = data.get("content")

        if not all([article_id, parent_id, user_id, content]):
            return jsonify({"error": "Missing fields"}), 400

        user = supabase.table("users").select("*").eq("id", user_id).execute()
        if not user.data or user.data[0]["status"] != "approved":
            return jsonify({"error": "User not approved"}), 403

        supabase.table("comments").insert({
            "article_id": article_id,
            "parent_id":  parent_id,
            "user_id":    user_id,
            "comment":    content
        }).execute()

        return jsonify({"message": "Reply added"}), 200

    except Exception as e:
        print("[add_reply] Error:", e)
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/get-related-articles/<string:category>/<int:article_id>", methods=["GET"])
def get_related_articles(category, article_id):
    try:
        response = supabase_safe_call(
            lambda: supabase.rpc("get_related_articles", {
                "cat": category, "exclude_id": article_id
            }).execute()
        )

        related = response.data or []
        for r in related:
            r["category"]    = normalize_category(r.get("category"))
            r["author_name"] = get_full_name(r)
            if "media" in r:
                r["media"] = resolve_media_url(r["media"])

        return jsonify(related), 200

    except Exception as e:
        print(f"[get_related_articles] Error: {e}")
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# USERS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/get-users", methods=["GET"])
def get_users():
    try:
        result = supabase.table("users").select(
            "id, first_name, middle_name, last_name, email, role, status, "
            "profile_picture, is_eic, is_view_only"
        ).order("created_at", desc=True).execute()

        users = result.data
        for u in users:
            u["full_name"]           = get_full_name(u)
            u["is_eic"]              = 1 if u.get("is_eic") else 0
            u["profile_picture_url"] = u.get("profile_picture") or None

        return jsonify(users), 200

    except Exception as e:
        print("[get_users] Error:", e)
        traceback.print_exc()
        return jsonify({"error": str(e)}), 500


@app.route("/get-pending-users", methods=["GET"])
def get_pending_users():
    try:
        result = supabase.table("users").select(
            "id, first_name, middle_name, last_name, email, role, status, created_at"
        ).eq("status", "pending").eq("role", "user") \
         .order("created_at", desc=True).execute()

        users = result.data
        for u in users:
            u["full_name"] = get_full_name(u)
            if u.get("created_at"):
                u["registered_date"] = datetime.fromisoformat(
                    str(u["created_at"])).strftime("%B %d, %Y")
            else:
                u["registered_date"] = None

        return jsonify(users), 200

    except Exception as e:
        print("[get_pending_users] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/get-user-status/<int:user_id>", methods=["GET"])
@limiter.exempt
def get_user_status(user_id):
    try:
        result = supabase_safe_call(
            lambda: supabase.table("users")
                .select("status, is_view_only")
                .eq("id", user_id)
                .single()
                .execute()
        )
        if not result.data:
            return jsonify({"error": "User not found"}), 404

        return jsonify({
            "status":       result.data.get("status"),
            "is_view_only": result.data.get("is_view_only", False)
        }), 200

    except Exception as e:
        print(f"[get_user_status] Error: {e}")
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# PROFILE PICTURES
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/upload-profile-picture", methods=["POST"])
def upload_profile_picture():
    try:
        if "profile_picture" not in request.files:
            return jsonify({"message": "No file provided"}), 400

        file  = request.files["profile_picture"]
        email = request.form.get("email")

        if not email:
            return jsonify({"message": "Email is required"}), 400
        if not file.filename:
            return jsonify({"message": "No file selected"}), 400

        user_res = supabase.table("users").select("id").eq("email", email).execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        user       = user_res.data[0]
        safe_name  = secure_filename(file.filename)
        timestamp  = datetime.now().strftime("%Y%m%d_%H%M%S")
        unique_name = f"profile_{user['id']}_{timestamp}_{safe_name}"

        file_bytes = file.read()
        supabase.storage.from_("profile_pictures").upload(unique_name, file_bytes)
        public_url = supabase.storage.from_("profile_pictures").get_public_url(unique_name)

        supabase.table("users").update({
            "profile_picture": public_url
        }).eq("email", email).execute()

        return jsonify({
            "message":             "Profile picture uploaded",
            "profile_picture_url": public_url
        }), 200

    except Exception as e:
        print("[upload_profile_picture] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/delete-profile-picture", methods=["POST"])
def delete_profile_picture():
    try:
        data  = request.get_json()
        email = data.get("email")

        if not email:
            return jsonify({"message": "Email is required"}), 400

        user_res = supabase.table("users").select("profile_picture").eq("email", email).execute()
        if not user_res.data:
            return jsonify({"message": "User not found"}), 404

        picture_url = user_res.data[0]["profile_picture"]
        if picture_url:
            filename = picture_url.split("/")[-1]
            supabase.storage.from_("profile_pictures").remove([filename])
            supabase.table("users").update({
                "profile_picture": None
            }).eq("email", email).execute()

        return jsonify({"message": "Profile picture removed"}), 200

    except Exception as e:
        print("[delete_profile_picture] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# VIEW-ONLY MODE
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/set-view-only", methods=["POST"])
def set_view_only():
    try:
        data            = request.get_json()
        target_email    = data.get("target_email")
        moderator_email = data.get("moderator_email")
        view_only       = data.get("view_only")

        if target_email is None or moderator_email is None:
            return jsonify({"error": "Missing fields"}), 400

        user_res = supabase.table("users").select("*") \
            .eq("email", target_email).single().execute()
        if not user_res.data:
            return jsonify({"error": "User not found"}), 404

        user           = user_res.data
        user_id        = user["id"]
        previous_state = user.get("is_view_only", False)

        supabase.table("users").update(
            {"is_view_only": view_only}
        ).eq("email", target_email).execute()

        log_activity(moderator_email, "View-Only Mode Updated",
                     f"{moderator_email} {'enabled' if view_only else 'disabled'} "
                     f"View-Only Mode for {target_email}")

        if previous_state != view_only:
            now = datetime.now(timezone.utc).isoformat()
            if view_only:
                supabase.table("notifications").insert({
                    "user_id":    user_id,
                    "title":      "View-Only Mode Enabled",
                    "message":    "Your account has been placed in View-Only Mode by an administrator.",
                    "type":       "system",
                    "is_read":    False,
                    "created_at": now
                }).execute()
            else:
                supabase.table("notifications").insert({
                    "user_id":    user_id,
                    "title":      "View-Only Mode Removed",
                    "message":    "Your account has been restored to full access.",
                    "type":       "system",
                    "is_read":    False,
                    "created_at": now
                }).execute()

        return jsonify({"message": "View-only updated successfully"}), 200

    except Exception as e:
        print("[set_view_only] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# NOTIFICATIONS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/notifications/<int:user_id>", methods=["GET"])
def get_notifications(user_id):
    try:
        limit  = int(request.args.get("limit", 50))
        offset = int(request.args.get("offset", 0))

        res = supabase.table("notifications") \
            .select("*") \
            .eq("user_id", user_id) \
            .order("created_at", desc=True) \
            .range(offset, offset + limit - 1) \
            .execute()

        return jsonify(res.data), 200

    except Exception as e:
        print("[get_notifications] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/notifications/read/<int:notif_id>", methods=["POST"])
def mark_notification_read(notif_id):
    try:
        supabase.table("notifications").update({"is_read": True}) \
            .eq("id", notif_id).execute()
        return jsonify({"message": "Notification marked as read"}), 200
    except Exception as e:
        print("[mark_notification_read] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/notifications/unread-count/<int:user_id>", methods=["GET"])
def unread_notification_count(user_id):
    try:
        res = supabase.table("notifications") \
            .select("id", count="exact") \
            .eq("user_id", user_id) \
            .eq("is_read", False) \
            .execute()
        return jsonify({"count": res.count or 0}), 200
    except Exception as e:
        print("[unread_notification_count] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/notifications/clear/<int:user_id>", methods=["POST"])
def clear_all_notifications(user_id):
    try:
        supabase.table("notifications").delete().eq("user_id", user_id).execute()
        return jsonify({"message": "Notifications cleared"}), 200
    except Exception as e:
        print("[clear_all_notifications] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# ANALYTICS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/analytics", methods=["GET"])
def analytics():
    try:
        from datetime import timedelta

        now           = datetime.now(timezone.utc)
        current_month = now.month
        current_year  = now.year

        def safe_rpc(name, params=None):
            try:
                res = supabase.rpc(name, params or {}).execute()
                return res.data
            except Exception as e:
                print(f"[analytics] RPC error in {name}:", e)
                return []

        top_authors = safe_rpc("top_authors", {
            "month": current_month, "year": current_year
        })
        top_authors = (top_authors or [])[:5]

        thirty_days_ago = (datetime.now(timezone.utc) - timedelta(days=30)).isoformat()
        try:
            logs_res = supabase.table("activity_logs") \
                .select("user_id") \
                .gt("created_at", thirty_days_ago) \
                .execute()
            logs         = logs_res.data or []
            active_users = len({row["user_id"] for row in logs if row.get("user_id")})
        except Exception as e:
            print("[analytics] active_users error:", e)
            active_users = 0

        return jsonify({
            "top_authors":  top_authors,
            "active_users": active_users
        }), 200

    except Exception as e:
        print("[analytics] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# ACTIVITY LOGS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/get-activity-logs", methods=["GET"])
def get_activity_logs():
    try:
        viewer_email = request.args.get("viewer_email")
        limit        = int(request.args.get("limit", 50))
        offset       = int(request.args.get("offset", 0))

        viewer      = get_user_by_email(viewer_email) if viewer_email else None
        viewer_role = viewer.get("role", "user") if viewer else "user"

        if viewer_role == "user":
            return jsonify({"error": "Unauthorized"}), 403

        res = supabase_safe_call(
            lambda: supabase.table("activity_logs")
                .select("id, user_id, action, description, created_at", count="exact")
                .order("created_at", desc=True)
                .range(offset, offset + limit - 1)
                .execute()
        )

        rows     = res.data or []
        user_ids = list({row.get("user_id") for row in rows if row.get("user_id")})

        actor_map = {}
        if user_ids:
            users_res = supabase_safe_call(
                lambda: supabase.table("users")
                    .select("id, first_name, middle_name, last_name, role")
                    .in_("id", user_ids)
                    .execute()
            )
            for u in users_res.data:
                actor_map[u["id"]] = u

        logs = []
        for row in rows:
            uid   = row.get("user_id")
            actor = actor_map.get(uid)

            if actor:
                actor_role = actor.get("role", "system").lower()
                actor_name = get_full_name(actor)
            else:
                actor_role = "system"
                actor_name = "System"

            if viewer_role == "admin":
                if actor_role not in ["admin", "superadmin", "user", "system"]:
                    continue

            created_at = str(row["created_at"]).replace(" ", "T")
            if "." in created_at:
                created_at = created_at.split(".")[0]
            if not created_at.endswith("Z"):
                created_at += "Z"

            logs.append({
                "id":          row["id"],
                "action":      row["action"],
                "description": row["description"],
                "created_at":  created_at,
                "actor": {
                    "id":   actor["id"] if actor else None,
                    "name": actor_name,
                    "role": actor_role,
                },
            })

        return jsonify({
            "logs":        logs,
            "next_offset": offset + limit,
            "has_more":    len(rows) == limit
        }), 200

    except Exception as e:
        print("[get_activity_logs] Error:", e)
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# ADMIN DASHBOARD STATS
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/admin-dashboard-stats/<string:email>", methods=["GET"])
def admin_dashboard_stats(email):
    try:
        user_res = supabase.table("users").select("id, role") \
            .eq("email", email).single().execute()
        user = user_res.data
        if not user:
            return jsonify({"error": "User not found"}), 404
        if user["role"] not in ["admin", "superadmin"]:
            return jsonify({"error": "Not an admin"}), 403

        admin_id = user["id"]

        def safe_count(status):
            res = supabase.table("articles") \
                .select("id", count="exact") \
                .eq("author_id", admin_id) \
                .eq("status", status) \
                .eq("is_deleted", False) \
                .execute()
            return res.count or 0

        drafts             = safe_count(STATUS_DRAFT)
        pending            = safe_count(STATUS_PENDING)
        published_approved = safe_count(STATUS_APPROVED)
        published_old      = safe_count("published")
        published          = published_approved + published_old
        revisions          = safe_count(STATUS_NEEDS_REVISION)

        deleted_res = supabase.table("articles") \
            .select("id", count="exact") \
            .eq("author_id", admin_id) \
            .eq("is_deleted", True) \
            .execute()
        deleted_count = deleted_res.count or 0

        article_res = supabase.table("articles") \
            .select("id") \
            .eq("author_id", admin_id) \
            .eq("is_deleted", False) \
            .execute()
        article_ids = [a["id"] for a in (article_res.data or [])]

        if not article_ids:
            commented_articles = 0
        else:
            comment_res = supabase.table("comments") \
                .select("article_id") \
                .in_("article_id", article_ids) \
                .execute()
            comment_rows       = comment_res.data or []
            commented_articles = len({row["article_id"] for row in comment_rows})

        return jsonify({
            "my_drafts":             drafts,
            "my_pending":            pending,
            "my_published":          published,
            "my_revisions":          revisions,
            "my_commented_articles": commented_articles,
            "my_deleted":            deleted_count
        }), 200

    except Exception as e:
        print("[admin_dashboard_stats] Error:", e)
        return jsonify({"error": "Server error", "details": str(e)}), 500
    
from flask import send_from_directory




# ══════════════════════════════════════════════════════════════════════════════
# MISC
# ══════════════════════════════════════════════════════════════════════════════

@app.route("/user-info/<email>", methods=["GET"])
def get_user_info(email):
    try:
        response = supabase.table("users").select("*") \
            .eq("email", email).single().execute()
        user = response.data
        if not user:
            return jsonify({"error": "User not found"}), 404

        return jsonify({
            "id":              user["id"],
            "email":           user["email"],
            "first_name":      user["first_name"],
            "last_name":       user["last_name"],
            "full_name":       f"{user['first_name']} {user['last_name']}",
            "role":            user["role"],
            "status":          user["status"],
            "profile_picture": user.get("profile_picture", None)
        }), 200

    except Exception as e:
        print("[get_user_info] Error:", e)
        return jsonify({"error": str(e)}), 500


@app.route("/debug-category-usage/<int:id>")
def debug_category_usage(id):
    cat = supabase.table("categories").select("*").eq("id", id).single().execute().data
    if not cat:
        return {"error": "Category not found"}
    articles = supabase.table("articles").select("id, headline, category") \
        .eq("category", cat["name"]).execute().data
    return {"category": cat["name"], "articles_using_it": articles}


@app.route("/test-supabase")
def test_supabase():
    try:
        result = supabase.table("users").select("*").limit(1).execute()
        return {"message": "Connected to supabase!", "data": result.data}
    except Exception as e:
        return {"error": str(e)}, 500


# ── DEBUG ENDPOINT: i-check kung nare-resolve ang media ng isang article ──────
@app.route("/debug-media/<int:article_id>")
def debug_media(article_id):
    """
    I-hit ito sa browser para makita kung tama ang media resolution:
    http://10.181.116.8:5001/debug-media/<article_id>
    """
    try:
        res = supabase.table("articles").select("id, headline, media") \
            .eq("id", article_id).single().execute()
        if not res.data:
            return jsonify({"error": "not found"}), 404
        raw = res.data["media"]
        resolved = resolve_media_url(raw)
        return jsonify({
            "article_id":    article_id,
            "headline":      res.data["headline"],
            "raw_type":      type(raw).__name__,
            "raw_value":     str(raw)[:500],
            "resolved_urls": resolved,
            "flask_base":    FLASK_BASE_URL,
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500


# ══════════════════════════════════════════════════════════════════════════════
# RUN — FIX: host="0.0.0.0" para ma-access ng mobile sa network
# ══════════════════════════════════════════════════════════════════════════════

if __name__ == "__main__":
    # host="0.0.0.0" = makikinig sa lahat ng network interfaces
    # kaya ma-access ng mobile device sa 192.168.254.106:5001
    app.run(host="0.0.0.0", port=5001, debug=True)