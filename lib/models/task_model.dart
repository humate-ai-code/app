class Task {
  final String id;
  String title;
  String description;
  DateTime? dueDate;
  bool isCompleted;
  String? sourceConversationId;
  String? sourceMessageId;
  String status; // 'pending', 'done', 'in_progress'

  Task({
    required this.id,
    required this.title,
    this.description = '',
    this.dueDate,
    this.isCompleted = false,
    this.sourceConversationId,
    this.sourceMessageId,
    this.status = 'pending',
  });

  // Serialization helpers if needed later
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'dueDate': dueDate?.toIso8601String(),
      'isCompleted': isCompleted,
      'sourceConversationId': sourceConversationId,
      'sourceMessageId': sourceMessageId,
      'status': status,
    };
  }

  factory Task.fromJson(Map<String, dynamic> json) {
    return Task(
      id: json['id'],
      title: json['title'],
      description: json['description'] ?? '',
      dueDate: json['dueDate'] != null ? DateTime.parse(json['dueDate']) : null,
      isCompleted: json['isCompleted'] ?? false,
      sourceConversationId: json['sourceConversationId'],
      sourceMessageId: json['sourceMessageId'],
      status: json['status'] ?? 'pending',
    );
  }
}
