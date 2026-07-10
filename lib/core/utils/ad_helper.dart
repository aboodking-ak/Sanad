import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdHelper {
  // تصميم Singleton لضمان مشاركة نفس الإعلانات في كل الشاشات
  static final AdHelper _instance = AdHelper._internal();
  factory AdHelper() => _instance;
  AdHelper._internal();

  // معرفات الوحدات الإعلانية الحقيقية الخاصة بك
  static const String appOpenAdUnitId = 'ca-app-pub-6998904301464352/5211613005';
  static const String rewardedAdUnitId = 'ca-app-pub-6998904301464352/3682908912';

  AppOpenAd? _appOpenAd;
  bool _isShowingAd = false;
  
  // وقت صلاحية إعلان الفتح (4 ساعات)
  DateTime? _appOpenLoadTime;

  RewardedAd? _rewardedAd;

  /// تحميل إعلان فتح التطبيق
  void loadAppOpenAd({VoidCallback? onAdLoadedCallback}) {
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('AppOpenAd loaded');
          _appOpenAd = ad;
          _appOpenLoadTime = DateTime.now();
          if (onAdLoadedCallback != null) onAdLoadedCallback();
        },
        onAdFailedToLoad: (error) {
          debugPrint('AppOpenAd failed to load: $error');
        },
      ),
    );
  }

  /// تحميل إعلان المكافأة في الخلفية ليكون جاهزاً
  void loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('RewardedAd loaded');
          _rewarded_ad = ad;
        },
        onAdFailedToLoad: (error) {
          debugPrint('RewardedAd failed to load: $error');
          _rewarded_ad = null;
        },
      ),
    );
  }

  RewardedAd? get _rewarded_ad => _rewardedAd;
  set _rewarded_ad(RewardedAd? ad) => _rewardedAd = ad;

  /// إظهار إعلان المكافأة مع تنفيذ أمر بعد انتهائه (مثل التنقل)
  Future<void> showRewardedAd(VoidCallback onComplete) async {
    final prefs = await SharedPreferences.getInstance();
    final bool isAdsRemoved = prefs.getBool('is_ads_removed') ?? false;

    if (isAdsRemoved) {
      onComplete();
      return;
    }

    if (_rewarded_ad == null) {
      debugPrint('Ad not ready yet, loading and proceeding to action...');
      onComplete();
      loadRewardedAd(); // محاولة التحميل للمرة القادمة
      return;
    }

    _rewarded_ad!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewarded_ad = null;
        loadRewardedAd(); // تحميل إعلان جديد للخلفية
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewarded_ad = null;
        loadRewardedAd();
        onComplete();
      },
    );

    _rewarded_ad!.show(onUserEarnedReward: (ad, reward) {
      debugPrint('User earned reward: ${reward.amount}');
    });
  }

  /// التحقق من صلاحية الإعلان المحمل
  bool get _isAppOpenAdAvailable {
    return _appOpenAd != null &&
        _appOpenLoadTime != null &&
        DateTime.now().difference(_appOpenLoadTime!).inHours < 4;
  }

  /// إظهار إعلان فتح التطبيق
  Future<void> showAppOpenAdIfAvailable() async {
    // التحقق أولاً إذا كان المستخدم قد اشترى ميزة إزالة الإعلانات
    final prefs = await SharedPreferences.getInstance();
    final bool isAdsRemoved = prefs.getBool('is_ads_removed') ?? false;

    if (isAdsRemoved) {
      debugPrint('Ads are removed, not showing AppOpenAd');
      return;
    }

    if (!_isAppOpenAdAvailable) {
      debugPrint('Tried to show ad before available.');
      loadAppOpenAd();
      return;
    }

    if (_isShowingAd) {
      debugPrint('Tried to show ad while already showing an ad.');
      return;
    }

    _appOpenAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdShowedFullScreenContent: (ad) {
        _isShowingAd = true;
        debugPrint('$ad onAdShowedFullScreenContent');
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('$ad onAdFailedToShowFullScreenContent: $error');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('$ad onAdDismissedFullScreenContent');
        _isShowingAd = false;
        ad.dispose();
        _appOpenAd = null;
        loadAppOpenAd();
      },
    );

    _appOpenAd!.show();
  }
}
