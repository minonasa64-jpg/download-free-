import React, { useState, useEffect } from 'react';
import { 
  CheckCircle2, 
  Clock, 
  ExternalLink, 
  Download, 
  Smartphone, 
  ShieldCheck, 
  Music, 
  Wifi, 
  Sparkles, 
  GitBranch, 
  Terminal,
  RefreshCw,
  Layers,
  Code2,
  Bot,
  Send
} from 'lucide-react';

interface WorkflowRun {
  id: number;
  status: string;
  conclusion: string | null;
  html_url: string;
  head_sha?: string;
  head_commit?: {
    id?: string;
    message: string;
  };
}

export default function App() {
  const [run, setRun] = useState<WorkflowRun | null>({
    id: 36242103365,
    status: 'in_progress',
    conclusion: null,
    html_url: 'https://github.com/minonasa64-jpg/download-free-/actions/runs/36242103365',
    head_sha: '954c5c5',
    head_commit: {
      id: '954c5c5',
      message: 'fix(player): restore original working video player and restore previous app icon'
    }
  });
  const [isRefreshing, setIsRefreshing] = useState(false);
  const [lastChecked, setLastChecked] = useState<string>('');

  const fetchStatus = async () => {
    setIsRefreshing(true);
    try {
      const res = await fetch('/api/build-status');
      if (res.ok) {
        const data = await res.json();
        if (data.latestRun) {
          setRun(data.latestRun);
        }
      }
    } catch {
      // Safe fallback: never throw or log unhandled errors
    } finally {
      setIsRefreshing(false);
      setLastChecked(new Date().toLocaleTimeString('ar-EG'));
    }
  };

  useEffect(() => {
    fetchStatus();
    const interval = setInterval(fetchStatus, 10000);
    return () => clearInterval(interval);
  }, []);

  const isBuilding = run?.status === 'in_progress' || run?.status === 'queued';
  const isSuccess = run?.conclusion === 'success';
  const isFailed = run?.conclusion === 'failure';

  return (
    <div className="min-h-screen bg-slate-950 text-slate-100 antialiased font-sans selection:bg-cyan-500 selection:text-white" dir="rtl">
      {/* Header */}
      <header className="border-b border-slate-800/80 bg-slate-900/60 backdrop-blur-md sticky top-0 z-50">
        <div className="max-w-6xl mx-auto px-4 py-4 flex flex-wrap items-center justify-between gap-4">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-cyan-500 to-blue-600 flex items-center justify-center shadow-lg shadow-cyan-500/20">
              <Smartphone className="w-5 h-5 text-white" />
            </div>
            <div>
              <h1 className="text-lg font-bold text-white tracking-tight flex items-center gap-2">
                Boykta Pro APK
                <span className="text-xs px-2 py-0.5 rounded-full bg-cyan-500/10 text-cyan-400 border border-cyan-500/20 font-mono">
                  v1.4.5
                </span>
              </h1>
              <p className="text-xs text-slate-400">لوحة تحكم البناء والتصدير التلقائي إلى GitHub</p>
            </div>
          </div>

          <div className="flex items-center gap-3">
            <button
              onClick={fetchStatus}
              disabled={isRefreshing}
              className="inline-flex items-center gap-2 px-3 py-1.5 text-xs rounded-lg bg-slate-800 hover:bg-slate-700 text-slate-300 border border-slate-700/70 transition"
            >
              <RefreshCw className={`w-3.5 h-3.5 ${isRefreshing ? 'animate-spin text-cyan-400' : ''}`} />
              تحديث الحالة {lastChecked && `(${lastChecked})`}
            </button>
            <a
              href="https://github.com/minonasa64-jpg/download-free-"
              target="_blank"
              rel="noreferrer"
              className="inline-flex items-center gap-1.5 px-3 py-1.5 text-xs font-medium rounded-lg bg-cyan-600 hover:bg-cyan-500 text-white transition shadow-sm"
            >
              <GitBranch className="w-3.5 h-3.5" />
              المستودع
              <ExternalLink className="w-3 h-3" />
            </a>
          </div>
        </div>
      </header>

      {/* Main Content */}
      <main className="max-w-6xl mx-auto px-4 py-8 space-y-8">
        {/* Live Build Status Card */}
        <section className="rounded-2xl border border-slate-800 bg-gradient-to-b from-slate-900/90 to-slate-950 p-6 shadow-xl relative overflow-hidden">
          <div className="absolute top-0 left-0 right-0 h-1 bg-gradient-to-r from-cyan-500 via-blue-500 to-indigo-500"></div>
          
          <div className="flex flex-col md:flex-row items-start md:items-center justify-between gap-4 pb-6 border-b border-slate-800/80">
            <div className="flex items-center gap-4">
              <div className={`w-12 h-12 rounded-2xl flex items-center justify-center border ${
                isBuilding 
                  ? 'bg-amber-500/10 border-amber-500/30 text-amber-400'
                  : isSuccess 
                  ? 'bg-emerald-500/10 border-emerald-500/30 text-emerald-400'
                  : 'bg-rose-500/10 border-rose-500/30 text-rose-400'
              }`}>
                {isBuilding ? (
                  <RefreshCw className="w-6 h-6 animate-spin" />
                ) : isSuccess ? (
                  <CheckCircle2 className="w-6 h-6" />
                ) : (
                  <Clock className="w-6 h-6" />
                )}
              </div>
              <div>
                <div className="flex items-center gap-2">
                  <span className="text-sm font-semibold text-slate-200">حالة خط البناء الآلي (GitHub Actions):</span>
                  <span className={`text-xs px-2.5 py-0.5 rounded-full font-medium ${
                    isBuilding 
                      ? 'bg-amber-400/10 text-amber-400 border border-amber-400/20 animate-pulse'
                      : isSuccess 
                      ? 'bg-emerald-400/10 text-emerald-400 border border-emerald-400/20'
                      : 'bg-slate-800 text-slate-300'
                  }`}>
                    {isBuilding ? 'جاري التجميع والبناء الآن ⚙️' : isSuccess ? 'تم البناء بنجاح! 🎉' : (run?.conclusion || 'جاري المعالجة')}
                  </span>
                </div>
                <p className="text-xs text-slate-400 mt-1">
                  Commit: <code className="text-cyan-400 bg-slate-900 px-1 py-0.5 rounded border border-slate-800 text-[11px]">{run?.head_sha?.slice(0, 7) || run?.head_commit?.id?.slice(0, 7) || 'a77667b'}</code> — {run?.head_commit?.message?.slice(0, 70)}...
                </p>
              </div>
            </div>

            <div className="flex items-center gap-3 w-full md:w-auto">
              <a
                href={run?.html_url || 'https://github.com/minonasa64-jpg/download-free-/actions'}
                target="_blank"
                rel="noreferrer"
                className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-slate-800 hover:bg-slate-700 text-slate-200 border border-slate-700 text-xs font-medium transition"
              >
                <Terminal className="w-4 h-4 text-slate-400" />
                متابعة سجلات البناء الحية
                <ExternalLink className="w-3.5 h-3.5" />
              </a>

              <a
                href="https://github.com/minonasa64-jpg/download-free-/releases/download/v1.4.5/app-release.apk"
                target="_blank"
                rel="noreferrer"
                className="flex-1 md:flex-initial inline-flex items-center justify-center gap-2 px-4 py-2.5 rounded-xl bg-cyan-600 hover:bg-cyan-500 text-white text-xs font-medium transition shadow-lg shadow-cyan-600/20"
              >
                <Download className="w-4 h-4" />
                تحميل APK المباشر (v1.4.5)
              </a>
            </div>
          </div>

          {/* Details Bar */}
          <div className="grid grid-cols-1 sm:grid-cols-3 gap-4 pt-6 text-xs text-slate-300">
            <div className="bg-slate-950/60 p-3.5 rounded-xl border border-slate-800/80">
              <span className="text-slate-500 block mb-1">البيئة وإصدار Flutter</span>
              <span className="font-semibold text-slate-200 flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-cyan-400"></span>
                Flutter 3.19.6 • Java 17 Zulu
              </span>
            </div>
            <div className="bg-slate-950/60 p-3.5 rounded-xl border border-slate-800/80">
              <span className="text-slate-500 block mb-1">مكتبة الوسائط FFmpeg</span>
              <span className="font-semibold text-slate-200 flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-blue-400"></span>
                ffmpeg-kit-min:8.1.7 (Maintained)
              </span>
            </div>
            <div className="bg-slate-950/60 p-3.5 rounded-xl border border-slate-800/80">
              <span className="text-slate-500 block mb-1">توقيع الإطلاق الرسمي</span>
              <span className="font-semibold text-slate-200 flex items-center gap-1.5">
                <span className="w-2 h-2 rounded-full bg-emerald-400"></span>
                RSA 2048-bit (Google Protect Safe)
              </span>
            </div>
          </div>
        </section>

        {/* Applied Features Overview */}
        <section className="space-y-4">
          <div className="flex items-center gap-2">
            <Sparkles className="w-5 h-5 text-cyan-400" />
            <h2 className="text-base font-bold text-white">الميزات والتحسينات المدمجة في الإصدار الجديد (v1.4.5)</h2>
          </div>

          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-4">
            <div className="p-5 rounded-2xl border border-blue-500/40 bg-blue-950/20 space-y-3">
              <div className="flex items-center gap-3 text-blue-400">
                <div className="p-2 rounded-lg bg-blue-500/20 border border-blue-500/30">
                  <Send className="w-5 h-5 text-blue-400" />
                </div>
                <h3 className="text-sm font-semibold text-white">إحصائيات وتنبيهات بوت تيليجرام الحية</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                إرسال إشعارات فورية إلى تيليجرام عند تثبيت مستخدم جديد، نبضة النشاط اليومية للمستخدمين، وتفاصيل التنزيلات المكتملة، مع كود بايثون متكامل للتحكم.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-cyan-500/30 bg-cyan-950/20 space-y-3">
              <div className="flex items-center gap-3 text-cyan-400">
                <div className="p-2 rounded-lg bg-cyan-500/20 border border-cyan-500/30">
                  <ShieldCheck className="w-5 h-5 text-cyan-400" />
                </div>
                <h3 className="text-sm font-semibold text-white">ترقية حماية أندرويد (Target SDK 34)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                توافق كامل مع متطلبات حماية Google Play وأحدث معايير الخصوصية في Android 14/15 لحل تحذير التثبيت نهائياً.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-cyan-500/30 bg-cyan-950/20 space-y-3">
              <div className="flex items-center gap-3 text-cyan-400">
                <div className="p-2 rounded-lg bg-cyan-500/20 border border-cyan-500/30">
                  <Music className="w-5 h-5 text-cyan-400" />
                </div>
                <h3 className="text-sm font-semibold text-white">تشغيل الموسيقى خارج التطبيق وفي الخلفية</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                استمرار تشغيل الصوتيات والأغاني عند قفل الشاشة أو مغادرة التطبيق مع أزرار التنقل السلس والتشغيل التلقائي للمقطع التالي.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-cyan-500/30 bg-cyan-950/20 space-y-3">
              <div className="flex items-center gap-3 text-cyan-400">
                <div className="p-2 rounded-lg bg-cyan-500/20 border border-cyan-500/30">
                  <Sparkles className="w-5 h-5 text-cyan-400" />
                </div>
                <h3 className="text-sm font-semibold text-white">مشغل يوتيوب سريع وخلاصة نقية 100%</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                بدء تشغيل فوري بأقل من نصف ثانية بدون تعليق، مع تصفية كاملة للمحتوى غير اللائق والإباحي وإزالة شريط التصنيفات لمظهر مريح.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-emerald-400">
                <div className="p-2 rounded-lg bg-emerald-500/10 border border-emerald-500/20">
                  <Download className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">محرك التنزيل متعدد الخطوط (Turbo 16 Chunks)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                تقسيم ملفات الفيديو والصوت إلى قنوات متزامنة متوازية (حتى 16 خط) عبر Range Requests لتسريع التحميل بأقصى سرعة إنترنت، مع مؤشرات بصرية لتقدم كل خط.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-purple-400">
                <div className="p-2 rounded-lg bg-purple-500/10 border border-purple-500/20">
                  <Sparkles className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">محطة الثيمات الحية (7 Themes)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                تطبيق فوري لـ 7 ثيمات متقدمة (Cyber Neon, Deep Dark, Sunset Orange, Emerald Forest, Rose Gold, Royal Gold, AMOLED) على كافة أجزاء التطبيق دون إعادة تشغيل.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-cyan-400">
                <div className="p-2 rounded-lg bg-cyan-500/10 border border-cyan-500/20">
                  <Music className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">صانع النغمات وقص الصوت (Audio Trimmer)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                قص المقاطع الصوتية بدون فقدان جودة وبدقة عالية مع دعم مباشر لنسخ تيار MP3 أو حاوية AAC/M4A المتوافقة مع كافة مشغلات أندرويد.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-blue-400">
                <div className="p-2 rounded-lg bg-blue-500/10 border border-blue-500/20">
                  <Wifi className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">خادم المشاركة اللاسلكي المحلي (Web Share)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                فحص المنافذ تلقائياً (8080, 8088, 8888, 5000, 3000) ومشاركة الملفات مباشرة مع أجهزة الكمبيوتر والهواتف على نفس شبكة Wi-Fi عبر متصفح الويب.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-indigo-400">
                <div className="p-2 rounded-lg bg-indigo-500/10 border border-indigo-500/20">
                  <ShieldCheck className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">الخزنة المشفرة وبصمة الإصبع ورمز التمويه</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                حماية الملفات الحساسة بكلمة مرور PIN ودعم البصمة البيومترية ووضع التمويه لخداع المتطفلين وحماية الخصوصية.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-rose-500/30 bg-rose-950/20 space-y-3">
              <div className="flex items-center gap-3 text-rose-400">
                <div className="p-2 rounded-lg bg-rose-500/20 border border-rose-500/30">
                  <Smartphone className="w-5 h-5 text-rose-400" />
                </div>
                <h3 className="text-sm font-semibold text-white">مشغل فيديو يوتيوب وبحث تفاعلي (YouTube UX)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                مشغل تفاعلي يدعم التشغيل الفوري بجودات متعددة والوضع الأفقي وملء الشاشة، مع سجل بحث واقتراحات حية وسحب للتحديث.
              </p>
            </div>

            <div className="p-5 rounded-2xl border border-slate-800 bg-slate-900/50 space-y-3">
              <div className="flex items-center gap-3 text-amber-400">
                <div className="p-2 rounded-lg bg-amber-500/10 border border-amber-500/20">
                  <Code2 className="w-5 h-5" />
                </div>
                <h3 className="text-sm font-semibold text-white">نظام اللغات الشامل (7 اللغات الفورية)</h3>
              </div>
              <p className="text-xs text-slate-400 leading-relaxed">
                دعم فوري كامل للعربية والإنجليزية والفرنسية والإسبانية والتركية والألمانية والروسية مع تبديل الاتجاه وتحديث الواجهة مباشرة.
              </p>
            </div>
          </div>
        </section>

        {/* Next Suggestions */}
        <section className="p-6 rounded-2xl border border-slate-800 bg-slate-900/40 space-y-4">
          <div className="flex items-center gap-2">
            <Layers className="w-5 h-5 text-amber-400" />
            <h2 className="text-base font-bold text-white">اقتراحات إضافية قادمة لتطوير التطبيق</h2>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-3 gap-4 text-xs text-slate-300">
            <div className="bg-slate-950/70 p-4 rounded-xl border border-slate-800">
              <h4 className="font-semibold text-amber-400 mb-1.5">1. دعم التنزيل متعدد الخيوط (Multi-threaded)</h4>
              <p className="text-slate-400 leading-relaxed">
                تقسيم الملف الكبير إلى 4 أجزاء متوازية (Chunked Downloads) لمضاعفة سرعة التنزيل حتى 300%.
              </p>
            </div>
            <div className="bg-slate-950/70 p-4 rounded-xl border border-slate-800">
              <h4 className="font-semibold text-amber-400 mb-1.5">2. دعم قوائم التشغيل (Playlist Downloader)</h4>
              <p className="text-slate-400 leading-relaxed">
                إمكانية لصق رابط قائمة تشغيل كاملة على يوتيوب واختيار تحميلها دفعة واحدة بضغطة زر.
              </p>
            </div>
            <div className="bg-slate-950/70 p-4 rounded-xl border border-slate-800">
              <h4 className="font-semibold text-amber-400 mb-1.5">3. دعم ترجمة المقاطع (Subtitles Downloader)</h4>
              <p className="text-slate-400 leading-relaxed">
                استخراج وتحميل ملفات الترجمة (.srt) المصاحبة للفيديوهات بأي لغة متاحة تلقائياً.
              </p>
            </div>
          </div>
        </section>
      </main>
    </div>
  );
}
