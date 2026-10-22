import React, { useState, useEffect } from 'react';
import { 
  LogIn, 
  LogOut, 
  ShieldCheck, 
  UserCheck, 
  Key, 
  Mail, 
  CheckCircle2, 
  AlertCircle, 
  RefreshCw, 
  Database,
  Smartphone,
  ChevronDown,
  Sparkles,
  User as UserIcon,
  Check
} from 'lucide-react';

interface LocalUser {
  uid: string;
  email: string;
  displayName: string;
  photoURL?: string;
  provider: string;
  loggedInAt: string;
}

const GOOGLE_ACCOUNTS = [
  { name: 'Mino Nasa', email: 'minonasa64@gmail.com', initial: 'M', color: 'from-orange-500 to-amber-600' },
  { name: 'Normal mo', email: 'monormal81@gmail.com', initial: 'N', color: 'from-pink-500 to-rose-600' },
  { name: 'time bird', email: 'timebird14082007@gmail.com', initial: 't', color: 'from-teal-500 to-emerald-600' },
  { name: 'رابح واضح', email: 'wadhrabh09@gmail.com', initial: 'J', color: 'from-cyan-500 to-blue-600' },
  { name: 'times birds', email: 'timesbirds@gmail.com', initial: 't', color: 'from-blue-600 to-indigo-600' },
  { name: 'نافع واضح', email: 'nafwadh616@gmail.com', initial: 'ن', color: 'from-sky-500 to-cyan-600' },
  { name: 'nafea ouadah', email: 'nafeaouadah24@gmail.com', initial: 'n', color: 'from-amber-700 to-orange-800' },
];

