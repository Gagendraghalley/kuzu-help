/// Every upload must go inside a folder named with the user's ID.
/// Storage security rules reject uploads anywhere else.
class StoragePaths {
  static String avatar(String userId) =>
      '$userId/avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';

  static String cid(String userId) => '$userId/cid.jpg';

  static String certificate(String userId) => '$userId/certificate.jpg';
}
