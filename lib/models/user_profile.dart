class UserProfile {
  final String name;
  final String company;
  final String email;

  const UserProfile({
    this.name = '',
    this.company = '',
    this.email = '',
  });

  bool get isEmpty => name.isEmpty && company.isEmpty && email.isEmpty;

  Map<String, dynamic> toJson() => {
        'name': name,
        'company': company,
        'email': email,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        name: json['name'] as String? ?? '',
        company: json['company'] as String? ?? '',
        email: json['email'] as String? ?? '',
      );

  UserProfile copyWith({
    String? name,
    String? company,
    String? email,
  }) {
    return UserProfile(
      name: name ?? this.name,
      company: company ?? this.company,
      email: email ?? this.email,
    );
  }
}
