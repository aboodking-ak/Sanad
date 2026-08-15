import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AdHelper {
  static final AdHelper _instance = AdHelper._internal();
  factory AdHelper() => _instance;
  AdHelper._internal();

  // تم الإيقاف لاستخدام الإعلانات الحقيقية
  static const bool _useTestAds = false; 

  // معرفات الوحدات الخاصة بك
  static const String _prodAppOpenId = 'ca-app-pub-6998904301464352/5211613005';
  static const String _prodRewardedId = 'ca-app-pub-6998904301464352/3682908912';

  // معرفات جوجل التجريبية
  static const String _testAppOpenId = 'ca-app-pub-3940256099942544/9257395921';
  static const String _testRewardedId = 'ca-app-pub-3940256099942544/5224354917';

  String get appOpenAdUnitId => _useTestAds ? _testAppOpenId : _prodAppOpenId;
  String get rewardedAdUnitId => _useTestAds ? _testRewardedId : _prodRewardedId;

  AppOpenAd? _appOpenAd;
  RewardedAd? _rewardedAd;
  bool _isLoadingAd = false;

  void loadAppOpenAd() {
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) => _appOpenAd = ad,
        onAdFailedToLoad: (error) => _appOpenAd = null,
      ),
    );
  }

  void loadRewardedAd() {
    if (_isLoadingAd || _rewardedAd != null) return;
    _isLoadingAd = true;
    
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          _isLoadingAd = false;
          debugPrint('AdMob: Rewarded Ad Loaded');
        },
        onAdFailedToLoad: (error) {
          _rewardedAd = null;
          _isLoadingAd = false;
          debugPrint('AdMob: Rewarded Ad Failed to Load: $error');
        },
      ),
    );
  }

  Future<void> showRewardedAd(VoidCallback onComplete) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('user_ads_removed') ?? false) {
      onComplete();
      return;
    }

    if (_rewardedAd == null) {
      debugPrint('AdMob: Ad not ready, proceeding and loading for next time...');
      loadRewardedAd();
      onComplete(); 
      return;
    }

    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onComplete();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        ad.dispose();
        _rewardedAd = null;
        loadRewardedAd();
        onComplete();
      },
    );

    _rewardedAd!.show(onUserEarnedReward: (ad, reward) {});
  }
}
