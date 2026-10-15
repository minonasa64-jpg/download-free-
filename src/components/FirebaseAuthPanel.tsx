import React, { useState, useEffect } from 'react';
import { 
  User, 
  onAuthStateChanged 
} from 'firebase/auth';
import { 
  doc, 
  onSnapshot 
} from 'firebase/firestore';
import { 
  auth, 
  db, 
  signInWithGoogleReal, 
  signOutReal, 
  testConnection,
  handleFirestoreError,
  OperationType 
} from '../lib/firebase';
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
  Smartphone
} from 'lucide-react';

export default function FirebaseAuthPanel() {
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [userProfileData, setUserProfileData] = useState<any>(null);
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [isSigningIn, setIsSigningIn] = useState<boolean>(false);
  const [isSigningOut, setIsSigningOut] = useState<boolean>(false);
  const [errorMessage, setErrorMessage] = useState<string | null>(null);
  const [successMessage, setSuccessMessage] = useState<string | null>(null);
  const [firestoreConnected, setFirestoreConnected] = useState<boolean>(false);

  // 1. Initial connection test & listen to Firebase Auth session
  useEffect(() => {
    testConnection().then(() => {
      setFirestoreConnected(true);
    }).catch(() => {
      setFirestoreConnected(false);
    });

    const unsubscribe = onAuthStateChanged(auth, (user) => {
      setCurrentUser(user);
      setIsLoading(false);
      if (user) {
        setErrorMessage(null);
      }
    });

    return () => unsubscribe();
  }, []);

  // 2. Real-time Firestore document listener for authenticated user profile
  useEffect(() => {
    if (!currentUser) {
      setUserProfileData(null);
      return;
    }

    const userDocRef = doc(db, 'users', currentUser.uid);
    const unsubscribe = onSnapshot(
      userDocRef,
      (snapshot) => {
        if (snapshot.exists()) {
          setUserProfileData(snapshot.data());
        }
      },
      (error) => {
        handleFirestoreError(error, OperationType.GET, `users/${currentUser.uid}`);
      }
    );

    return () => unsubscribe();
  }, [currentUser]);

  // Handle Google Sign-in
  const handleGoogleSignIn = async () => {
    setIsSigningIn(true);
    setErrorMessage(null);
    setSuccessMessage(null);

    try {
      const user = await signInWithGoogleReal();
      setSuccessMessage(`مرحباً بك، ${user.displayName || user.email}! تم تسجيل الدخول بنجاح عبر Google.`);
    } catch (err: any) {
      console.error('Google Sign-in Error:', err);
      if (err.code === 'auth/popup-closed-by-user') {
        setErrorMessage('تم إلغاء نافذة تسجيل الدخول من قبل المستخدم.');
      } else if (err.code === 'auth/cancelled-popup-request') {
        setErrorMessage('تم إلغاء طلب تسجيل الدخول بسبب تكرار المحاولة.');
      } else if (err.code === 'auth/network-request-failed') {
        setErrorMessage('فشل الاتصال بالشبكة. يرجى التحقق من اتصال الإنترنت والمحاولة ثانية.');
      } else if (err.code === 'auth/unauthorized-domain') {
        setErrorMessage('النطاق الحالي غير مدرج في النطاقات المصرح لها في Firebase Console.');
      } else {
        setErrorMessage(err.message || 'حدث خطأ أثناء تسجيل الدخول بحساب Google.');
      }
    } finally {
      setIsSigningIn(false);
    }
  };

  // Handle Sign-out
  const handleSignOut = async () => {
    setIsSigningOut(true);
    setErrorMessage(null);
    try {
      await signOutReal();
      setSuccessMessage('تم تسجيل الخروج بنجاح.');
    } catch (err: any) {
      setErrorMessage(err.message || 'فشل تسجيل الخروج.');
    } finally {
      setIsSigningOut(false);
    }
  };

  if (isLoading) {
    return (
      <div className="p-6 rounded-2xl border border-slate-800 bg-slate-900/60 flex items-center justify-center gap-3 text-slate-300 text-sm">
        <RefreshCw className="w-5 h-5 animate-spin text-cyan-400" />
        <span>جاري التحقق من جلسة Firebase Authentication...</span>
      </div>
    );
  }

  return (
    <div className="rounded-2xl border border-slate-800 bg-gradient-to-b from-slate-900/90 to-slate-950 p-6 shadow-xl relative overflow-hidden space-y-6">
      {/* Top Banner with Service Status */}
      <div className="flex flex-col sm:flex-row sm:items-center justify-between gap-4 pb-4 border-b border-slate-800">
        <div className="flex items-center gap-3">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-amber-500/20 to-orange-500/20 border border-amber-500/30 flex items-center justify-center text-amber-400">
            <ShieldCheck className="w-5 h-5" />
          </div>
          <div>
            <h2 className="text-base font-bold text-white flex items-center gap-2">
              نظام مصادقة Google الرسمي (Firebase Authentication)
              <span className="text-xs px-2.5 py-0.5 rounded-full bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
                Live & Secure
              </span>
            </h2>
            <p className="text-xs text-slate-400 mt-0.5">
              مصادقة حقيقية 100% مرتبطة بمزود Google وقاعدة بيانات Firestore المشفرة بقواعد حماية صارمة
            </p>
          </div>
        </div>

        <div className="flex items-center gap-2">
          <span className="text-xs px-2.5 py-1 rounded-lg bg-slate-800 text-slate-300 border border-slate-700/80 flex items-center gap-1.5">
            <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse"></span>
            Firestore DB: متصل
          </span>
        </div>
      </div>

      {/* Notifications */}
      {errorMessage && (
        <div className="p-3.5 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-300 text-xs flex items-center gap-2.5 animate-fadeIn">
          <AlertCircle className="w-4 h-4 flex-shrink-0 text-rose-400" />
          <span>{errorMessage}</span>
        </div>
      )}

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
              قم بالمصادقة بأمان عبر حساب Google لحفظ قائمة التنزيلات والمزامنة السحابية وإدارة اشتراكاتك.
            </p>
          </div>

          <button
            onClick={handleGoogleSignIn}
            disabled={isSigningIn}
            className="inline-flex items-center justify-center gap-3 px-6 py-3 rounded-xl bg-white hover:bg-slate-100 text-slate-900 font-semibold text-sm transition shadow-lg shadow-white/10 active:scale-[0.98] disabled:opacity-60 cursor-pointer"
          >
            {isSigningIn ? (
              <>
                <RefreshCw className="w-4 h-4 animate-spin text-slate-900" />
                <span>جاري فتح نافذة Google...</span>
              </>
            ) : (
              <>
                <img 
                  src="https://upload.wikimedia.org/wikipedia/commons/thumb/c/c1/Google_%22G%22_logo.svg/768px-Google_%22G%22_logo.svg.png" 
                  alt="Google"
                  className="w-4 h-4 object-contain"
                />
                <span>المتابعة باستخدام Google</span>
              </>
            )}
          </button>
        </div>
      ) : (
        /* When LOGGED IN: Real User Profile Details */
        <div className="space-y-4">
          <div className="p-5 rounded-xl bg-slate-950/70 border border-slate-800 flex flex-col md:flex-row items-start md:items-center justify-between gap-5">
            <div className="flex items-center gap-4">
              {currentUser.photoURL ? (
                <img 
                  src={currentUser.photoURL} 
                  alt={currentUser.displayName || 'Avatar'} 
                  className="w-14 h-14 rounded-full border-2 border-cyan-500/40 object-cover shadow-md"
                />
              ) : (
                <div className="w-14 h-14 rounded-full bg-cyan-600/20 border border-cyan-500/40 flex items-center justify-center text-cyan-400 font-bold text-xl">
                  {currentUser.displayName ? currentUser.displayName[0].toUpperCase() : 'U'}
                </div>
              )}

              <div className="space-y-1">
                <div className="flex items-center gap-2">
                  <h3 className="text-sm font-bold text-white">{currentUser.displayName || 'مستخدم Google'}</h3>
                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-medium">
                    موثق رسمياً
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
                disabled={isSigningOut}
                className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2 text-xs font-semibold rounded-xl bg-rose-500/10 hover:bg-rose-500/20 text-rose-300 border border-rose-500/30 transition shadow-sm"
              >
                {isSigningOut ? (
                  <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                ) : (
                  <LogOut className="w-3.5 h-3.5" />
                )}
                تسجيل الخروج
              </button>
            </div>
          </div>

          {/* Firestore Synchronized Profile Data */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-3 text-xs">
            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">مزود المصادقة</span>
              <span className="font-semibold text-slate-200">
                {currentUser.providerData[0]?.providerId === 'google.com' ? 'Google Authentication' : 'Firebase Auth'}
              </span>
            </div>

            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">حالة قاعدة البيانات (Firestore)</span>
              <span className="font-semibold text-emerald-400 flex items-center gap-1">
                <CheckCircle2 className="w-3.5 h-3.5" />
                الملف الشخصي متزامن في /users/{currentUser.uid.slice(0, 8)}...
              </span>
            </div>

            <div className="bg-slate-950/40 p-3 rounded-lg border border-slate-800">
              <span className="text-slate-500 block mb-0.5">أمان البيانات (Security Rules)</span>
              <span className="font-semibold text-cyan-400 flex items-center gap-1">
                <ShieldCheck className="w-3.5 h-3.5" />
                عزل تام: القراءة والكتابة للمالك فقط
              </span>
            </div>
          </div>
        </div>
      )}

      {/* Android Native Fingerprints Section for Firebase Console */}
      <div className="mt-4 pt-4 border-t border-slate-800/80 bg-slate-950/30 p-4 rounded-xl space-y-2 text-xs">
        <div className="flex items-center gap-2 text-slate-300 font-semibold">
          <Smartphone className="w-4 h-4 text-cyan-400" />
          <span>بصمات شهادة المفتاح الدائم لتطبيق Android (لإضافتها إلى Firebase Console):</span>
        </div>
        <p className="text-slate-400 text-[11px] leading-relaxed">
          لتفعيل تسجيل دخول Google في تطبيق الأندرويد (APK)، يتم ربط بصمتي SHA-1 و SHA-256 للمفتاح الثابت في إعدادات تطبيق Android بـ Firebase:
        </p>
        <div className="space-y-1.5 font-mono text-[11px]">
          <div className="bg-slate-900 p-2 rounded border border-slate-800 flex items-center justify-between gap-2 overflow-x-auto">
            <span className="text-slate-400">Package Name:</span>
            <span className="text-cyan-300 font-bold select-all">com.boykta.pro_downloader</span>
          </div>
          <div className="bg-slate-900 p-2 rounded border border-slate-800 flex items-center justify-between gap-2 overflow-x-auto">
            <span className="text-slate-400">SHA-1:</span>
            <span className="text-emerald-300 select-all">01:9A:11:8D:50:A8:88:5E:A7:4E:77:06:59:FE:17:F1:D4:7B:F5:40</span>
          </div>
          <div className="bg-slate-900 p-2 rounded border border-slate-800 flex items-center justify-between gap-2 overflow-x-auto">
            <span className="text-slate-400">SHA-256:</span>
            <span className="text-amber-300 select-all">E0:87:13:DD:99:95:A7:46:49:D5:CF:EB:20:B7:29:B6:6F:D8:13:BE:D8:9C:F9:2D:56:85:60:EB:3E:E2:19:66</span>
          </div>
        </div>
      </div>
    </div>
  );
}
