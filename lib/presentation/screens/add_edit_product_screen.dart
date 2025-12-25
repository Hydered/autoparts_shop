import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../../domain/entities/product.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_strings.dart';
import '../../core/utils/image_utils.dart';
import '../providers/product_provider.dart';
import '../providers/category_provider.dart';
import '../widgets/product_image_widget.dart';
import '../../domain/entities/product_characteristic.dart';

class AddEditProductScreen extends StatefulWidget {
  final Product? product;

  const AddEditProductScreen({super.key, this.product});

  @override
  State<AddEditProductScreen> createState() => _AddEditProductScreenState();
}

class _AddEditProductScreenState extends State<AddEditProductScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  final _quantityController = TextEditingController();
  final _skuController = TextEditingController();
  final _imagePicker = ImagePicker();
  int? _selectedCategoryId;
  File? _selectedImage;
  String? _currentImagePath; // Путь к текущему изображению товара

  List<ProductCharacteristic> _editedCharacteristics = [];
  List<ProductCharacteristic>? _initialCharacteristics;
  bool _isLoadingCharacteristics = false;

  @override
  void initState() {
    super.initState();
    if (widget.product != null) {
      _nameController.text = widget.product!.name;
      _descriptionController.text = widget.product!.description;
      _priceController.text = widget.product!.price.toString();
      _quantityController.text = widget.product!.quantity.toString();
      _skuController.text = widget.product!.sku;
      _selectedCategoryId = widget.product!.categoryId;
      _currentImagePath = widget.product!.imagePath;
      _loadCharacteristics();
    }
  }

  Future<void> _loadCharacteristics() async {
    final productId = widget.product?.id;
    if (productId == null) return;
    setState(() => _isLoadingCharacteristics = true);
    try {
      final provider = context.read<ProductProvider>();
      final list = await provider.getCharacteristicsByProduct(productId);
      if (!mounted) return;
      setState(() {
        _initialCharacteristics = list;
        _editedCharacteristics = List<ProductCharacteristic>.from(list);
        _isLoadingCharacteristics = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingCharacteristics = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _quantityController.dispose();
    _skuController.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1024,
        maxHeight: 1024,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
          _currentImagePath = null; // Сбрасываем текущее изображение при выборе нового
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Ошибка при выборе изображения: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _removeImage() async {
    // Удаляем старое изображение, если оно было локальным файлом
    if (_currentImagePath != null && !ImageUtils.isAssetImage(_currentImagePath)) {
      await ImageUtils.deleteImage(_currentImagePath);
    }
    
    setState(() {
      _selectedImage = null;
      _currentImagePath = null;
    });
  }

  Future<void> _saveProduct() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedCategoryId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Пожалуйста, выберите категорию')),
      );
      return;
    }

    String? finalImagePath = _currentImagePath;

    // Если выбрано новое изображение, сохраняем его
    if (_selectedImage != null) {
      try {
        // Удаляем старое изображение, если оно было локальным файлом
        if (_currentImagePath != null && !ImageUtils.isAssetImage(_currentImagePath)) {
          await ImageUtils.deleteImage(_currentImagePath);
        }

        // Сохраняем новое изображение
        final fileName = ImageUtils.generateFileName(
          _skuController.text.trim().isEmpty 
            ? 'product_${DateTime.now().millisecondsSinceEpoch}'
            : _skuController.text.trim(),
        );
        finalImagePath = await ImageUtils.saveImage(_selectedImage!, fileName);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Ошибка при сохранении изображения: $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
    }

    final product = Product(
      id: widget.product?.id,
      name: _nameController.text.trim(),
      description: _descriptionController.text.trim(),
      categoryId: _selectedCategoryId!,
      price: double.parse(_priceController.text),
      quantity: int.parse(_quantityController.text),
      sku: _skuController.text.trim(),
      minQuantity: widget.product?.minQuantity ?? 5,
      imagePath: finalImagePath,
      createdAt: widget.product?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    final provider = context.read<ProductProvider>();
    // Теперь передаём product и характеристики вместе:
    final success = widget.product == null
        ? await provider.addProductWithCharacteristics(product, _editedCharacteristics)
        : await provider.updateProductWithCharacteristics(product, _editedCharacteristics);

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(widget.product == null
              ? 'Товар успешно добавлен'
              : 'Товар успешно обновлён'),
        ),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(provider.error ?? 'Не удалось сохранить товар'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null
            ? AppStrings.addProduct
            : AppStrings.editProduct),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Category
            Consumer<CategoryProvider>(
              builder: (context, categoryProvider, child) {
                if (categoryProvider.categories.isEmpty) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16),
                      child: Text('Нет доступных категорий. Сначала добавьте категории.'),
                    ),
                  );
                }
                return DropdownButtonFormField<int>(
                  value: _selectedCategoryId,
                  decoration: const InputDecoration(
                    labelText: AppStrings.category,
                    border: OutlineInputBorder(),
                  ),
                  items: categoryProvider.categories.map((category) {
                    return DropdownMenuItem<int>(
                      value: category.id,
                      child: Text(category.name),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      _selectedCategoryId = value;
                    });
                  },
                  validator: (value) {
                    if (value == null) {
                      return AppStrings.requiredField;
                    }
                    return null;
                  },
                );
              },
            ),
            const SizedBox(height: 16),
            // Image Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Изображение товара',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    // Показываем текущее или выбранное изображение
                    Stack(
                      children: [
                        Container(
                          width: double.infinity,
                          height: 200,
                          decoration: BoxDecoration(
                            color: AppColors.background,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppColors.textSecondary.withOpacity(0.2)),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: _selectedImage != null
                                ? Image.file(
                                    _selectedImage!,
                                    fit: BoxFit.cover,
                                  )
                                : ProductImageWidget(
                                    imagePath: _currentImagePath,
                                    width: double.infinity,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                          ),
                        ),
                        if (_selectedImage != null || _currentImagePath != null)
                          Positioned(
                            top: 8,
                            right: 8,
                            child: IconButton(
                              icon: const Icon(Icons.close, color: Colors.white),
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.black54,
                              ),
                              onPressed: _removeImage,
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.photo_library),
                            label: const Text('Галерея'),
                            onPressed: () => _pickImage(ImageSource.gallery),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.camera_alt),
                            label: const Text('Камера'),
                            onPressed: () => _pickImage(ImageSource.camera),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Name
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: AppStrings.productName,
                border: OutlineInputBorder(),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // SKU
            TextFormField(
              controller: _skuController,
              decoration: const InputDecoration(
                labelText: AppStrings.sku,
                border: OutlineInputBorder(),
              ),
              enabled: widget.product == null,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Description
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: AppStrings.description,
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Price
            TextFormField(
              controller: _priceController,
              decoration: const InputDecoration(
                labelText: AppStrings.price,
                border: OutlineInputBorder(),
                prefixText: '₽',
              ),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                if (double.tryParse(value) == null || double.parse(value) < 0) {
                  return 'Некорректная цена';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Quantity
            TextFormField(
              controller: _quantityController,
              decoration: const InputDecoration(
                labelText: AppStrings.quantity,
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return AppStrings.requiredField;
                }
                if (int.tryParse(value) == null || int.parse(value) < 0) {
                  return 'Некорректное количество';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            // Characteristics editor
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Характеристики товара',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 12),
                    if (_isLoadingCharacteristics)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: LinearProgressIndicator(),
              ),
                    CharacteristicsEditor(
                      key: ValueKey('pc_${widget.product?.id}_${_initialCharacteristics?.length ?? -1}'),
                      initialList: widget.product == null ? const [] : (_initialCharacteristics ?? const []),
                      onChanged: (list) => _editedCharacteristics = list,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saveProduct,
                child: const Text(AppStrings.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --- Виджет для редактирования характеристик товара ---
class CharacteristicsEditor extends StatefulWidget {
  final List<ProductCharacteristic>? initialList;
  final void Function(List<ProductCharacteristic>) onChanged;

  const CharacteristicsEditor({Key? key, this.initialList, required this.onChanged}) : super(key: key);

  @override
  State<CharacteristicsEditor> createState() => _CharacteristicsEditorState();
}

class _CharacteristicsEditorState extends State<CharacteristicsEditor> {
  late List<_CharacteristicEditingItem> _characteristics;

  // Предопределенные характеристики для автозапчастей
  static const List<Map<String, dynamic>> _predefinedCharacteristics = [
    {'name': 'Вес', 'unit': 'кг', 'type': 'numeric'},
    {'name': 'Длина', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Ширина', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Высота', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Диаметр', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Материал', 'unit': null, 'type': 'text'},
    {'name': 'Цвет', 'unit': null, 'type': 'text'},
    {'name': 'Мощность', 'unit': 'Вт', 'type': 'numeric'},
    {'name': 'Напряжение', 'unit': 'В', 'type': 'numeric'},
    {'name': 'Ток', 'unit': 'А', 'type': 'numeric'},
    {'name': 'Сопротивление', 'unit': 'Ом', 'type': 'numeric'},
    {'name': 'Объем', 'unit': 'л', 'type': 'numeric'},
    {'name': 'Вместимость', 'unit': 'л', 'type': 'numeric'},
    {'name': 'Давление', 'unit': 'атм', 'type': 'numeric'},
    {'name': 'Температура', 'unit': '°C', 'type': 'numeric'},
    {'name': 'Толщина', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Внутренний диаметр', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Наружный диаметр', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Количество', 'unit': 'шт', 'type': 'numeric'},
    {'name': 'Марка стали', 'unit': null, 'type': 'text'},
    {'name': 'Тип резьбы', 'unit': null, 'type': 'text'},
    {'name': 'Шаг резьбы', 'unit': 'мм', 'type': 'numeric'},
    {'name': 'Класс прочности', 'unit': null, 'type': 'text'},
    {'name': 'Рабочая температура', 'unit': '°C', 'type': 'numeric'},
    {'name': 'Допустимая нагрузка', 'unit': 'кг', 'type': 'numeric'},
    {'name': 'Срок службы', 'unit': 'лет', 'type': 'numeric'},
    {'name': 'Гарантия', 'unit': 'мес', 'type': 'numeric'},
  ];

  // Получить тип характеристики
  String _getCharacteristicType(String? characteristicName) {
    if (characteristicName == null) return 'text'; // Для custom характеристик

    final characteristic = _predefinedCharacteristics.firstWhere(
      (char) => char['name'] == characteristicName,
      orElse: () => {'type': 'text'},
    );

    return characteristic['type'] as String? ?? 'text';
  }

  // Получить уникальные названия характеристик для выпадающего списка
  List<String> get _uniqueCharacteristicNames {
    final names = _predefinedCharacteristics.map((char) => char['name'] as String).toSet();
    return names.toList()..sort();
  }

  @override
  void initState() {
    super.initState();
    _characteristics = widget.initialList != null
        ? widget.initialList!
            .map((e) => _createCharacteristicItemFromExisting(e))
            .toList()
        : [
            _CharacteristicEditingItem(
              value: TextEditingController(),
              unit: TextEditingController(),
            ),
          ];
    _emitChanged();
  }

  _CharacteristicEditingItem _createCharacteristicItemFromExisting(ProductCharacteristic e) {
    // Ищем совпадение с предопределенными характеристиками
    final predefined = _predefinedCharacteristics.firstWhere(
      (predef) => predef['name'] == e.name && predef['unit'] == e.unit,
      orElse: () => {'name': null, 'unit': null},
    );

    if (predefined['name'] != null) {
      // Найдено совпадение с предопределенной характеристикой
      return _CharacteristicEditingItem(
        selectedCharacteristic: e.name,
        value: TextEditingController(text: e.value),
        unit: TextEditingController(text: e.unit ?? ''),
      );
    } else {
      // Не найдено - используем как custom
      return _CharacteristicEditingItem(
        selectedCharacteristic: null, // null означает "Другое"
        customName: TextEditingController(text: e.name),
        value: TextEditingController(text: e.value),
        unit: TextEditingController(text: e.unit ?? ''),
      );
    }
  }

  void _addCharacteristic() {
    setState(() {
      _characteristics.add(_CharacteristicEditingItem(
        value: TextEditingController(),
        unit: TextEditingController(),
      ));
    });
    _emitChanged();
  }

  void _removeCharacteristic(int index) {
    setState(() {
      _characteristics.removeAt(index);
    });
    _emitChanged();
  }

  void _emitChanged() {
    final list = _characteristics
        .where((item) => item.name.trim().isNotEmpty && item.value.text.trim().isNotEmpty)
        .map((item) => ProductCharacteristic(
              name: item.name.trim(),
              value: item.value.text.trim(),
              unit: item.unit.text.trim().isEmpty ? null : item.unit.text.trim(),
            ))
        .toList();
    widget.onChanged(list);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_characteristics.isEmpty)
          const Text('Нет характеристик'),
        ..._characteristics.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: DropdownButtonFormField<String?>(
                        value: item.selectedCharacteristic,
                        decoration: const InputDecoration(labelText: 'Характеристика'),
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Другое...'),
                          ),
                          ..._uniqueCharacteristicNames.map((name) {
                            final variants = _predefinedCharacteristics.where((char) => char['name'] == name);
                            if (variants.length == 1) {
                              final char = variants.first;
                              return DropdownMenuItem<String?>(
                                value: name,
                                child: Text('${char['name']} ${char['unit'] != null ? '(${char['unit']})' : ''}'),
                              );
                            } else {
                              return DropdownMenuItem<String?>(
                                value: name,
                                child: Text(name),
                              );
                            }
                          }),
                        ],
                        onChanged: (value) {
                          setState(() {
                            item.selectedCharacteristic = value;
                            if (value != null) {
                              final predefined = _predefinedCharacteristics.firstWhere(
                                (char) => char['name'] == value,
                                orElse: () => {'unit': null},
                              );
                              item.unit.text = predefined['unit'] ?? '';
                            }
                          });
                          _emitChanged();
                        },
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline, color: Colors.red),
                      tooltip: 'Удалить',
                      onPressed: () => _removeCharacteristic(index),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
                if (item.isCustom) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: item.customName,
                    decoration: const InputDecoration(labelText: 'Название характеристики'),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zа-яА-Я\s\-]')),
                    ],
                    onChanged: (_) => _emitChanged(),
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: item.value,
                        decoration: const InputDecoration(labelText: 'Значение'),
                        inputFormatters: [
                          if (_getCharacteristicType(item.selectedCharacteristic) == 'numeric')
                            FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))
                          else
                            FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Zа-яА-Я\s\-]')),
                        ],
                        onChanged: (_) => _emitChanged(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 1,
                      child: TextField(
                        controller: item.unit,
                        decoration: const InputDecoration(labelText: 'Ед. изм.'),
                        readOnly: item.selectedCharacteristic != null,
                        onChanged: (_) => _emitChanged(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        ElevatedButton.icon(
          onPressed: _addCharacteristic,
          icon: const Icon(Icons.add),
          label: const Text('Добавить характеристику'),
        ),
      ],
    );
  }
}

class _CharacteristicEditingItem {
  String? selectedCharacteristic; // Выбранная характеристика или null для "Другое"
  final TextEditingController customName; // Для ручного ввода, если выбрано "Другое"
  final TextEditingController value;
  final TextEditingController unit;

  _CharacteristicEditingItem({
    this.selectedCharacteristic,
    TextEditingController? customName,
    required this.value,
    required this.unit,
  }) : customName = customName ?? TextEditingController();

  // Получить итоговое имя характеристики
  String get name => selectedCharacteristic ?? customName.text;

  // Проверить, выбрано ли "Другое"
  bool get isCustom => selectedCharacteristic == null;
}
