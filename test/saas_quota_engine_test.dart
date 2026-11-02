import 'package:flutter_test/flutter_test.dart';
import 'package:packproof_app/models/seller_profile.dart';

void main() {
  group('Category 2: SaaS Quota & Decrementing Counter Engine Tests', () {
    test('QUOTA-01 & QUOTA-04: Dynamic VIP Banner text and Unlimited status per Tier', () {
      // 1. Silver Tier
      final silver = SellerProfile(
        id: 'user-silver',
        email: 'silver@test.com',
        sellerName: 'Silver Seller',
        storeName: 'Daraz Silver',
        phone: '03001111111',
        plan: 'silver',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 29)),
        monthlyQuota: 100,
        videosThisMonth: 0,
      );

      expect(silver.isUnlimited, isFalse);
      expect(silver.monthlyQuota, equals(100));
      expect(silver.remainingQuota, equals(100));
      expect(silver.canRecord, isTrue);

      // 2. Gold Tier
      final gold = SellerProfile(
        id: 'user-gold',
        email: 'gold@test.com',
        sellerName: 'Gold Seller',
        storeName: 'Daraz Gold',
        phone: '03002222222',
        plan: 'gold',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 29)),
        monthlyQuota: 200,
        videosThisMonth: 0,
      );

      expect(gold.isUnlimited, isFalse);
      expect(gold.monthlyQuota, equals(200));
      expect(gold.remainingQuota, equals(200));
      expect(gold.canRecord, isTrue);

      // 3. Platinum Tier
      final platinum = SellerProfile(
        id: 'user-platinum',
        email: 'platinum@test.com',
        sellerName: 'Waqas',
        storeName: 'Waqas Daraz Store',
        phone: '03003333333',
        plan: 'platinum',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 29)),
        monthlyQuota: 999999,
        videosThisMonth: 15,
      );

      expect(platinum.isUnlimited, isTrue);
      expect(platinum.remainingQuota, equals(999999));
      expect(platinum.isQuotaReached, isFalse);
      expect(platinum.canRecord, isTrue);
    });

    test('QUOTA-02: Real-time decrementing quota calculation', () {
      final initialGold = SellerProfile(
        id: 'user-gold-01',
        email: 'seller@test.com',
        sellerName: 'Gold Seller',
        storeName: 'Daraz Store',
        phone: '',
        plan: 'gold',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 30)),
        monthlyQuota: 200,
        videosThisMonth: 0,
      );

      expect(initialGold.remainingQuota, equals(200));

      // After 1 video recorded
      final after1 = initialGold.copyWith(videosThisMonth: 1);
      expect(after1.remainingQuota, equals(199));
      expect(after1.isQuotaReached, isFalse);
      expect(after1.canRecord, isTrue);

      // After 50 videos recorded
      final after50 = initialGold.copyWith(videosThisMonth: 50);
      expect(after50.remainingQuota, equals(150));
      expect(after50.isQuotaReached, isFalse);
      expect(after50.canRecord, isTrue);

      // After 199 videos recorded (1 order left)
      final after199 = initialGold.copyWith(videosThisMonth: 199);
      expect(after199.remainingQuota, equals(1));
      expect(after199.isQuotaReached, isFalse);
      expect(after199.canRecord, isTrue);
    });

    test('QUOTA-03: Monthly limit lockout triggers at exact limit', () {
      final reachedGold = SellerProfile(
        id: 'user-gold-02',
        email: 'seller@test.com',
        sellerName: 'Gold Seller',
        storeName: 'Daraz Store',
        phone: '',
        plan: 'gold',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 15)),
        monthlyQuota: 200,
        videosThisMonth: 200,
      );

      // Verify quota is reached and recording is locked
      expect(reachedGold.isQuotaReached, isTrue);
      expect(reachedGold.remainingQuota, equals(0));
      expect(reachedGold.canRecord, isFalse);

      // Even if recorded count exceeds monthly limit somehow, quota remains 0 and locked
      final exceededGold = reachedGold.copyWith(videosThisMonth: 205);
      expect(exceededGold.isQuotaReached, isTrue);
      expect(exceededGold.remainingQuota, equals(0));
      expect(exceededGold.canRecord, isFalse);
    });

    test('QUOTA-04: Platinum tier allows unlimited recording without quota exhaustion', () {
      final platinum = SellerProfile(
        id: 'user-platinum',
        email: 'platinum@test.com',
        sellerName: 'Platinum Seller',
        storeName: 'Daraz Store',
        phone: '',
        plan: 'platinum',
        isActive: true,
        expiresAt: DateTime.now().add(const Duration(days: 29)),
        monthlyQuota: 999999,
        videosThisMonth: 5000,
      );

      expect(platinum.isUnlimited, isTrue);
      expect(platinum.isQuotaReached, isFalse);
      expect(platinum.remainingQuota, equals(999999));
      expect(platinum.canRecord, isTrue);
    });

    test('QUOTA-05: Expiry date calculation locks access on day 31', () {
      final expiredSeller = SellerProfile(
        id: 'user-expired',
        email: 'expired@test.com',
        sellerName: 'Expired Seller',
        storeName: 'Daraz Store',
        phone: '',
        plan: 'gold',
        isActive: true,
        expiresAt: DateTime.now().subtract(const Duration(hours: 2)),
        monthlyQuota: 200,
        videosThisMonth: 10,
      );

      expect(expiredSeller.isExpired, isTrue);
      expect(expiredSeller.daysRemaining, equals(0));
      expect(expiredSeller.canRecord, isFalse);
    });
  });
}
