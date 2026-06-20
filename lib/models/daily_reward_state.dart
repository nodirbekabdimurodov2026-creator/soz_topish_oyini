/// Kunlik kirish mukofotlari va streak (ketma-ket kunlar) holatini saqlaydi.
class DailyRewardState {
  final DateTime? lastClaimDate;
  final int currentStreak; // ketma-ket necha kun kirgan
  final int longestStreak;
  final bool claimedToday;

  DailyRewardState({
    required this.lastClaimDate,
    required this.currentStreak,
    required this.longestStreak,
    required this.claimedToday,
  });

  factory DailyRewardState.initial() => DailyRewardState(
        lastClaimDate: null,
        currentStreak: 0,
        longestStreak: 0,
        claimedToday: false,
      );

  /// 7 kunlik tsikl bo'yicha mukofot miqdori (oxirgi kun eng katta bonus).
  /// Bu klassik "kunlik kirish" mexanikasi - har 7 kunda qaytadan boshlanadi,
  /// progress yo'qolmaydi degan tuyg'u beradi, lekin doimiy yangilanish bor.
  static const List<int> rewardCycle = [10, 15, 20, 25, 30, 40, 100];

  int get nextRewardAmount {
    final dayInCycle = currentStreak % 7;
    return rewardCycle[dayInCycle];
  }

  DailyRewardState copyWith({
    DateTime? lastClaimDate,
    int? currentStreak,
    int? longestStreak,
    bool? claimedToday,
  }) {
    return DailyRewardState(
      lastClaimDate: lastClaimDate ?? this.lastClaimDate,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      claimedToday: claimedToday ?? this.claimedToday,
    );
  }

  Map<String, dynamic> toJson() => {
        'lastClaimDate': lastClaimDate?.toIso8601String(),
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
      };

  factory DailyRewardState.fromJson(Map<String, dynamic> json) {
    return DailyRewardState(
      lastClaimDate: json['lastClaimDate'] != null
          ? DateTime.parse(json['lastClaimDate'] as String)
          : null,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      claimedToday: false, // har doim yangi sessiyada qayta tekshiriladi
    );
  }
}
