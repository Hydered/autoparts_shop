
class Receipt {
  final String companyName;
  final String hotline;
  final String owner;
  final DateTime dateTime;
  final List<ReceiptItem> items;
  final double total;
  final double vatRate; // НДС в процентах (например, 20)
  final double vatAmount;
  final String paymentMethod;
  final String cashier;
  final String? customerName;
  final String? notes;
  final String? orderNumber;
  
  // Фискальные данные
  final String? kktRegistrationNumber; // РН ККТ
  final String? fiscalDriveNumber; // ФН
  final String? fiscalDocumentNumber; // ФД
  final String? fiscalFeature; // ФП

  Receipt({
    required this.companyName,
    required this.hotline,
    required this.owner,
    required this.dateTime,
    required this.items,
    required this.total,
    this.vatRate = 20.0,
    required this.vatAmount,
    this.paymentMethod = 'НАЛИЧНЫМИ',
    this.cashier = 'Администратор',
    this.customerName,
    this.notes,
    this.orderNumber,
    this.kktRegistrationNumber,
    this.fiscalDriveNumber,
    this.fiscalDocumentNumber,
    this.fiscalFeature,
  });
}

class ReceiptItem {
  final String productName;
  final double quantity;
  final double unitPrice;
  final double total;
  final double vatRate;

  ReceiptItem({
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    this.vatRate = 20.0,
  });
}
