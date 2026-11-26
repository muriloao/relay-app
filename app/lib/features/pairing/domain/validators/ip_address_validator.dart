String normalizeIpAddress(String value) {
  final address = value.trim();
  if (address.startsWith('[') && address.endsWith(']')) {
    return address.substring(1, address.length - 1);
  }
  return address;
}

bool isValidIpAddress(String value) {
  var address = normalizeIpAddress(value);
  if (_isValidIpv4(address)) return true;
  if (!address.contains(':') || address.contains('%')) return false;

  final compressionAt = address.indexOf('::');
  final compressed = compressionAt >= 0;
  if (compressed && address.indexOf('::', compressionAt + 2) >= 0) return false;
  if (compressed &&
      (address.substring(0, compressionAt).endsWith(':') ||
          address.substring(compressionAt + 2).startsWith(':'))) {
    return false;
  }

  if (address.contains('.')) {
    final lastColon = address.lastIndexOf(':');
    if (lastColon < 0 || !_isValidIpv4(address.substring(lastColon + 1))) {
      return false;
    }
    address = '${address.substring(0, lastColon + 1)}0:0';
  }

  final groups = address.split(':');
  if (compressed) {
    final left = address.substring(0, compressionAt);
    final right = address.substring(compressionAt + 2);
    final groupCount =
        (left.isEmpty ? 0 : left.split(':').length) +
        (right.isEmpty ? 0 : right.split(':').length);
    if (groupCount >= 8) return false;
  } else if (groups.length != 8) {
    return false;
  }

  return groups
      .where((group) => group.isNotEmpty)
      .every((group) => RegExp(r'^[0-9a-fA-F]{1,4}$').hasMatch(group));
}

bool _isValidIpv4(String address) {
  final parts = address.split('.');
  if (parts.length != 4) return false;
  return parts.every((part) {
    if (!RegExp(r'^\d{1,3}$').hasMatch(part)) return false;
    final octet = int.parse(part);
    return octet >= 0 && octet <= 255;
  });
}
