import '../entities/receipt.dart';
import 'package:intl/intl.dart';

class ReceiptService {
  static const int _lineWidth = 48; // Ширина чека в символах
  
  /// Генерирует текст чека в формате, похожем на кассовый чек
  String generateReceiptText(Receipt receipt) {
    final buffer = StringBuffer();
    final dateFormat = DateFormat('dd.MM.yyyy HH:mm');
    
    // Заголовок компании
    _addCentered(buffer, receipt.companyName);
    buffer.writeln();
    _addCentered(buffer, 'Горячая линия: ${receipt.hotline}');
    buffer.writeln();
    _addCentered(buffer, receipt.owner);
    buffer.writeln();
    _addSeparator(buffer, '-');
    // Приветствие
    _addCentered(buffer, 'ДОБРО ПОЖАЛОВАТЬ!');
    buffer.writeln();
    _addCentered(buffer, 'КАССОВЫЙ ЧЕК');
    buffer.writeln();
    _addSeparator(buffer, '-');
    
    // Номер заказа (если есть)
    if (receipt.orderNumber != null && receipt.orderNumber!.isNotEmpty) {
      final orderLine = 'Заказ: ${receipt.orderNumber}';
      buffer.write(orderLine);
      _addPadding(buffer, _lineWidth - orderLine.length);
      buffer.writeln();
    }
    
    // Тип операции и дата
    _addRightAligned(buffer, 'ПРИХОД');
    buffer.writeln();
    _addRightAligned(buffer, dateFormat.format(receipt.dateTime));
    buffer.writeln();
    _addSeparator(buffer, '-');
    
    // Список товаров
    for (final item in receipt.items) {
      buffer.writeln(item.productName);
      final quantityStr = item.quantity.toStringAsFixed(3);
      final unitPriceStr = _formatCurrency(item.unitPrice);
      final totalStr = _formatCurrency(item.total);
      final itemLine = '$quantityStr x $unitPriceStr=$totalStr';
      buffer.write(itemLine);
      _addPadding(buffer, _lineWidth - itemLine.length);
      buffer.writeln();
      final vatLine = 'НДС ${item.vatRate.toStringAsFixed(0)}%';
      buffer.write(vatLine);
      _addPadding(buffer, _lineWidth - vatLine.length);
      buffer.writeln();
      buffer.write('ТОВАР');
      _addPadding(buffer, _lineWidth - 5);
      buffer.writeln();
    }
    
    _addSeparator(buffer, '-');
    buffer.writeln('ПОЛНЫЙ РАСЧЕТ');
    _addSeparator(buffer, '-');
    
    // Итог
    final totalStr = _formatCurrency(receipt.total);
    final itogLine = 'ИТОГ=$totalStr';
    buffer.write(itogLine);
    _addPadding(buffer, _lineWidth - itogLine.length);
    buffer.writeln();
    
    _addSeparator(buffer, '-');
    
    // Оплата
    buffer.writeln('ОПЛАТА');
    final paymentLine = '${receipt.paymentMethod}=$totalStr';
    buffer.write(paymentLine);
    _addPadding(buffer, _lineWidth - paymentLine.length);
    buffer.writeln();
    buffer.writeln('СНО:ОСН');
    
    // НДС
    final vatAmountStr = _formatCurrency(receipt.vatAmount);
    final vatLine = 'СУММА НДС ${receipt.vatRate.toStringAsFixed(0)}%$vatAmountStr';
    buffer.write(vatLine);
    _addPadding(buffer, _lineWidth - vatLine.length);
    buffer.writeln();
    
    // Кассир
    buffer.writeln('КАССИР:${receipt.cashier}');
    buffer.writeln('ПОДПИСЬ:');
    buffer.writeln();
    
    // Благодарность
    _addCentered(buffer, 'СПАСИБО ЗА ПОКУПКУ!');
    buffer.writeln();
    
    // Фискальные данные
    _addSeparator(buffer, '=');
    if (receipt.kktRegistrationNumber != null) {
      final kktLine = 'РН ККТ:${receipt.kktRegistrationNumber!}';
      buffer.write(kktLine);
      _addPadding(buffer, _lineWidth - kktLine.length);
      buffer.writeln();
    }
    if (receipt.fiscalDriveNumber != null) {
      final fnLine = 'ФН №:${receipt.fiscalDriveNumber!}';
      buffer.write(fnLine);
      _addPadding(buffer, _lineWidth - fnLine.length);
      buffer.writeln();
    }
    if (receipt.fiscalDocumentNumber != null) {
      final fdLine = 'ФД №:${receipt.fiscalDocumentNumber!}';
      buffer.write(fdLine);
      _addPadding(buffer, _lineWidth - fdLine.length);
      buffer.writeln();
    }
    if (receipt.fiscalFeature != null) {
      final fpLine = 'ФП:${receipt.fiscalFeature!}';
      buffer.write(fpLine);
      _addPadding(buffer, _lineWidth - fpLine.length);
      buffer.writeln();
    }
    
    return buffer.toString();
  }
  
  void _addCentered(StringBuffer buffer, String text) {
    final padding = (_lineWidth - text.length) ~/ 2;
    buffer.write(' ' * padding);
    buffer.write(text);
  }
  
  void _addRightAligned(StringBuffer buffer, String text, {int startPos = 0}) {
    final currentPos = buffer.length - startPos;
    final padding = _lineWidth - currentPos - text.length;
    if (padding > 0) {
      buffer.write(' ' * padding);
    }
    buffer.write(text);
  }
  
  void _addPadding(StringBuffer buffer, int count) {
    if (count > 0) {
      buffer.write(' ' * count);
    }
  }
  
  void _addSeparator(StringBuffer buffer, String char) {
    buffer.writeln(char * _lineWidth);
  }
  
  String _formatCurrency(double amount) {
    return amount.toStringAsFixed(2);
  }
  
  /// Вычисляет сумму НДС из общей суммы
  double calculateVatAmount(double total, double vatRate) {
    return total * vatRate / (100 + vatRate);
  }
}
