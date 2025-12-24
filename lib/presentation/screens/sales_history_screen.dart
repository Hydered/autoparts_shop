import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../domain/entities/sale.dart';
import '../../domain/entities/receipt.dart';
import '../providers/sale_provider.dart';
import '../providers/product_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/empty_state_widget.dart';
import '../widgets/loading_widget.dart';
import '../widgets/profile_section.dart';
import '../../core/utils/date_utils.dart' as app_date_utils;
import 'receipt_preview_screen.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:pdf/pdf.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  DateTime? _filterStartDate;
  DateTime? _filterEndDate;
  int? _selectedClientId; // Для отслеживания выбранного клиента

  // Кэш сгенерированных чеков для оптимизации
  final Map<String, Receipt> _receiptsCache = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      context.read<SaleProvider>().loadSales(refresh: true, userId: auth.isAdmin ? null : auth.userId);
    });
  }

  // Группировка продаж по клиентам
  Map<int, List<Sale>> _groupSalesByClient(List<Sale> sales) {
    final Map<int, List<Sale>> grouped = {};
    for (final sale in sales) {
      if (sale.userId != null) {
        grouped.putIfAbsent(sale.userId!, () => []).add(sale);
      }
    }
    return grouped;
  }

  Future<void> _selectDateRange() async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      locale: const Locale('ru', 'RU'),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: _filterStartDate != null && _filterEndDate != null
          ? DateTimeRange(start: _filterStartDate!, end: _filterEndDate!)
          : null,
      helpText: 'Выберите период',
      cancelText: 'Отмена',
      confirmText: 'Выбрать',
      errorFormatText: 'Неверный формат',
      errorInvalidText: 'Неверный диапазон',
      errorInvalidRangeText: 'Начальная дата должна быть раньше конечной',
      fieldStartLabelText: 'Начало периода',
      fieldEndLabelText: 'Конец периода',
    );

    if (picked != null) {
      setState(() {
        _filterStartDate = picked.start;
        _filterEndDate = picked.end;
      });
      context.read<SaleProvider>().filterSalesByDate(
            app_date_utils.DateUtils.getStartOfDay(picked.start),
            app_date_utils.DateUtils.getEndOfDay(picked.end),
          );
    }
  }

  Future<void> _exportToPDF() async {
    final saleProvider = context.read<SaleProvider>();
    final productProvider = context.read<ProductProvider>();

    try {
      final sales = saleProvider.sales;
      if (sales.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Нет продаж для экспорта')),
        );
        return;
      }

      final pdf = pw.Document();

      final List<List<String>> rows = [
        [
          'ID',
          'Товар',
          'SKU',
          'Кол-во',
          'Цена за ед.',
          'Сумма',
          'Дата',
          'Покупатель',
        ],
      ];

      for (final sale in sales) {
        final product = await productProvider.getProductById(sale.productId);
        rows.add([
          (sale.id ?? '').toString(),
          product?.name ?? 'Неизвестно',
          product?.sku ?? 'Н/Д',
          sale.quantity.toString(),
          NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
              .format(sale.unitPrice),
          NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
              .format(sale.totalPrice),
          app_date_utils.DateUtils.formatDateTime(sale.saleDate),
          sale.customerName ?? '',
        ]);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Text(
              'Отчёт по продажам',
              style: pw.TextStyle(
                fontSize: 18,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: rows.first,
              data: rows.sublist(1),
              headerStyle: pw.TextStyle(
                fontWeight: pw.FontWeight.bold,
              ),
              cellAlignment: pw.Alignment.centerLeft,
              headerDecoration: const pw.BoxDecoration(
                color: PdfColor.fromInt(0xFFE0E0E0),
              ),
            ),
          ],
        ),
      );

      final directory = await getApplicationDocumentsDirectory();
      final file = File(
        '${directory.path}/sales_report_${DateTime.now().millisecondsSinceEpoch}.pdf',
      );
      await file.writeAsBytes(await pdf.save());

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF-отчёт сохранён: ${file.path}'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта PDF: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _exportReceiptToPDF(Receipt receipt) async {
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Чек сохранён: ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка экспорта чека: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          const ProfileSection(),
          Padding(
            padding: const EdgeInsets.only(top: 8, left: 8, right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      return Text(
                        auth.isClient ? 'История покупок' : AppStrings.salesHistory,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      );
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_alt),
                    onPressed: _selectDateRange,
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (auth.isClient) {
                      return IconButton(
                        icon: const Icon(Icons.delete_forever),
                        tooltip: 'Очистить историю',
                        onPressed: () async {
                          final saleProvider = context.read<SaleProvider>();
                          final confirmed = await showDialog<bool>(
                            context: context,
                            builder: (context) => AlertDialog(
                              title: const Text('Очистить историю?'),
                              content: const Text('Вы действительно хотите удалить все покупки?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Отмена'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  style: TextButton.styleFrom(foregroundColor: Colors.red),
                                  child: const Text('Очистить'),
                                ),
                              ],
                            ),
                          );
                          if (confirmed == true) {
                            await saleProvider.clearClientHistory(auth.userId!);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Вся история покупок удалена')),
                              );
                            }
                          }
                        },
                      );
                    }
                    return const SizedBox.shrink();
                  },
                
                ),
                Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    if (!auth.isAdmin) return const SizedBox.shrink();
                    return IconButton(
                      icon: const Icon(Icons.picture_as_pdf),
                      onPressed: _exportToPDF,
                    );
                  },
                ),
              ],
            ),
          ),
          // Filter Info
          if (_filterStartDate != null && _filterEndDate != null)
            Container(
              padding: const EdgeInsets.all(8),
              color: AppColors.primary.withOpacity(0.1),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${app_date_utils.DateUtils.formatDateDisplay(_filterStartDate!)} - ${app_date_utils.DateUtils.formatDateDisplay(_filterEndDate!)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _filterStartDate = null;
                        _filterEndDate = null;
                      });
                      context.read<SaleProvider>().filterSalesByDate(null, null);
                    },
                    child: const Text('Очистить'),
                  ),
                ],
              ),
            ),
          // Sales List
          Expanded(
            child: Consumer<SaleProvider>(
              builder: (context, provider, child) {
                if (provider.isLoading && provider.sales.isEmpty) {
                  return const LoadingWidget();
                }

                if (provider.error != null && provider.sales.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          provider.error!,
                          style: const TextStyle(color: AppColors.error),
                        ),
                        const SizedBox(height: 16),
                        Consumer<AuthProvider>(
                          builder: (context, auth, _) {
                            return ElevatedButton(
                              onPressed: () => provider.loadSales(
                                refresh: true,
                                userId: auth.isAdmin ? null : auth.userId,
                              ),
                              child: const Text('Повторить'),
                            );
                          },
                        ),
                      ],
                    ),
                  );
                }

                if (provider.sales.isEmpty) {
                  return Consumer<AuthProvider>(
                    builder: (context, auth, _) {
                      final msg = auth.isClient
                          ? 'Покупки не найдены'
                          : 'Продажи не найдены';
                      return EmptyStateWidget(
                        message: msg,
                        icon: Icons.receipt_long_outlined,
                      );
                    },
                  );
                }

                return Consumer<AuthProvider>(
                  builder: (context, auth, _) {
                    // Для админа показываем список клиентов
                    if (auth.isAdmin) {
                      return RefreshIndicator(
                        onRefresh: () {
                          return provider.loadSales(
                            refresh: true,
                            userId: null,
                          );
                        },
                        child: _buildAdminView(provider.sales),
                      );
                    }
                    // Для клиентов обычный список
                    return RefreshIndicator(
                      onRefresh: () {
                        return provider.loadSales(
                          refresh: true,
                          userId: auth.userId,
                        );
                      },
                      child: _buildClientView(provider.sales),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Виджет для отображения списка клиентов (для админа)
  Widget _buildAdminView(List<Sale> sales) {
    final groupedByClient = _groupSalesByClient(sales);
    
    if (groupedByClient.isEmpty) {
      return const EmptyStateWidget(
        message: 'Продажи не найдены',
        icon: Icons.receipt_long_outlined,
      );
    }

    // Если выбран клиент, показываем его заказы
    if (_selectedClientId != null) {
      final clientSales = groupedByClient[_selectedClientId] ?? [];
      return _buildClientOrdersView(_selectedClientId!, clientSales);
    }

    // Иначе показываем список клиентов
    return ListView.builder(
      itemCount: groupedByClient.length,
      itemBuilder: (context, index) {
        final userId = groupedByClient.keys.elementAt(index);
        final clientSales = groupedByClient[userId]!;
        return FutureBuilder<Map<String, dynamic>?>(
          future: context.read<AuthProvider>().getUserDetailsById(userId),
          builder: (context, snapshot) {
            final userData = snapshot.data;
            final totalAmount = clientSales.fold<double>(
              0.0,
              (sum, sale) => sum + sale.totalPrice,
            );
            
            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: ListTile(
                leading: CircleAvatar(
                  child: Text(
                    userData?['FullName']?.toString().substring(0, 1).toUpperCase() ?? '?',
                  ),
                ),
                title: Text(
                  userData?['FullName'] ?? 'Клиент ID: $userId',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (userData != null) ...[
                      Text('Телефон: ${userData['Phone'] ?? 'Н/Д'}'),
                      Text('Email: ${userData['Email'] ?? 'Н/Д'}'),
                    ],
                    Text(
                      'Заказов: ${clientSales.length} | Всего: ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(totalAmount)}',
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                  ],
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  setState(() {
                    _selectedClientId = userId;
                  });
                },
              ),
            );
          },
        );
      },
    );
  }

  // Виджет для отображения заказов клиента, сгруппированных по номеру заказа
  Widget _buildClientOrdersView(int userId, List<Sale> sales) {
    // Группируем продажи по orderNumber
    final Map<String, List<Sale>> orderGroups = {};
    for (final sale in sales) {
      if (sale.orderNumber != null && sale.orderNumber!.isNotEmpty) {
        orderGroups.putIfAbsent(sale.orderNumber!, () => []).add(sale);
      }
    }
    // Сортируем по дате (по убыванию)
    final sortedOrders = orderGroups.values.toList()
      ..sort((a, b) => b.first.saleDate.compareTo(a.first.saleDate));
    return Column(
      children: [
        // Кнопка "Назад"
        Container(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () {
                  setState(() {
                    _selectedClientId = null;
                  });
                },
              ),
              FutureBuilder<Map<String, dynamic>?>(
                future: context.read<AuthProvider>().getUserDetailsById(userId),
                builder: (context, snapshot) {
                  final userData = snapshot.data;
                  return Expanded(
                    child: Text(
                      userData?['FullName'] ?? 'Клиент ID: $userId',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
        // Список заказов по orderNumber
        Expanded(
          child: ListView.builder(
            itemCount: sortedOrders.length,
            itemBuilder: (context, orderIndex) {
              final orderSales = sortedOrders[orderIndex];
              final firstSale = orderSales.first;
              final orderTotal = orderSales.fold<double>(
                0.0,
                (sum, sale) => sum + sale.totalPrice,
              );

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: ExpansionTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Дата: ${app_date_utils.DateUtils.formatDateDisplay(firstSale.saleDate)}',
                                  style: const TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  'ID продажи: ${(firstSale.orderNumber ?? '').isNotEmpty ? firstSale.orderNumber : (firstSale.id?.toString() ?? '—')}',
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                          IconButton(
                            icon: const Icon(Icons.visibility, color: AppColors.primary),
                            onPressed: () async {
final orderNumber = firstSale.orderNumber ?? '';
                                  if (orderNumber.isNotEmpty) {
                                    // Используем кэш чеков
                                    Receipt? receipt = _receiptsCache[orderNumber];
                                    if (receipt == null) {
                                      receipt = await context.read<SaleProvider>().generateReceiptForOrder(
                                        orderNumber,
                                        userId,
                                        ignoreClientDeletedHistory: true,
                                      );
                                      if (receipt != null) {
                                        _receiptsCache[orderNumber] = receipt;
                                      }
                                    }
                                    if (receipt != null) {
                                      // Получаем имя покупателя
                                      String? customerName;
                                      try {
                                        final auth = context.read<AuthProvider>();
                                        final userDetails = await auth.getUserDetailsById(userId);
                                        customerName = userDetails?['FullName'] as String?;
                                      } catch (e) {
                                        customerName = 'Клиент #$userId';
                                      }

                                      await Navigator.of(context).push(
                                        MaterialPageRoute(
                                          builder: (_) => ReceiptPreviewScreen(
                                            receipt: receipt!,
                                            customerName: customerName,
                                          ),
                                        ),
                                      );
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Не удалось сгенерировать чек')),
                                        );
                                      }
                                    }
                                  }
                            },
                            tooltip: 'Посмотреть чек',
                          ),
                          IconButton(
                            icon: const Icon(Icons.download, color: AppColors.primary),
                            onPressed: () async {
final orderNumber = firstSale.orderNumber ?? '';
                                  if (orderNumber.isNotEmpty) {
                                    // Используем кэш чеков
                                    Receipt? receipt = _receiptsCache[orderNumber];
                                    if (receipt == null) {
                                      receipt = await context.read<SaleProvider>().generateReceiptForOrder(
                                        orderNumber,
                                        userId,
                                        ignoreClientDeletedHistory: true,
                                      );
                                      if (receipt != null) {
                                        _receiptsCache[orderNumber] = receipt;
                                      }
                                    }
                                    if (receipt != null) {
                                      await _exportReceiptToPDF(receipt);
                                    } else {
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(content: Text('Не удалось сгенерировать чек')),
                                        );
                                      }
                                    }
                                  }
                            },
                            tooltip: 'Скачать чек',
                          ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  subtitle: Text(
                    '${orderSales.length} товар(ов) | ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(orderTotal)}',
                  ),
                  children: [
                    if ((firstSale.notes ?? '').trim().isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 8.0, right: 8.0, top: 6, bottom: 2),
                        child: Text(
                          'Заметка: ${firstSale.notes}',
                          style: const TextStyle(
                            fontSize: 13,
                            fontStyle: FontStyle.italic,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ...orderSales.map((sale) {
                    return FutureBuilder(
                      future: context.read<ProductProvider>().getProductById(sale.productId),
                      builder: (context, snapshot) {
                        final product = snapshot.data;
                        return ListTile(
                          title: Text(
                            product?.name ?? 'Product ID: ${sale.productId}',
                            style: const TextStyle(fontWeight: FontWeight.w500),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${sale.quantity} шт. x ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(sale.unitPrice)} = ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(sale.totalPrice)}',
                              ),
                            ],
                          ),
                          trailing: Text(
                            NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                                .format(sale.totalPrice),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        );
                      },
                    );
                  }).toList(),
                ]),
              );
            },
          ),
        ),
      ],
    );
  }

  // Виджет для отображения списка покупок клиента
  Widget _buildClientView(List<Sale> sales) {
    // Группировка по orderNumber (одна карта — один заказ, все товары внутри)
    final Map<String, List<Sale>> orderGroups = {};
    for (final sale in sales) {
      if (sale.orderNumber != null && sale.orderNumber!.isNotEmpty) {
      orderGroups.putIfAbsent(sale.orderNumber!, () => []).add(sale);
    }
    }
    // Сортировка по дате (по убыванию)
    final sortedOrders = orderGroups.values.toList()
      ..sort((a, b) => b.first.saleDate.compareTo(a.first.saleDate));
    return ListView.builder(
      itemCount: sortedOrders.length,
      itemBuilder: (context, orderIdx) {
        final orderSales = sortedOrders[orderIdx];
        final firstSale = orderSales.first;
        final totalAmount = orderSales.fold<double>(0.0, (sum, s) => sum + s.totalPrice);
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          child: ExpansionTile(
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Дата: ${app_date_utils.DateUtils.formatDateTime(firstSale.saleDate)}',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            'ID продажи: ${(firstSale.orderNumber ?? '').isNotEmpty ? firstSale.orderNumber : (firstSale.id?.toString() ?? '—')}',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.grey),
                          ),
                          Text(
                            'Сумма заказа: ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(totalAmount)}',
                            style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black54),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.visibility, color: AppColors.primary),
                          onPressed: () async {
                            final orderNumber = firstSale.orderNumber ?? '';
                            if (orderNumber.isNotEmpty) {
                              // Используем кэш чеков
                              Receipt? receipt = _receiptsCache[orderNumber];
                              final auth = context.read<AuthProvider>();
                              if (receipt == null) {
                                receipt = await context.read<SaleProvider>().generateReceiptForOrder(
                                  orderNumber,
                                  auth.userId!,
                                  ignoreClientDeletedHistory: auth.isAdmin,
                                );
                                if (receipt != null) {
                                  _receiptsCache[orderNumber] = receipt;
                                }
                              }
                              if (receipt != null) {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ReceiptPreviewScreen(
                                      receipt: receipt!,
                                      customerName: auth.fullName,
                                    ),
                                  ),
                                );
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Не удалось сгенерировать чек')),
                                  );
                                }
                              }
                            }
                          },
                          tooltip: 'Посмотреть чек',
                        ),
                        IconButton(
                          icon: const Icon(Icons.download, color: AppColors.primary),
                          onPressed: () async {
                            final orderNumber = firstSale.orderNumber ?? '';
                            if (orderNumber.isNotEmpty) {
                              // Используем кэш чеков
                              Receipt? receipt = _receiptsCache[orderNumber];
                              if (receipt == null) {
                                final auth = context.read<AuthProvider>();
                                receipt = await context.read<SaleProvider>().generateReceiptForOrder(
                                  orderNumber,
                                  auth.userId!,
                                  ignoreClientDeletedHistory: auth.isAdmin,
                                );
                                if (receipt != null) {
                                  _receiptsCache[orderNumber] = receipt;
                                }
                              }
                              if (receipt != null) {
                                await _exportReceiptToPDF(receipt);
                              } else {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Не удалось сгенерировать чек')),
                                  );
                                }
                              }
                            }
                          },
                          tooltip: 'Скачать чек',
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            children: orderSales.map((sale) => FutureBuilder(
              future: context.read<ProductProvider>().getProductById(sale.productId),
              builder: (context, snapshot) {
                final product = snapshot.data;
                return ListTile(
                  title: Text(
                    product?.name ?? 'Product ID: ${sale.productId}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${sale.quantity} шт. x ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(sale.unitPrice)} = ${NumberFormat.currency(locale: 'ru_RU', symbol: '₽').format(sale.totalPrice)}',
                    style: const TextStyle(fontWeight: FontWeight.w500),
                  ),
                  trailing: Text(
                    NumberFormat.currency(locale: 'ru_RU', symbol: '₽')
                        .format(sale.totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                );
              },
            )).toList(),
          ),
        );
      },
    );
  }
}