#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===================================================================
      🤖 بوت إحصائيات وتنبيهات تطبيق Boykta Pro الرسمي 🤖
===================================================================
• التوكن: 8992827519:AAHGaDQSoSQU0h6GIsxQBdmS_iFmc5J7qKs
• معرف الأدمن: 8262706717
• وظيفة البوت: استقبال إشعارات المستخدمين الجدد، النشطين يومياً،
  وعمليات التحميل الناجحة، مع لوحة تحكم وإحصائيات تفاعلية.
===================================================================
"""

import sys
import subprocess
import os
import json
import time
from datetime import datetime

# التثبيت التلقائي للمكتبات الضرورية إذا لم تكن موجودة
REQUIRED_LIBRARIES = ['requests']

def ensure_dependencies():
    for lib in REQUIRED_LIBRARIES:
        try:
            __import__(lib)
        except ImportError:
            print(f"[*] جاري تثبيت المكتبة المطلوبة تلقائياً: {lib}...")
            try:
                subprocess.check_call([sys.executable, "-m", "pip", "install", lib])
                print(f"[+] تم تثبيت {lib} بنجاح!")
            except Exception as e:
                print(f"[-] فشل تثبيت {lib}: {e}")
                print("[!] يرجى تثبيتها يدوياً عبر: pip install requests")
                sys.exit(1)

ensure_dependencies()

import requests

# إعدادات البوت والمسؤول
BOT_TOKEN = "8992827519:AAHGaDQSoSQU0h6GIsxQBdmS_iFmc5J7qKs"
ADMIN_ID = "8262706717"
BASE_URL = f"https://api.telegram.org/bot{BOT_TOKEN}"
DB_FILE = "boykta_analytics.json"

# قاعدة بيانات محلية لحفظ الإحصائيات
def load_db():
    if os.path.exists(DB_FILE):
        try:
            with open(DB_FILE, 'r', encoding='utf-8') as f:
                return json.load(f)
        except Exception:
            pass
    return {
        "new_users_count": 0,
        "users": {},
        "active_today": {},
        "total_downloads": 0,
        "recent_downloads": [],
        "last_started": ""
    }

def save_db(db):
    try:
        with open(DB_FILE, 'w', encoding='utf-8') as f:
            json.dump(db, f, ensure_ascii=False, indent=2)
    except Exception as e:
        print(f"[-] خطأ أثناء حفظ البيانات: {e}")

# دوال التواصل مع Telegram API
def send_telegram_message(chat_id, text, reply_markup=None):
    url = f"{BASE_URL}/sendMessage"
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    try:
        resp = requests.post(url, json=payload, timeout=10)
        return resp.json()
    except Exception as e:
        print(f"[-] خطأ في الإرسال: {e}")
        return None

def answer_callback(callback_query_id, text=""):
    url = f"{BASE_URL}/answerCallbackQuery"
    try:
        requests.post(url, json={"callback_query_id": callback_query_id, "text": text}, timeout=5)
    except Exception:
        pass

# لوحة المفاتيح التفاعلية الرئيسية
def get_main_keyboard():
    return {
        "inline_keyboard": [
            [
                {"text": "📊 الإحصائيات العامة", "callback_data": "cmd_stats"},
                {"text": "👥 المستخدمين النشطين", "callback_data": "cmd_users"}
            ],
            [
                {"text": "📥 أحدث التنزيلات", "callback_data": "cmd_downloads"},
                {"text": "⚡ حالة البوت", "callback_data": "cmd_ping"}
            ],
            [
                {"text": "🔄 تحديث", "callback_data": "cmd_refresh"},
                {"text": "❓ المساعدة والأوامر", "callback_data": "cmd_help"}
            ]
        ]
    }

# بناء نص الإحصائيات الشاملة
def format_stats_message(db):
    total_users = len(db.get("users", {}))
    active_today = len(db.get("active_today", {}))
    total_dl = db.get("total_downloads", 0)
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")

    msg = (
        "📊 <b>إحصائيات تطبيق Boykta Pro v1.4.2</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        f"👥 <b>إجمالي المستخدمين المسجلين:</b> {total_users}\n"
        f"👤 <b>المستخدمين النشطين اليوم:</b> {active_today}\n"
        f"📥 <b>إجمالي عمليات التنزيل:</b> {total_dl}\n"
        f"🕒 <b>تاريخ التقرير:</b> <code>{now_str}</code>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "💡 <i>يتم تحديث هذه الأرقام تلقائياً مع كل استخدام للتطبيق.</i>"
    )
    return msg

# معالجة الأوامر والرسائل
def handle_command(chat_id, user_id, text, db):
    str_user_id = str(user_id)
    cmd = text.strip().split()[0].lower()

    if cmd == "/start":
        welcome = (
            "👋 <b>مرحباً بك في بوت إدارة وإحصائيات Boykta Pro!</b>\n\n"
            "هذا البوت مربوط بتطبيقك مباشرة، ويستقبل:\n"
            "• 🎉 تنبيهات فورية عند قيام أي مستخدم جديد بتثبيت التطبيق.\n"
            "• 👤 إحصائيات النشاط اليومي للمستخدمين.\n"
            "• 📥 تفاصيل التنزيلات المكتملة بنجاح.\n\n"
            "اختر من القائمة أدناه لعرض الإحصائيات:"
        )
        send_telegram_message(chat_id, welcome, get_main_keyboard())

    elif cmd == "/stats":
        send_telegram_message(chat_id, format_stats_message(db), get_main_keyboard())

    elif cmd == "/users":
        users = db.get("users", {})
        if not users:
            send_telegram_message(chat_id, "ℹ️ لا يوجد مستخدمين مسجلين حتى الآن. ستصلك البيانات فور فتح المستخدمين للتطبيق.")
            return
        
        lines = ["👥 <b>قائمة آخر المستخدمين:</b>\n━━━━━━━━━━━━━━━━━━━━"]
        for uid, info in list(users.items())[-10:]:
            date = info.get("first_seen", "غير معروف")
            os_ver = info.get("os", "Android")
            lines.append(f"• <code>{uid}</code>\n  📱 النظام: {os_ver} | 🕒 {date}")
        lines.append("━━━━━━━━━━━━━━━━━━━━")
        send_telegram_message(chat_id, "\n".join(lines), get_main_keyboard())

    elif cmd == "/downloads":
        recent_dl = db.get("recent_downloads", [])
        if not recent_dl:
            send_telegram_message(chat_id, "ℹ️ لم تسجل عمليات تنزيل بعد. ستظهر هنا فور إتمام المستخدمين لعمليات التحميل.")
            return
        lines = ["📥 <b>أحدث 5 عمليات تنزيل:</b>\n━━━━━━━━━━━━━━━━━━━━"]
        for item in recent_dl[-5:]:
            title = item.get("title", "فيديو")
            fmt = item.get("format", "mp4").upper()
            t = item.get("time", "")
            lines.append(f"• 🎬 <b>{title}</b>\n  📦 الصيغة: {fmt} | 🕒 {t}")
        lines.append("━━━━━━━━━━━━━━━━━━━━")
        send_telegram_message(chat_id, "\n".join(lines), get_main_keyboard())

    elif cmd == "/ping":
        send_telegram_message(chat_id, "⚡ <b>البوت يعمل بكفاءة وسرعة فائقة!</b>\n🟢 حالة الاتصال: ممتاز 100%")

    elif cmd == "/help":
        help_text = (
            "📖 <b>دليل أوامر بوت Boykta:</b>\n\n"
            "/start - القائمة الرئيسية ولوحة التحكم\n"
            "/stats - عرض إحصائيات التطبيق والمستخدمين\n"
            "/users - قائمة بأحدث المستخدمين المسجلين\n"
            "/downloads - أحدث ملفات الفيديو المحملة\n"
            "/ping - فحص سرعة استجابة البوت\n"
            "/help - عرض هذه المساعدة\n"
        )
        send_telegram_message(chat_id, help_text, get_main_keyboard())

# معالجة الضغط على أزرار Inline
def handle_callback_query(cq, db):
    cq_id = cq.get("id")
    chat_id = cq.get("message", {}).get("chat", {}).get("id")
    data = cq.get("data", "")
    
    answer_callback(cq_id)

    if data == "cmd_stats":
        send_telegram_message(chat_id, format_stats_message(db), get_main_keyboard())
    elif data == "cmd_users":
        handle_command(chat_id, chat_id, "/users", db)
    elif data == "cmd_downloads":
        handle_command(chat_id, chat_id, "/downloads", db)
    elif data == "cmd_ping":
        handle_command(chat_id, chat_id, "/ping", db)
    elif data == "cmd_refresh":
        send_telegram_message(chat_id, "🔄 تم تحديث البيانات!\n\n" + format_stats_message(db), get_main_keyboard())
    elif data == "cmd_help":
        handle_command(chat_id, chat_id, "/help", db)

# تسجيل الرسائل الواردة من التطبيق تلقائياً في الإحصائيات
def process_incoming_app_message(text, db):
    now_str = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    today_str = datetime.now().strftime("%Y-%m-%d")

    # مستخدم جديد
    if "مستخدم جديد قام بتثبيت تطبيق Boykta" in text:
        db["new_users_count"] = db.get("new_users_count", 0) + 1
        # استخراج المعرف
        import re
        m = re.search(r"معرّف المستخدم:</b>\s*<code>(.*?)</code>", text)
        uid = m.group(1) if m else f"user_{len(db.get('users', {})) + 1}"
        users = db.setdefault("users", {})
        users[uid] = {
            "first_seen": now_str,
            "last_active": now_str,
            "os": "Android"
        }
        save_db(db)

    # مستخدم نشط يومي
    elif "مستخدم نشط اليوم" in text:
        import re
        m = re.search(r"معرّف المستخدم:</b>\s*<code>(.*?)</code>", text)
        uid = m.group(1) if m else "unknown"
        active_today = db.setdefault("active_today", {})
        active_today[uid] = now_str
        save_db(db)

    # اكتمال تحميل
    elif "عملية تنزيل ناجحة" in text:
        db["total_downloads"] = db.get("total_downloads", 0) + 1
        import re
        m_title = re.search(r"الملف:</b>\s*(.*)", text)
        m_fmt = re.search(r"النوع:</b>\s*(.*)", text)
        title = m_title.group(1).strip() if m_title else "ملف فيديو"
        fmt = m_fmt.group(1).strip() if m_fmt else "MP4"
        
        recent = db.setdefault("recent_downloads", [])
        recent.append({
            "title": title,
            "format": fmt,
            "time": now_str
        })
        if len(recent) > 20:
            recent.pop(0)
        save_db(db)

# الحلقة الرئيسية لتشغيل البوت
def main():
    print("=" * 60)
    print("      🚀 بدء تشغيل بوت إحصائيات Boykta Pro 🚀")
    print(f"      • معرف المسؤول المعتمد: {ADMIN_ID}")
    print(f"      • إصدار التطبيق المتوافق: v1.4.2")
    print("=" * 60)

    db = load_db()
    db["last_started"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    save_db(db)

    # إرسال إشعار بدء التشغيل لحساب التيليجرام الخاص بك
    startup_msg = (
        "🚀 <b>تم تشغيل بوت Boykta Pro بنجاح على جهازك/سيرفرك!</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🟢 <b>الحالة:</b> متصل وجاهز للاستقبال والتحكم.\n"
        "📱 <b>إصدار التطبيق المتصل:</b> v1.4.2\n"
        f"🕒 <b>توقيت التشغيل:</b> {db['last_started']}\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "اضغط /start لفتح لوحة التحكم والإحصائيات."
    )
    print("[*] جاري إرسال إشعار بدء التشغيل إلى حسابك على تيليجرام...")
    send_telegram_message(ADMIN_ID, startup_msg, get_main_keyboard())
    print("[+] تم إرسال إشعار البدء بنجاح! البوت الآن يستقبل التحديثات...")

    offset = 0
    while True:
        try:
            url = f"{BASE_URL}/getUpdates?offset={offset}&timeout=30"
            resp = requests.get(url, timeout=35)
            if resp.status_code != 200:
                time.sleep(3)
                continue
            
            data = resp.json()
            if not data.get("ok"):
                time.sleep(3)
                continue

            for update in data.get("result", []):
                offset = update["update_id"] + 1

                # معالجة أزرار الكول باك
                if "callback_query" in update:
                    handle_callback_query(update["callback_query"], db)
                    continue

                # معالجة الرسائل النصية
                if "message" in update:
                    msg = update["message"]
                    chat_id = msg.get("chat", {}).get("id")
                    user_id = msg.get("from", {}).get("id")
                    text = msg.get("text", "")

                    # فحص إذا كانت الرسالة إشعاراً آلياً قادماً من التطبيق
                    process_incoming_app_message(text, db)

                    # إذا كانت أمراً موجهاً للبوت
                    if text.startswith("/"):
                        handle_command(chat_id, user_id, text, db)

        except requests.exceptions.RequestException as e:
            # معالجة انقطاع الإنترنت بهدوء وإعادة المحاولة
            time.sleep(5)
        except Exception as e:
            print(f"[-] خطأ غير متوقع: {e}")
            time.sleep(3)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] تم إيقاف البوت يدوياً. إلى اللقاء!")
