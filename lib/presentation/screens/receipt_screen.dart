import 'package:flutter/material.dart';
import '../../domain/entities/receipt.dart';
import '../../core/constants/app_colors.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';
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
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  receipt.companyName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Горячая линия: ${receipt.hotline}'),
                pw.Text('Владелец: ${receipt.owner}'),
                pw.SizedBox(height: 15),
                pw.Center(child: pw.Text('ДОБРО ПОЖАЛОВАТЬ!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.Center(child: pw.Text('КАССОВЫЙ ЧЕК', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                pw.SizedBox(height: 15),
                pw.Text(
                  'ЧЕК №${receipt.orderNumber ?? 'Н/Д'}',
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
                pw.Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(receipt.dateTime)}'),
                pw.Text('Кассир: ${receipt.cashier}'),
                pw.Text('Покупатель: ${receipt.customerName}'),
                pw.SizedBox(height: 10),
                pw.Text('Товары:', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 10),
                pw.Table(
                  children: [
                    pw.TableRow(
                      children: [
                        pw.Text('Наименование', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Кол-во', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Цена', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                        pw.Text('Сумма', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                      ],
                    ),
                    ...receipt.items.map((item) => pw.TableRow(
                      children: [
                        pw.Text(item.productName),
                        pw.Text(item.quantity.toString()),
                        pw.Text(NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.unitPrice)),
                        pw.Text(NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.total)),
                      ],
                    )),
                  ],
                ),
                pw.SizedBox(height: 10),
                pw.Text('Итого: ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(receipt.total)}'),
                pw.Text('НДС ${receipt.vatRate}%: ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(receipt.vatAmount)}'),
                pw.Text('Способ оплаты: ${receipt.paymentMethod}'),
                if (receipt.notes?.isNotEmpty ?? false) ...[
                  pw.SizedBox(height: 10),
                  pw.Text('Заметка: ${receipt.notes}'),
                ],
                pw.SizedBox(height: 20),
                pw.Text('Спасибо за покупку!', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              ],
            );
          },
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/receipt_${receipt.orderNumber ?? 'unknown'}_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('PDF сохранён: ${file.path}')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Чек'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: () => _exportToPDF(context),
            tooltip: 'Экспорт в PDF',
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Шапка
            Center(
              child: Text(
                receipt.companyName,
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('Горячая линия: ${receipt.hotline}')),
            Center(child: Text('Владелец: ${receipt.owner}')),
            const SizedBox(height: 20),

            // Информация о чеке
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: AppColors.primary),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ЧЕК №${receipt.orderNumber ?? 'Н/Д'}',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text('Дата: ${DateFormat('dd.MM.yyyy HH:mm').format(receipt.dateTime)}'),
                  Text('Кассир: ${receipt.cashier}'),
                  Text('Покупатель: ${receipt.customerName}'),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Товары
            const Text(
              'Товары:',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Table(
              border: TableBorder.all(),
              children: [
                const TableRow(
                  children: [
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Наименование', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Кол-во', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Цена', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                    Padding(
                      padding: EdgeInsets.all(8),
                      child: Text('Сумма', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
                ...receipt.items.map((item) => TableRow(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(item.productName),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(item.quantity.toString()),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.unitPrice)),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(item.total)),
                    ),
                  ],
                )),
              ],
            ),
            const SizedBox(height: 20),

            // Итого
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Итого:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(
                        NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(receipt.total),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('НДС ${receipt.vatRate}%:'),
                      Text(NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(receipt.vatAmount)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text('Способ оплаты: ${receipt.paymentMethod}'),
                ],
              ),
            ),

            // Заметка
            if (receipt.notes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 20),
              const Text(
                'Заметка:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  border: Border.all(color: AppColors.textSecondary.withOpacity(0.3)),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(receipt.notes!),
              ),
            ],

            const SizedBox(height: 30),
            const Center(
              child: Text(
                'Спасибо за покупку!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
