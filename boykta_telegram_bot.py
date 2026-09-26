#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
===================================================================
      🤖 بوت إحصائيات وتنبيهات تطبيق Boykta Pro الرسمي 🤖
===================================================================
• التوكن: 8992827519:AAHGaDQSoSQU0h6GIsxQBdmS_iFmc5J7qKs
• معرف الأدمن: 8262706717
• الميزات: يعمل مباشرة وبدون الحاجة لتثبيت أي مكتبات خارجية (Zero Dependencies)
  مبني على مكتبات بايثون القياسية القياسية 100%.
===================================================================
"""

import sys
import os
import json
import time
import urllib.request
import urllib.error
import urllib.parse
from datetime import datetime

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

# دوال التواصل مع Telegram API عبر مكتبة urllib القياسية
def api_request(method, payload=None, timeout=35):
    url = f"{BASE_URL}/{method}"
    headers = {"Content-Type": "application/json"}
    data = json.dumps(payload).encode("utf-8") if payload else None
    req = urllib.request.Request(url, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            content = resp.read().decode("utf-8")
            return json.loads(content)
    except Exception as e:
        # print(f"[-] خطأ في الاتصال ({method}): {e}")
        return None

def send_telegram_message(chat_id, text, reply_markup=None):
    payload = {
        "chat_id": chat_id,
        "text": text,
        "parse_mode": "HTML",
        "disable_web_page_preview": True
    }
    if reply_markup:
        payload["reply_markup"] = reply_markup
    return api_request("sendMessage", payload, timeout=10)

def answer_callback(callback_query_id, text=""):
    api_request("answerCallbackQuery", {"callback_query_id": callback_query_id, "text": text}, timeout=5)

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
                {"text": "⚡ حالة الاستضافة", "callback_data": "cmd_ping"}
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
    cmd = text.strip().split()[0].lower()

    if cmd == "/start":
        welcome = (
            "👋 <b>مرحباً بك في بوت إدارة وإحصائيات Boykta Pro!</b>\n\n"
            "🟢 <b>البوت مستضاف ويعمل الآن في السحابة بنجاح!</b>\n\n"
            "الوظائف التي يقوم بها البوت تلقائياً:\n"
            "• 🎉 استقبال إشعار فوري عند قيام أي مستخدم جديد بتثبيت التطبيق.\n"
            "• 👤 تسجيل وحساب المستخدمين النشطين يومياً (DAU).\n"
            "• 📥 إشعار فوري وتوثيق لكل عملية تنزيل مكتملة.\n\n"
            "اختر من القائمة أدناه لعرض الإحصائيات الحالية:"
        )
        send_telegram_message(chat_id, welcome, get_main_keyboard())

    elif cmd == "/stats":
        send_telegram_message(chat_id, format_stats_message(db), get_main_keyboard())

    elif cmd == "/users":
        users = db.get("users", {})
        if not users:
            send_telegram_message(chat_id, "ℹ️ لا يوجد مستخدمين مسجلين بعد. ستصلك البيانات فور فتح أي شخص للتطبيق.", get_main_keyboard())
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
            send_telegram_message(chat_id, "ℹ️ لم تسجل عمليات تنزيل بعد. ستظهر هنا فور إتمام المستخدمين لعمليات التحميل.", get_main_keyboard())
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
        send_telegram_message(chat_id, "⚡ <b>البوت مستضاف ويعمل بكفاءة وسرعة فائقة!</b>\n🟢 حالة الاتصال: متصل وسريع 100%")

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

    # 1. مستخدم جديد
    if "مستخدم جديد قام بتثبيت تطبيق Boykta" in text:
        db["new_users_count"] = db.get("new_users_count", 0) + 1
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

    # 2. مستخدم نشط يومي
    elif "مستخدم نشط اليوم" in text:
        import re
        m = re.search(r"معرّف المستخدم:</b>\s*<code>(.*?)</code>", text)
        uid = m.group(1) if m else "unknown"
        active_today = db.setdefault("active_today", {})
        active_today[uid] = now_str
        save_db(db)

    # 3. اكتمال تنزيل
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
    print("      🚀 بدء تشغيل واستضافة بوت Boykta Pro في الخلفية 🚀")
    print(f"      • معرف المسؤول المعتمد: {ADMIN_ID}")
    print(f"      • إصدار التطبيق المتوافق: v1.4.2")
    print("=" * 60)

    db = load_db()
    db["last_started"] = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    save_db(db)

    # إرسال إشعار بدء الاستضافة لحساب التيليجرام الخاص بك فورياً
    startup_msg = (
        "🚀 <b>تم تفعيل واستضافة بوت Boykta Pro بنجاح في السحابة!</b>\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "🟢 <b>الحالة:</b> مستضاف، متصل ويعمل في الخلفية.\n"
        "📱 <b>إصدار التطبيق المتصل:</b> v1.4.2\n"
        f"🕒 <b>توقيت البدء:</b> {db['last_started']}\n"
        "━━━━━━━━━━━━━━━━━━━━\n"
        "أرسل /start أو اضغط الأزرار أدناه للتحكم."
    )
    print("[*] جاري إرسال إشعار بدء الاستضافة إلى حسابك على تيليجرام...")
    send_telegram_message(ADMIN_ID, startup_msg, get_main_keyboard())
    print("[+] تم إرسال إشعار البدء بنجاح! البوت الآن يستقبل التحديثات...")

    offset = 0
    while True:
        try:
            updates = api_request("getUpdates", {"offset": offset, "timeout": 25}, timeout=30)
            if not updates or not updates.get("ok"):
                time.sleep(3)
                continue

            for update in updates.get("result", []):
                offset = update["update_id"] + 1

                if "callback_query" in update:
                    handle_callback_query(update["callback_query"], db)
                    continue

                if "message" in update:
                    msg = update["message"]
                    chat_id = msg.get("chat", {}).get("id")
                    user_id = msg.get("from", {}).get("id")
                    text = msg.get("text", "")

                    process_incoming_app_message(text, db)

                    if text.startswith("/"):
                        handle_command(chat_id, user_id, text, db)

        except Exception as e:
            # print(f"[-] خطأ: {e}")
            time.sleep(3)

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n[!] تم إيقاف البوت يدوياً.")
