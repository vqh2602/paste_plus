enum ClipboardContentType {
  text,
  url,
  email,
  phone,
  code,
  color,
  json,
  file,
  image;

  static ClipboardContentType fromDatabase(String value) {
    return values.firstWhere(
      (type) => type.name == value,
      orElse: () => ClipboardContentType.text,
    );
  }
}
