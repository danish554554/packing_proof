class SellerProfile {
  final String id;
  final String email;
  final String sellerName;
  final String storeName;
  final String phone;
  final String plan;
  final bool isActive;
  final DateTime expiresAt;
  final int monthlyQuota;
  final int videosThisMonth;
  final DateTime? quotaResetDate;
  final DateTime? createdAt;

  const SellerProfile({
    required this.id,
    required this.email,
    required this.sellerName,
    required this.storeName,
    required this.phone,
    required this.plan,
    required this.isActive,
    required this.expiresAt,
    required this.monthlyQuota,
    required this.videosThisMonth,
    this.quotaResetDate,
    this.createdAt,
  });

  factory SellerProfile.fromJson(Map<String, dynamic> json) {
    return SellerProfile(
      id: json['id'] as String? ?? '',
      email: json['email'] as String? ?? '',
      sellerName: json['seller_name'] as String? ?? 'Valued Seller',
      storeName: json['store_name'] as String? ?? '',
      phone: json['phone_number'] as String? ?? '',
      plan: (json['plan'] as String? ?? 'silver').toLowerCase(),
      isActive: json['is_active'] as bool? ?? true,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())?.toLocal() ??
              DateTime.now().add(const Duration(days: 30))
          : DateTime.now().add(const Duration(days: 30)),
      monthlyQuota: (json['monthly_quota'] as num?)?.toInt() ?? 100,
      videosThisMonth:
          (json['videos_recorded_this_month'] as num?)?.toInt() ?? 0,
      quotaResetDate: json['quota_reset_date'] != null
          ? DateTime.tryParse(json['quota_reset_date'].toString())?.toLocal()
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())?.toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'seller_name': sellerName,
      'store_name': storeName,
      'phone_number': phone,
      'plan': plan,
      'is_active': isActive,
      'expires_at': expiresAt.toIso8601String(),
      'monthly_quota': monthlyQuota,
      'videos_recorded_this_month': videosThisMonth,
      'quota_reset_date': quotaResetDate?.toIso8601String(),
      'created_at': createdAt?.toIso8601String(),
    };
  }

  /// Copy with updated values
  SellerProfile copyWith({
    String? id,
    String? email,
    String? sellerName,
    String? storeName,
    String? phone,
    String? plan,
    bool? isActive,
    DateTime? expiresAt,
    int? monthlyQuota,
    int? videosThisMonth,
    DateTime? quotaResetDate,
    DateTime? createdAt,
  }) {
    return SellerProfile(
      id: id ?? this.id,
      email: email ?? this.email,
      sellerName: sellerName ?? this.sellerName,
      storeName: storeName ?? this.storeName,
      phone: phone ?? this.phone,
      plan: plan ?? this.plan,
      isActive: isActive ?? this.isActive,
      expiresAt: expiresAt ?? this.expiresAt,
      monthlyQuota: monthlyQuota ?? this.monthlyQuota,
      videosThisMonth: videosThisMonth ?? this.videosThisMonth,
      quotaResetDate: quotaResetDate ?? this.quotaResetDate,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  bool get isExpired => DateTime.now().isAfter(expiresAt);

  int get daysRemaining {
    final diff = expiresAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }

  bool get isUnlimited => plan.toLowerCase() == 'platinum';

  bool get isQuotaReached => !isUnlimited && videosThisMonth >= monthlyQuota;

  bool get canRecord => isActive && !isExpired && !isQuotaReached;

  int get remainingQuota {
    if (isUnlimited) return 999999;
    final rem = monthlyQuota - videosThisMonth;
    return rem < 0 ? 0 : rem;
  }

  String get planDisplayName {
    switch (plan.toLowerCase()) {
      case 'gold':
        return 'Gold (200 Orders)';
      case 'platinum':
        return 'Platinum (Unlimited)';
      case 'silver':
      default:
        return 'Silver (100 Orders)';
    }
  }
}
