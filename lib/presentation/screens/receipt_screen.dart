import 'package:flutter/material.dart';
import '../../domain/entities/receipt.dart';
import '../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class ReceiptScreen extends StatelessWidget {
  final Receipt receipt;

  const ReceiptScreen({Key? key, required this.receipt}) : super(key: key);

  Future<void> _exportToPDF(BuildContext context) async {
    try {
      final pdf = pw.Document();

      pdf.addPage(
        pw.Page(
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text('Чек продажи',
                    style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 20),
                pw.Text('Номер заказа: ${receipt.orderNumber}'),
                pw.Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(receipt.dateTime)}'),
                pw.Text('Продавец: ${receipt.cashier}'),
                pw.SizedBox(height: 20),
                pw.Text('Товары:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                ...receipt.items.map((item) => pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('${item.productName} x${item.quantity}'),
                    pw.Text('${item.unitPrice} руб. за шт.'),
                    pw.Text('Итого: ${item.total} руб.'),
                    pw.SizedBox(height: 5),
                  ],
                )),
                pw.SizedBox(height: 20),
                pw.Text('Общая сумма: ${receipt.total} руб.',
                    style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              ],
            );
          },
        ),
      );

      // Сохраняем PDF в локальное хранилище
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/receipt_${receipt.orderNumber}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Чек сохранен: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ошибка при создании PDF')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чек продажи'),
        actions: [
          IconButton(
            icon: const Icon(Icons.download),
            onPressed: () => _exportToPDF(context),
            tooltip: 'Экспорт в PDF',
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Чек #${receipt.orderNumber}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(receipt.dateTime)}'),
                    Text('Продавец: ${receipt.cashier}'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Товары',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: receipt.items.length,
                itemBuilder: (context, index) {
                  final item = receipt.items[index];
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.productName,
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text('${item.quantity} шт. × ${item.unitPrice} руб.'),
                              ],
                            ),
                          ),
                          Text(
                            '${item.total} руб.',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Общая сумма:', style: TextStyle(fontSize: 16)),
                      Text('${receipt.total} руб.',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}