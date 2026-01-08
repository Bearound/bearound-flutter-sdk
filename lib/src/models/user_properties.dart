class UserProperties {
  final String? internalId;
  final String? email;
  final String? name;
  final Map<String, String> customProperties;

  const UserProperties({
    this.internalId,
    this.email,
    this.name,
    this.customProperties = const {},
  });

  Map<String, dynamic> toJson() {
    final data = <String, dynamic>{};

    if (internalId != null && internalId!.isNotEmpty) {
      data['internalId'] = internalId;
    }
    if (email != null && email!.isNotEmpty) {
      data['email'] = email;
    }
    if (name != null && name!.isNotEmpty) {
      data['name'] = name;
    }

    data['customProperties'] = customProperties;

    return data;
  }
}
