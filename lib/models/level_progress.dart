/// Bitta level bo'yicha o'yinchining progressi (qaysi so'zlar topilgan, yulduzlar).
class LevelProgress {
  final int levelId;
  final List<String> foundWords;
  final int starsEarned;
  final bool isCompleted;

  LevelProgress({
    required this.levelId,
    required this.foundWords,
    required this.starsEarned,
    required this.isCompleted,
  });

  factory LevelProgress.empty(int levelId) {
    return LevelProgress(
      levelId: levelId,
      foundWords: [],
      starsEarned: 0,
      isCompleted: false,
    );
  }

  LevelProgress copyWith({
    List<String>? foundWords,
    int? starsEarned,
    bool? isCompleted,
  }) {
    return LevelProgress(
      levelId: levelId,
      foundWords: foundWords ?? this.foundWords,
      starsEarned: starsEarned ?? this.starsEarned,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  Map<String, dynamic> toJson() => {
        'levelId': levelId,
        'foundWords': foundWords,
        'starsEarned': starsEarned,
        'isCompleted': isCompleted,
      };

  factory LevelProgress.fromJson(Map<String, dynamic> json) {
    return LevelProgress(
      levelId: json['levelId'] as int,
      foundWords: List<String>.from(json['foundWords'] as List),
      starsEarned: json['starsEarned'] as int,
      isCompleted: json['isCompleted'] as bool,
    );
  }
}
