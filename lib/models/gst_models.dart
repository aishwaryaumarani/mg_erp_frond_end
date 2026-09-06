/// GST document state as the backend reports it.
///
/// These mirror the normalised responses from /api/gst and
/// /api/sales-invoices/{id}/gst-status -- nothing provider-specific ever
/// reaches the app, and no credential is ever sent to it.
library;

class EInvoiceInfo {
  final String status; // NOT_GENERATED | GENERATING | GENERATED | CANCELLED | FAILED | UNKNOWN
  final String? irn;
  final String? ackNumber;
  final String? ackDate;
  final String? signedQrCode;
  final bool cancelled;
  final String? cancelledAt;
  final String? errorCode;
  final String? errorMessage;
  final String? environment;

  const EInvoiceInfo({
    this.status = 'NOT_GENERATED',
    this.irn,
    this.ackNumber,
    this.ackDate,
    this.signedQrCode,
    this.cancelled = false,
    this.cancelledAt,
    this.errorCode,
    this.errorMessage,
    this.environment,
  });

  factory EInvoiceInfo.fromJson(Map<String, dynamic> j) => EInvoiceInfo(
        status: j['status'] ?? 'NOT_GENERATED',
        irn: j['irn'],
        ackNumber: j['ack_number'],
        ackDate: j['ack_date'],
        signedQrCode: j['signed_qr_code'],
        cancelled: j['cancelled'] == true,
        cancelledAt: j['cancelled_at'],
        errorCode: j['error_code'],
        errorMessage: j['error_message'],
        environment: j['environment'],
      );

  bool get isGenerated => status == 'GENERATED';
}

class EWayBillInfo {
  final int? id;
  final String status;
  final String? ewbNumber;
  final String? ewbDate;
  final String? validUntil;
  final String? transportMode;
  final String? transporterId;
  final String? vehicleNumber;
  final String? vehicleType;
  final int? distanceKm;
  final bool cancelled;
  final String? errorCode;
  final String? errorMessage;

  const EWayBillInfo({
    this.id,
    this.status = 'NOT_GENERATED',
    this.ewbNumber,
    this.ewbDate,
    this.validUntil,
    this.transportMode,
    this.transporterId,
    this.vehicleNumber,
    this.vehicleType,
    this.distanceKm,
    this.cancelled = false,
    this.errorCode,
    this.errorMessage,
  });

  factory EWayBillInfo.fromJson(Map<String, dynamic> j) => EWayBillInfo(
        id: j['id'],
        status: j['status'] ?? 'NOT_GENERATED',
        ewbNumber: j['ewb_number'],
        ewbDate: j['ewb_date'],
        validUntil: j['valid_until'],
        transportMode: j['transport_mode'],
        transporterId: j['transporter_id'],
        vehicleNumber: j['vehicle_number'],
        vehicleType: j['vehicle_type'],
        distanceKm: j['distance_km'],
        cancelled: j['cancelled'] == true,
        errorCode: j['error_code'],
        errorMessage: j['error_message'],
      );

  bool get isActive => status == 'GENERATED';
}

class GstStatus {
  final bool gstEnabled;
  final String eInvoiceStatus;
  final String eWayBillStatus;
  final EInvoiceInfo? eInvoice;
  final EWayBillInfo? eWayBill;

  const GstStatus({
    this.gstEnabled = false,
    this.eInvoiceStatus = 'NOT_GENERATED',
    this.eWayBillStatus = 'NOT_GENERATED',
    this.eInvoice,
    this.eWayBill,
  });

  factory GstStatus.fromJson(Map<String, dynamic> j) => GstStatus(
        gstEnabled: j['gst_enabled'] == true,
        eInvoiceStatus: j['einvoice_status'] ?? 'NOT_GENERATED',
        eWayBillStatus: j['eway_bill_status'] ?? 'NOT_GENERATED',
        eInvoice: j['einvoice'] == null
            ? null
            : EInvoiceInfo.fromJson((j['einvoice'] as Map).cast<String, dynamic>()),
        eWayBill: j['eway_bill'] == null
            ? null
            : EWayBillInfo.fromJson((j['eway_bill'] as Map).cast<String, dynamic>()),
      );
}

/// Transport details for generating an e-way bill. The invoice, customer
/// and company details are already on the server, so only what the server
/// cannot know is asked for.
class EWayBillRequestInput {
  String transportMode; // 1 road, 2 rail, 3 air, 4 ship
  int distanceKm;
  String? transporterId;
  String? transporterName;
  String? transportDocNo;
  String? vehicleNumber;
  String vehicleType; // R regular, O over-dimensional cargo

  EWayBillRequestInput({
    this.transportMode = '1',
    this.distanceKm = 0,
    this.transporterId,
    this.transporterName,
    this.transportDocNo,
    this.vehicleNumber,
    this.vehicleType = 'R',
  });

  Map<String, dynamic> toJson() => {
        'transport_mode': transportMode,
        'distance_km': distanceKm,
        'transporter_id': transporterId,
        'transporter_name': transporterName,
        'transport_doc_no': transportDocNo,
        'vehicle_number': vehicleNumber,
        'vehicle_type': vehicleType,
      };
}

const kTransportModes = {
  '1': 'Road',
  '2': 'Rail',
  '3': 'Air',
  '4': 'Ship',
};

/// The portal's own reason codes, so what the user picks is what is filed.
const kEInvoiceCancelReasons = {
  '1': 'Duplicate',
  '2': 'Data entry mistake',
  '3': 'Order cancelled',
  '4': 'Other',
};

const kEWayBillCancelReasons = {
  '1': 'Duplicate',
  '2': 'Order cancelled',
  '3': 'Data entry mistake',
  '4': 'Other',
};

const kVehicleUpdateReasons = {
  '1': 'Due to break down',
  '2': 'Transhipment',
  '3': 'Other',
  '4': 'First time vehicle',
};
