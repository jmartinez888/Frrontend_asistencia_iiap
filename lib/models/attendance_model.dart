// ignore_for_file: constant_identifier_names

enum AttendanceType {
  CHECK_IN,
  CHECK_OUT;

  static AttendanceType fromString(String? type) {
    if (type?.toUpperCase() == 'CHECK_OUT') {
      return AttendanceType.CHECK_OUT;
    }
    return AttendanceType.CHECK_IN;
  }

  String get label => this == AttendanceType.CHECK_IN ? 'ENTRADA' : 'SALIDA';
}

enum AttendanceStatus {
  ON_TIME,
  RECORDED;

  static AttendanceStatus fromString(String? status) {
    if (status?.toUpperCase() == 'RECORDED') {
      return AttendanceStatus.RECORDED;
    }
    return AttendanceStatus.ON_TIME;
  }

  String get label => this == AttendanceStatus.ON_TIME ? 'A Tiempo' : 'Registrado';
}

class AttendanceModel {
  final String id;
  final String userId;
  final DateTime timestamp;
  final AttendanceType type;
  final AttendanceStatus status;
  final String? scannedQrHash;
  final String? markedById;
  final String? userName;
  final String? userEmail;
  final String? userDocument;
  final String? markedByName;
  final double? latitude;
  final double? longitude;
  final String? deviceId;
  final bool isManual;
  final String? observation;

  AttendanceModel({
    required this.id,
    required this.userId,
    required this.timestamp,
    required this.type,
    required this.status,
    this.scannedQrHash,
    this.markedById,
    this.userName,
    this.userEmail,
    this.userDocument,
    this.markedByName,
    this.latitude,
    this.longitude,
    this.deviceId,
    this.isManual = false,
    this.observation,
  });

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    final userMap = json['user'] is Map ? json['user'] as Map<String, dynamic> : null;
    final markedByMap = json['marked_by'] is Map ? json['marked_by'] as Map<String, dynamic> : null;

    final parsedTimestamp = json['timestamp'] != null
        ? DateTime.tryParse(json['timestamp'].toString())?.toLocal() ?? DateTime.now()
        : DateTime.now();

    return AttendanceModel(
      id: json['id']?.toString() ?? '',
      userId: json['user_id']?.toString() ?? userMap?['id']?.toString() ?? '',
      timestamp: parsedTimestamp,
      type: AttendanceType.fromString(json['type']?.toString()),
      status: AttendanceStatus.fromString(json['status']?.toString()),
      scannedQrHash: json['scanned_qr_hash']?.toString(),
      markedById: json['marked_by_id']?.toString() ?? markedByMap?['id']?.toString(),
      userName: json['user_name']?.toString() ?? userMap?['full_name']?.toString(),
      userEmail: json['user_email']?.toString() ?? userMap?['email']?.toString(),
      userDocument: userMap?['document_number']?.toString(),
      markedByName: json['marked_by_name']?.toString() ?? markedByMap?['full_name']?.toString(),
      latitude: json['latitude'] != null ? double.tryParse(json['latitude'].toString()) : null,
      longitude: json['longitude'] != null ? double.tryParse(json['longitude'].toString()) : null,
      deviceId: json['device_id']?.toString(),
      isManual: json['is_manual'] == true,
      observation: json['observation']?.toString(),
    );
  }
}
