
class Speaker {
  final String id;
  String name;
  final List<double> embedding;
  bool isUser;
  
  Speaker({
    required this.id,
    required this.name,
    required this.embedding,
    this.isUser = false,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'embedding': embedding,
    'isUser': isUser,
  };

  factory Speaker.fromJson(Map<String, dynamic> json) => Speaker(
    id: json['id'],
    name: json['name'],
    embedding: List<double>.from(json['embedding']),
    isUser: json['isUser'] ?? false,
  );
}
