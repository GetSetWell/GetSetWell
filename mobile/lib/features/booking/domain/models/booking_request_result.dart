class BookingRequestResult {
  const BookingRequestResult({
    required this.requestId,
    required this.referenceCode,
    required this.requestType,
  });

  final String requestId;
  final String referenceCode;
  final String requestType;

  factory BookingRequestResult.fromJson(
    Map<String, dynamic> json,
  ) {
    return BookingRequestResult(
      requestId: json['request_id'] as String,
      referenceCode: json['reference_code'] as String,
      requestType: json['request_type'] as String,
    );
  }
}