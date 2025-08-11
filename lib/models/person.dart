class Person {
  int? id;
  String name;
  int empCode; // numeric unique id starting from 1
  String role; // 'Staff' or 'Student'

  Person({this.id, required this.name, required this.empCode, required this.role});

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'empCode': empCode,
        'role': role,
      };

  factory Person.fromMap(Map<String, dynamic> m) => Person(
        id: m['id'] as int?,
        name: m['name'] as String,
        empCode: m['empCode'] as int,
        role: m['role'] as String,
      );
}