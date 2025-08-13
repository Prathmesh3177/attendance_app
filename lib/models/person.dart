class Person {
  int? id;
  String name;
  int empCode; // numeric unique id starting from 1
  String role; // 'Staff' or 'Student'
  String? studentClass; // NEW: 8th, 9th, 10th (null for Staff)

  Person({
    this.id,
    required this.name,
    required this.empCode,
    required this.role,
    this.studentClass,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'empCode': empCode,
        'role': role,
        'studentClass': studentClass,
      };

  factory Person.fromMap(Map<String, dynamic> m) => Person(
        id: m['id'] as int?,
        name: m['name'] as String,
        empCode: m['empCode'] as int,
        role: m['role'] as String,
        studentClass: m['studentClass'] as String?,
      );
}
