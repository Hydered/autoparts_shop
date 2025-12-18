import 'dart:io';
import 'package:flutter/material.dart';
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

  @override
  void initState() {
    super.initState();
    _characteristics = widget.initialList != null
        ? widget.initialList!
            .map((e) => _CharacteristicEditingItem(
                  name: TextEditingController(text: e.name),
                  value: TextEditingController(text: e.value),
                  unit: TextEditingController(text: e.unit ?? ''),
                ))
            .toList()
        : [
            _CharacteristicEditingItem(
              name: TextEditingController(),
              value: TextEditingController(),
              unit: TextEditingController(),
            ),
          ];
    _emitChanged();
  }

  void _addCharacteristic() {
    setState(() {
      _characteristics.add(_CharacteristicEditingItem(
        name: TextEditingController(),
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
        .where((item) => item.name.text.trim().isNotEmpty && item.value.text.trim().isNotEmpty)
        .map((item) => ProductCharacteristic(
              name: item.name.text.trim(),
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
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: item.name,
                    decoration: const InputDecoration(labelText: 'Название'),
                    onChanged: (_) => _emitChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: item.value,
                    decoration: const InputDecoration(labelText: 'Значение'),
                    onChanged: (_) => _emitChanged(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: item.unit,
                    decoration: const InputDecoration(labelText: 'Ед. изм.'),
                    onChanged: (_) => _emitChanged(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: Colors.red),
                  tooltip: 'Удалить',
                  onPressed: () => _removeCharacteristic(index),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: ElevatedButton.icon(
            onPressed: _addCharacteristic,
            icon: const Icon(Icons.add),
            label: const Text('Добавить'),
          ),
        ),
      ],
    );
  }
}

class _CharacteristicEditingItem {
  final TextEditingController name;
  final TextEditingController value;
  final TextEditingController unit;
  _CharacteristicEditingItem({
    required this.name,
    required this.value,
    required this.unit,
  });
}