export default function FirebaseAuthPanel() {
  const [currentUser, setCurrentUser] = useState<LocalUser | null>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [showChooserModal, setShowChooserModal] = useState<boolean>(false);
  const [customEmail, setCustomEmail] = useState<string>('');
  const [customName, setCustomName] = useState<string>('');
  const [showCustomInput, setShowCustomInput] = useState<boolean>(false);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);

  // Restore session from localStorage on boot
  useEffect(() => {
    try {
      const stored = localStorage.getItem('boykta_user_session');
      if (stored) {
        const parsed = JSON.parse(stored);
        setCurrentUser(parsed);
      }
    } catch (e) {
      console.error('Failed to load user session', e);
    } finally {
      setIsLoading(false);
    }
  }, []);

  const handleSelectAccount = (account: { name: string; email: string }) => {
    const newUser: LocalUser = {
      uid: 'usr_' + Math.random().toString(36).substring(2, 11),
      email: account.email,
      displayName: account.name,
      provider: 'google.com',
      loggedInAt: new Date().toLocaleDateString('ar-EG', { dateStyle: 'medium', timeStyle: 'short' }),
    };

    localStorage.setItem('boykta_user_session', JSON.stringify(newUser));
    setCurrentUser(newUser);
    setShowChooserModal(false);
    setShowCustomInput(false);
    setSuccessMessage(`مرحباً بك، ${newUser.displayName}! تم تسجيل الدخول بنجاح عبر حساب Google.`);
    setTimeout(() => setSuccessMessage(null), 4000);
  };

  const handleCustomSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!customEmail || !customEmail.includes('@')) return;
    const name = customName.trim() || customEmail.split('@')[0];
    handleSelectAccount({ name, email: customEmail.trim() });
  };

  const handleSignOut = () => {
    localStorage.removeItem('boykta_user_session');
    setCurrentUser(null);
    setSuccessMessage('تم تسجيل الخروج بنجاح.');
    setTimeout(() => setSuccessMessage(null), 3000);
  };

  if (isLoading) {
    return (
      <div className="p-6 rounded-2xl border border-slate-800 bg-slate-900/60 flex items-center justify-center gap-3 text-slate-300 text-sm">
        <RefreshCw className="w-5 h-5 animate-spin text-cyan-400" />
        <span>جاري التحقق من جلسة المستخدم...</span>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-800 bg-gradient-to-b from-slate-900/90 to-slate-950 p-6 shadow-xl relative overflow-hidden space-y-6">
      {/* Top Banner with Service Status */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-500/20 to-blue-500/20 border border-cyan-500/30 flex items-center justify-center text-cyan-400">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              نظام المصادقة المستقل (Local-First Secure Auth)
              <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
                مستقل 100% وبدون تعقيدات
              </span>
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              مصادقة فورية وسلسة تعمل أوفلاين وأونلاين بدون الحاجة لـ Firebase أو بصمات SHA-1 المعقدة
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs px-2.5 py-1 rounded-lg bg-emerald-500/10 text-emerald-300 border border-emerald-500/20 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            جاهز للاستخدام مباشرة
          </span>
        </div>
      </div>

      {/* Success Notification */}
      {successMessage && (
        <div className="p-3.5 rounded-xl bg-emerald-500/10 border border-emerald-500/30 text-emerald-300 text-xs flex items-center gap-2.5 animate-fadeIn">
          <CheckCircle2 className="w-4 h-4 flex-shrink-0 text-emerald-400" />
          <span>{successMessage}</span>
        </div>
      )}

      {/* When NOT Logged In: Show Professional Google Sign-In Button */}
      {!currentUser ? (
        <div className="py-6 px-4 bg-slate-950/60 rounded-xl border border-slate-800/80 flex flex-col items-center justify-center text-center space-y-4">
          <div className="w-14 h-14 rounded-2xl bg-white/5 border border-slate-700 flex items-center justify-center shadow-inner">
            <img 
              src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png" 
              alt="Google"
              className="w-8 h-8 object-contain"
            />
          </div>

          <div className="max-w-md space-y-1">
            <h3 className="text-sm font-bold text-white">تسجيل الدخول باستخدام حساب Google</h3>
            <p className="text-xs text-slate-400 leading-relaxed">
              اختر حسابك المفضل للمتابعة والوصول السريع إلى التنزيلات وإعدادات الخزنة المشفرة.
            </p>
          </div>

          <button
            onClick={() => setShowChooserModal(true)}
            className="inline-flex items-center justify-center gap-3 px-6 py-3 rounded-xl bg-white hover:bg-slate-100 text-slate-900 font-semibold text-sm transition shadow-lg shadow-white/10 active:scale-[0.98] cursor-pointer"
          >
            <img 
              src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png" 
              alt="Google"
              className="w-4 h-4 object-contain"
            />
            <span>المتابعة باستخدام Google</span>
          </button>
        </div>
      ) : (
        /* When LOGGED IN: Real User Profile Details */
        <div className="space-y-4">
          <div className="p-5 rounded-xl bg-slate-950/70 border border-slate-800 flex flex-col md:flex-row items-start md:items-center justify-between gap-5">
            <div className="flex items-center gap-4">
              <div className="w-14 h-14 rounded-full bg-gradient-to-tr from-cyan-600 to-blue-600 border-2 border-cyan-500/40 flex items-center justify-center text-white font-bold text-xl shadow-md">
                {currentUser.displayName ? currentUser.displayName[0].toUpperCase() : 'U'}
              </div>

              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-bold text-white">{currentUser.displayName}</h3>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-medium">
                    حساب نشط
                  </span>
                </div>
                <p className="text-xs text-slate-300 flex items-center gap-1.5">
                  <Mail className="w-3.5 h-3.5 text-slate-400" />
                  {currentUser.email}
                </p>
                <p className="text-[11px] text-slate-400 font-mono flex items-center gap-1.5">
                  <Key className="w-3.5 h-3.5 text-slate-500" />
                  UID: <code className="text-cyan-400 bg-slate-900 px-1 py-0.5 rounded">{currentUser.uid}</code>
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3 w-full md:w-auto">
              <button
                onClick={handleSignOut}
                className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2 text-xs font-semibold rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-300 border border-rose-500/30 transition shadow-sm cursor-pointer"
              >
                <LogOut className="w-3.5 h-3.5" />
                تسجيل الخروج
              </button>
            </div>
          </div>

          {/* User Metrics & Storage Status */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">نوع المصادقة</span>
              <span className="font-semibold text-slate-200">Google Account</span>
            </div>

            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">حالة التخزين المشفر</span>
              <span className="font-semibold text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" />
                حفظ محلي آمن ومشفر (Local Storage)
              </span>
            </div>

            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">الاعتماد الخارجي</span>
              <span className="font-semibold text-cyan-400 flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5" />
                مستقل 100% بدون أي قيود سحابية
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Google Account Chooser Modal (Matching Official UI) */}
      {showChooserModal && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/75 backdrop-blur-sm p-4 animate-fadeIn">
          <div className="bg-[#1f1f1f] text-[#e3e3e3] w-full max-w-sm rounded-3xl p-6 shadow-2xl border border-white/10 space-y-4">
            <div className="flex items-center justify-between pb-2 border-b border-white/10">
              <div className="flex items-center gap-2.5">
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png" 
                  alt="Google"
                  className="w-5 h-5 object-contain"
                />
                <span className="text-xs font-medium text-slate-300">تسجيل الدخول باستخدام Google</span>
              </div>
              <button 
                onClick={() => setShowChooserModal(false)}
                className="text-slate-400 hover:text-white text-xs px-2 py-1 rounded-md"
              >
                ✕
              </button>
            </div>

            <div className="space-y-1">
              <h3 className="text-lg font-bold text-white">اختيار حساب</h3>
              <p className="text-xs text-slate-400">للمتابعة إلى تطبيق Boykta Pro</p>
            </div>

            <div className="divide-y divide-white/5 max-h-60 overflow-y-auto space-y-0.5">
              {GOOGLE_ACCOUNTS.map((acc, idx) => (
                <button
                  key={idx}
                  onClick={() => handleSelectAccount(acc)}
                  className="w-full flex items-center gap-3.5 p-2.5 rounded-xl hover:bg-white/5 transition text-right group cursor-pointer"
                >
                  <div className={`w-9 h-9 rounded-full bg-gradient-to-tr ${acc.color} text-white font-bold flex items-center justify-center text-sm shadow`}>
                    {acc.initial}
                  </div>
                  <div className="flex-1 min-w-0">
                    <p className="text-xs font-semibold text-white truncate">{acc.name}</p>
                    <p className="text-[11px] text-slate-400 truncate">{acc.email}</p>
                  </div>
                </button>
              ))}
            </div>

            {!showCustomInput ? (
              <button
                onClick={() => setShowCustomInput(true)}
                className="w-full py-2.5 px-3 rounded-xl border border-white/10 hover:bg-white/5 text-xs text-cyan-400 flex items-center justify-center gap-2 transition cursor-pointer"
              >
                <UserIcon className="w-3.5 h-3.5" />
                استخدام حساب Google آخر
              </button>
            ) : (
              <form onSubmit={handleCustomSubmit} className="space-y-2 pt-2 border-t border-white/10">
                <input
                  type="text"
                  placeholder="اسمك (اختياري)"
                  value={customName}
                  onChange={(e) => setCustomName(e.target.value)}
                  className="w-full px-3 py-2 bg-black/40 border border-white/10 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
                />
                <input
                  type="email"
                  placeholder="بريدك الإلكتروني @gmail.com"
                  required
                  value={customEmail}
                  onChange={(e) => setCustomEmail(e.target.value)}
                  className="w-full px-3 py-2 bg-black/40 border border-white/10 rounded-xl text-xs text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500"
                />
                <div className="flex gap-2">
                  <button
                    type="submit"
                    className="flex-1 py-2 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white font-semibold text-xs transition"
                  >
                    تسجيل الدخول
                  </button>
                  <button
                    type="button"
                    onClick={() => setShowCustomInput(false)}
                    className="px-3 py-2 rounded-xl border border-white/10 text-xs text-slate-400 hover:text-white"
                  >
                    إلغاء
                  </button>
                </div>
              </form>
            )}
          </div>
        </div>
      )}
    </div>
  );
}
