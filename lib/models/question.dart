class Question {
  const Question({
    required this.id,
    required this.categoryId,
    required this.categoryKey,
    required this.difficultyKey,
    required this.questionKey,
    required this.optionsKeys,
    required this.correctIndex,
    required this.explanationKey,
    required this.signId,
    this.questionText,
    this.questionTextAr,
    this.options,
    this.optionsAr,
    this.explanation,
    this.explanationAr,
    this.imageUrl,
  });

  final String id;
  final String categoryId;
  final String categoryKey;
  final String difficultyKey;
  final String questionKey;
  final List<String> optionsKeys;
  final int correctIndex;
  final String? explanationKey;
  final String? signId;
  final String? questionText;
  final String? questionTextAr;
  final List<String>? options;
  final List<String>? optionsAr;
  final String? explanation;
  final String? explanationAr;
  final String? imageUrl;

  static String _categoryFromKey(String key) {
    final parts = key.split('.');
    return parts.isNotEmpty ? parts.last : key;
  }

  factory Question.fromJson(Map<String, dynamic> json) {
    final questionMap = json['question'] as Map<String, dynamic>?;
    final optionsList = json['options'] as List<dynamic>?;
    final explanationMap = json['explanation'] as Map<String, dynamic>?;
    final categoryKey = json['categoryKey'] as String? ??
        'quiz.categories.${json['category'] ?? json['categoryId'] ?? 'unknown'}';
    final difficultyKey = json['difficultyKey'] as String? ??
        'quiz.difficulty.${json['difficulty'] ?? 'easy'}';
    final questionKey = json['questionKey'] as String? ?? '';
    final categoryId = json['categoryId'] as String? ??
        json['category'] as String? ??
        _categoryFromKey(categoryKey);
    return Question(
      id: json['id'] as String,
      categoryId: categoryId,
      categoryKey: categoryKey,
      difficultyKey: difficultyKey,
      questionKey: questionKey,
      optionsKeys: List<String>.from(json['optionsKeys'] ?? const []),
      correctIndex: (json['correctIndex'] ?? json['correctAnswer'] ?? 0) as int,
      explanationKey: json['explanationKey'] as String?,
      signId: json['signId'] as String?,
      questionText: questionMap?['en'] as String?,
      questionTextAr: questionMap?['ar'] as String?,
      options: optionsList
          ?.map((option) => (option as Map<String, dynamic>)['en'] as String? ?? '')
          .toList(),
      optionsAr: optionsList
          ?.map((option) => (option as Map<String, dynamic>)['ar'] as String? ?? '')
          .toList(),
      explanation: explanationMap?['en'] as String?,
      explanationAr: explanationMap?['ar'] as String?,
      imageUrl: json['imageUrl'] as String?,
    );
  }
}
