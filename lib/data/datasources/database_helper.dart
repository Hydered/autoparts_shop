import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('autoparts.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    // Проверяем, что это не веб-платформа
    if (kIsWeb) {
      throw UnsupportedError(
        'SQLite не поддерживается на веб-платформе. '
        'Запустите приложение на Android или iOS устройстве/эмуляторе.'
      );
    }
 
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    // Проверяем, существует ли уже база данных (только для мобильных платформ)
    final exists = await databaseExists(path);

    if (!exists) {
      // Если БД не существует, копируем из assets
      try {
        await Directory(dirname(path)).create(recursive: true);
        final data = await rootBundle.load('assets/database/$filePath');
        final bytes = data.buffer.asUint8List();
        await File(path).writeAsBytes(bytes);
      } catch (e) {
        // Если не удалось загрузить из assets, создаем новую БД
        print('Could not load database from assets: $e');
        return await _createNewDatabase(path);
      }
    }

    // Открываем существующую БД
    return await openDatabase(
      path,
      version: 15,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
      onOpen: _ensureSalesColumns,
    );
  }

  /// Принудительно проверяем и добавляем недостающие колонки
  Future<void> _ensureSalesColumns(Database db) async {
    // === Проверяем структуру таблицы Sales ===
    final salesInfo = await db.rawQuery('PRAGMA table_info(Sales)');
    final salesColumns = salesInfo.map((c) => c['name'].toString().toLowerCase()).toSet();
    
    if (!salesColumns.contains('client_deleted_history')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN client_deleted_history INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (!salesColumns.contains('user_id')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN user_id INTEGER'); } catch (_) {}
      try { await db.execute('ALTER TABLE Sales ADD COLUMN client_deleted_history INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (!salesColumns.contains('created_at')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN created_at INTEGER'); } catch (_) {}
    }
    if (!salesColumns.contains('status')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN status TEXT DEFAULT \'completed\''); } catch (_) {}
    }
    if (!salesColumns.contains('order_number')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN order_number TEXT'); } catch (_) {}
    }
    if (!salesColumns.contains('total_price')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN total_price REAL'); } catch (_) {}
    }
    if (!salesColumns.contains('customername')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN CustomerName TEXT'); } catch (_) {}
    }
    if (!salesColumns.contains('notes')) {
      try { await db.execute('ALTER TABLE Sales ADD COLUMN Notes TEXT'); } catch (_) {}
    }

    // === Проверяем структуру таблицы Products ===
    final productsInfo = await db.rawQuery('PRAGMA table_info(Products)');
    final productsColumns = productsInfo.map((c) => c['name'].toString().toLowerCase()).toSet();
    
    if (!productsColumns.contains('min_quantity')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN min_quantity INTEGER DEFAULT 5'); } catch (_) {}
    }
    if (!productsColumns.contains('image_url')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN image_url TEXT'); } catch (_) {}
    }
    if (!productsColumns.contains('created_at')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN created_at INTEGER'); } catch (_) {}
    }
    if (!productsColumns.contains('updated_at')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN updated_at INTEGER'); } catch (_) {}
    }
    if (!productsColumns.contains('stock')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN stock INTEGER DEFAULT 0'); } catch (_) {}
    }
    if (!productsColumns.contains('sku')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN sku TEXT'); } catch (_) {}
    }
    // Для совместимости со старой БД: добавляем category_id если есть только CategoryId
    if (!productsColumns.contains('category_id') && productsColumns.contains('categoryid')) {
      try { await db.execute('ALTER TABLE Products ADD COLUMN category_id INTEGER'); } catch (_) {}
      try { await db.execute('UPDATE Products SET category_id = CategoryId WHERE category_id IS NULL'); } catch (_) {}
    }
    if (!productsColumns.contains('name') && productsColumns.contains('name')) {
      // SQLite имена колонок регистронезависимы, но на всякий случай
    }
    // Добавляем id если есть только Id
    if (!productsColumns.contains('id')) {
      // В SQLite нельзя переименовать колонку, но SELECT работает регистронезависимо
    }

    // === Проверяем наличие и структуру таблицы SaleItems ===
    await db.execute('''
      CREATE TABLE IF NOT EXISTS SaleItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES Sales(id),
        FOREIGN KEY (product_id) REFERENCES Products(id)
      )
    ''');

    // === Проверяем и обновляем структуру таблицы ProductCharacteristics ===
    final pcInfo = await db.rawQuery('PRAGMA table_info(ProductCharacteristics)');
    final pcColumns = pcInfo.map((c) => c['name'].toString().toLowerCase()).toSet();

    // Если есть старая структура с characteristic_id, нужно пересоздать таблицу
    if (pcColumns.contains('characteristic_id')) {
      print('Обнаружена старая структура ProductCharacteristics. Пересоздаю таблицу...');

      // Сохраняем старые данные (если возможно получить связанные названия)
      final oldData = await db.rawQuery('''
        SELECT pc.product_id, c.name, c.unit, pc.value
        FROM ProductCharacteristics pc
        LEFT JOIN Characteristics c ON pc.characteristic_id = c.id
        WHERE c.name IS NOT NULL
      ''');

      // Удаляем старую таблицу
      await db.execute('DROP TABLE ProductCharacteristics');

      // Создаем новую таблицу с упрощенной структурой
      await db.execute('''
        CREATE TABLE ProductCharacteristics (
          product_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          unit TEXT,
          value TEXT NOT NULL,
          PRIMARY KEY (product_id, name),
          FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
        )
      ''');

      // Восстанавливаем данные в новой структуре
      for (final row in oldData) {
        try {
          await db.insert('ProductCharacteristics', {
            'product_id': row['product_id'],
            'name': row['name'],
            'unit': row['unit'],
            'value': row['value'].toString(),
          }, conflictAlgorithm: ConflictAlgorithm.ignore);
        } catch (e) {
          print('Ошибка при восстановлении характеристики: $e');
        }
      }

      print('Таблица ProductCharacteristics пересоздана и данные восстановлены');
    }

    // Проверяем структуру таблицы SaleItems и добавляем недостающие колонки
    final saleItemsInfo = await db.rawQuery('PRAGMA table_info(SaleItems)');
    final saleItemsColumns = saleItemsInfo.map((c) => c['name'].toString().toLowerCase()).toSet();
    
    if (!saleItemsColumns.contains('sale_id')) {
      try { await db.execute('ALTER TABLE SaleItems ADD COLUMN sale_id INTEGER'); } catch (_) {}
    }
    if (!saleItemsColumns.contains('product_id')) {
      try { await db.execute('ALTER TABLE SaleItems ADD COLUMN product_id INTEGER'); } catch (_) {}
    }
    if (!saleItemsColumns.contains('quantity')) {
      try { await db.execute('ALTER TABLE SaleItems ADD COLUMN quantity INTEGER'); } catch (_) {}
    }
    if (!saleItemsColumns.contains('price')) {
      try { await db.execute('ALTER TABLE SaleItems ADD COLUMN price REAL'); } catch (_) {}
    }
    
    // Копируем данные из старых колонок если они есть
    if (saleItemsColumns.contains('saleid') && saleItemsColumns.contains('sale_id')) {
      try { await db.execute('UPDATE SaleItems SET sale_id = SaleId WHERE sale_id IS NULL'); } catch (_) {}
    }
    if (saleItemsColumns.contains('productid') && saleItemsColumns.contains('product_id')) {
      try { await db.execute('UPDATE SaleItems SET product_id = ProductId WHERE product_id IS NULL'); } catch (_) {}
    }
    if (saleItemsColumns.contains('priceatsale') && saleItemsColumns.contains('price')) {
      try { await db.execute('UPDATE SaleItems SET price = PriceAtSale WHERE price IS NULL'); } catch (_) {}
    }

    // === Проверяем наличие таблиц характеристик ===
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Characteristics (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        unit TEXT,
        UNIQUE(name, unit)
      )
    ''');

    await db.execute('''
      CREATE TABLE IF NOT EXISTS ProductCharacteristics (
        product_id INTEGER NOT NULL,
        characteristic_id INTEGER NOT NULL,
        value TEXT NOT NULL,
        PRIMARY KEY (product_id, characteristic_id),
        FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE,
        FOREIGN KEY (characteristic_id) REFERENCES Characteristics(id) ON DELETE CASCADE
      )
    ''');

    // === Проверяем наличие таблицы CartItems ===
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CartItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
      )
    ''');


    // Для тестирования: устанавливаем stock = 0 для товара "Амортизатор KYB"
    try {
      print('DatabaseHelper: начинаем обновление товара "Амортизатор KYB"');
      final beforeUpdate = await db.rawQuery('SELECT id, name, stock FROM Products WHERE name LIKE ?', ['%Амортизатор KYB%']);
      print('DatabaseHelper: товар до обновления: $beforeUpdate');

      await db.execute('UPDATE Products SET stock = 0 WHERE name LIKE ?', ['%Амортизатор KYB%']);
      print('DatabaseHelper: SQL UPDATE выполнен');

      // Проверим результат
      final result = await db.rawQuery('SELECT id, name, stock FROM Products WHERE name LIKE ?', ['%Амортизатор KYB%']);
      print('DatabaseHelper: результат обновления: $result');
    } catch (e) {
      print('DatabaseHelper: ошибка при обновлении товара: $e');
    }

    // Исправляем пути к изображениям при каждом открытии БД
    await updateProductImages(db);
  }

  Future<Database> _createNewDatabase(String path) async {
    return await openDatabase(
      path,
      version: 15,
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    // Categories table (упрощенная версия из SQL)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Categories (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        Name TEXT NOT NULL UNIQUE
      )
    ''');

    // Products table (объединенная версия)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Products (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        price REAL NOT NULL,
        image_url TEXT,
        category_id INTEGER NOT NULL,
        sku TEXT UNIQUE,
        min_quantity INTEGER DEFAULT 5,
        stock INTEGER DEFAULT 0,
        created_at INTEGER,
        updated_at INTEGER,
        FOREIGN KEY (category_id) REFERENCES Categories(id)
      )
    ''');

    // Таблица Stock удалена - остатки хранятся в поле Products.stock

    // Sales table (обновленная версия с поддержкой user_id)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Sales (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        created_at INTEGER NOT NULL,
        user_id INTEGER NOT NULL,
        status TEXT DEFAULT 'completed',
        order_number TEXT,
        total_price REAL,
        Notes TEXT,
        FOREIGN KEY (user_id) REFERENCES Users(Id)
      )
    ''');

    // SaleItems table (обновленная версия с snake_case)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS SaleItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        sale_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        price REAL NOT NULL,
        FOREIGN KEY (sale_id) REFERENCES Sales(id),
        FOREIGN KEY (product_id) REFERENCES Products(id)
      )
    ''');

    // Users table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Users (
        Id INTEGER PRIMARY KEY AUTOINCREMENT,
        FullName TEXT NOT NULL,
        Phone TEXT NOT NULL,
        Address TEXT NOT NULL,
        Email TEXT NOT NULL UNIQUE,
        PasswordHash TEXT NOT NULL,
        Role TEXT NOT NULL DEFAULT 'client'
      )
    ''');

    // ProductCharacteristics (для характеристик товара - упрощенная структура)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ProductCharacteristics (
        product_id INTEGER NOT NULL,
        name TEXT NOT NULL,
        unit TEXT,
        value TEXT NOT NULL,
        PRIMARY KEY (product_id, name),
        FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
      )
    ''');

    // CartItems table (для хранения корзин пользователей)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS CartItems (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER,
        product_id INTEGER NOT NULL,
        quantity INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
      )
    ''');

    // Favorites table (для хранения избранных товаров пользователей)
    await db.execute('''
      CREATE TABLE IF NOT EXISTS Favorites (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        user_id INTEGER NOT NULL,
        product_id INTEGER NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (user_id) REFERENCES Users(Id) ON DELETE CASCADE,
        FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE,
        UNIQUE(user_id, product_id)
      )
    ''');

    // Indexes
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_category_id ON Products(category_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_sales_created_at ON Sales(created_at)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_products_sku ON Products(sku)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saleitems_sale_id ON SaleItems(sale_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_saleitems_product_id ON SaleItems(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pc_product_id ON ProductCharacteristics(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_pc_characteristic_id ON ProductCharacteristics(characteristic_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_c_name_unit ON Characteristics(name, unit)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cartitems_user_id ON CartItems(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON Favorites(user_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_product_id ON Favorites(product_id)');
    await db.execute('CREATE INDEX IF NOT EXISTS idx_cartitems_product_id ON CartItems(product_id)');

    // Исправляем пути к изображениям товаров в базе данных
    await updateProductImages(db);

    // Seed data: создаём админа по умолчанию
    await db.execute('''
      INSERT OR IGNORE INTO Users (FullName, Phone, Address, Email, PasswordHash, Role)
      VALUES ('Администратор', '-', '-', 'admin@admin.ru', 'admin', 'admin')
    ''');

    // Seed data: добавляем популярные характеристики товаров
    await db.execute('''
      INSERT OR IGNORE INTO Characteristics (name, unit)
      VALUES
        ('Вес', 'кг'),
        ('Длина', 'мм'),
        ('Ширина', 'мм'),
        ('Высота', 'мм'),
        ('Диаметр', 'мм'),
        ('Материал', NULL),
        ('Цвет', NULL),
        ('Мощность', 'Вт'),
        ('Напряжение', 'В'),
        ('Объем', 'л'),
        ('Вместимость', 'шт'),
        ('Толщина', 'мм'),
        ('Размер', NULL),
        ('Бренд', NULL),
        ('Модель', NULL),
        ('Тип', NULL),
        ('Форма', NULL),
        ('Количество', 'шт'),
        ('Масса', 'г'),
        ('Плотность', 'г/см³')
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Миграция на версию 2: добавляем новые поля и таблицы
      try {
        // Добавляем новые поля в Products, если их нет
        await db.execute('ALTER TABLE Products ADD COLUMN Brand TEXT');
        await db.execute('ALTER TABLE Products ADD COLUMN ImageUrl TEXT');
        await db.execute('ALTER TABLE Products ADD COLUMN SKU TEXT');
        await db.execute('ALTER TABLE Products ADD COLUMN MinQuantity INTEGER DEFAULT 5');
        await db.execute('ALTER TABLE Products ADD COLUMN CreatedAt INTEGER');
        await db.execute('ALTER TABLE Products ADD COLUMN UpdatedAt INTEGER');
      } catch (e) {
        // Поля могут уже существовать
        print('Ошибка миграции: $e');
      }

      // Таблица Stock больше не используется - остатки хранятся в Products.stock

      await db.execute('''
        CREATE TABLE IF NOT EXISTS SaleItems (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          SaleId INTEGER NOT NULL,
          ProductId INTEGER NOT NULL,
          Quantity INTEGER NOT NULL,
          PriceAtSale REAL NOT NULL,
          FOREIGN KEY (SaleId) REFERENCES Sales(Id),
          FOREIGN KEY (ProductId) REFERENCES Products(Id)
        )
      ''');

      // Обновляем/создаём таблицу Users
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Users (
          Id INTEGER PRIMARY KEY AUTOINCREMENT,
          FullName TEXT NOT NULL,
          Phone TEXT NOT NULL,
          Address TEXT NOT NULL,
          Email TEXT NOT NULL UNIQUE,
          PasswordHash TEXT NOT NULL,
          Role TEXT NOT NULL DEFAULT 'client'
        )
      ''');
      // На случай существующей старой версии Users добавляем недостающие поля
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN FullName TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN Phone TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN Address TEXT');
      } catch (_) {}

      // Добавляем индексы
      await db.execute('CREATE INDEX IF NOT EXISTS idx_saleitems_sale_id ON SaleItems(sale_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_saleitems_product_id ON SaleItems(product_Id)');
    }
    
    if (oldVersion < 3) {
      // Миграция на версию 3: добавляем недостающие колонки в Users
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN FullName TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN Phone TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Users ADD COLUMN Address TEXT');
      } catch (_) {}
      // Обновляем значение по умолчанию для Role
      try {
        await db.execute('UPDATE Users SET Role = \'client\' WHERE Role = \'User\' OR Role IS NULL');
      } catch (_) {}
      // Добавляем колонку stock в Products, если её нет
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN stock INTEGER DEFAULT 0');
      } catch (_) {}
    }
    
    if (oldVersion < 4) {
      // Миграция на версию 4: добавляем недостающие колонки в Products (snake_case)
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN min_quantity INTEGER DEFAULT 5');
      } catch (_) {
        // Колонка может уже существовать, игнорируем ошибку
      }
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN image_url TEXT');
      } catch (_) {
        // Колонка может уже существовать, игнорируем ошибку
      }
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN created_at INTEGER');
      } catch (_) {
        // Колонка может уже существовать, игнорируем ошибку
      }
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN updated_at INTEGER');
      } catch (_) {
        // Колонка может уже существовать, игнорируем ошибку
      }
    }
    
    if (oldVersion < 5) {
      // Миграция на версию 5: гарантируем наличие всех необходимых колонок в Products (snake_case)
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN min_quantity INTEGER DEFAULT 5');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN image_url TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN created_at INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Products ADD COLUMN updated_at INTEGER');
      } catch (_) {}
    }
    
    if (oldVersion < 6) {
      // Миграция на версию 6: добавляем недостающие колонки в таблицу Sales
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN user_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN created_at INTEGER');
      } catch (_) {
        // Если created_at не существует, но есть SaleDate, копируем данные
        try {
          await db.execute('ALTER TABLE Sales ADD COLUMN created_at INTEGER');
          await db.execute('UPDATE Sales SET created_at = SaleDate WHERE created_at IS NULL');
        } catch (_) {}
      }
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN status TEXT DEFAULT \'completed\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN order_number TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN total_price REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN CustomerName TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN Notes TEXT');
      } catch (_) {}
    }

    if (oldVersion < 7) {
      // Миграция на версию 7: добавляем таблицы для характеристик товара
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Characteristics (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          unit TEXT,
          UNIQUE(name, unit)
        )
      ''');

      await db.execute('''
        CREATE TABLE IF NOT EXISTS ProductCharacteristics (
          product_id INTEGER NOT NULL,
          characteristic_id INTEGER NOT NULL,
          value TEXT NOT NULL,
          PRIMARY KEY (product_id, characteristic_id),
          FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE,
          FOREIGN KEY (characteristic_id) REFERENCES Characteristics(id) ON DELETE CASCADE
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_pc_product_id ON ProductCharacteristics(product_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_pc_characteristic_id ON ProductCharacteristics(characteristic_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_c_name_unit ON Characteristics(name, unit)');
    }

    if (oldVersion < 9) {
      // Миграция на версию 9: добавляем недостающие колонки в Sales
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN user_id INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN created_at INTEGER');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN status TEXT DEFAULT \'completed\'');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN order_number TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN total_price REAL');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN CustomerName TEXT');
      } catch (_) {}
      try {
        await db.execute('ALTER TABLE Sales ADD COLUMN Notes TEXT');
      } catch (_) {}
    }

    if (oldVersion < 10) {
      // Миграция на версию 10: добавляем таблицу CartItems
      await db.execute('''
        CREATE TABLE IF NOT EXISTS CartItems (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER,
          product_id INTEGER NOT NULL,
          quantity INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
        )
      ''');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cartitems_user_id ON CartItems(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_cartitems_product_id ON CartItems(product_id)');
    }

    if (oldVersion < 11) {
      // Миграция на версию 11: обновляем структуру ProductCharacteristics
      final pcInfo = await db.rawQuery('PRAGMA table_info(ProductCharacteristics)');
      final pcColumns = pcInfo.map((c) => c['name'].toString().toLowerCase()).toSet();

      // Если есть старая структура с characteristic_id, пересоздаем таблицу
      if (pcColumns.contains('characteristic_id')) {
        print('Миграция 11: Обновление структуры ProductCharacteristics');

        // Сохраняем старые данные
        final oldData = await db.rawQuery('''
          SELECT pc.product_id, c.name, c.unit, pc.value
          FROM ProductCharacteristics pc
          LEFT JOIN Characteristics c ON pc.characteristic_id = c.id
          WHERE c.name IS NOT NULL
        ''');

        // Удаляем старую таблицу
        await db.execute('DROP TABLE ProductCharacteristics');

        // Создаем новую таблицу
        await db.execute('''
          CREATE TABLE ProductCharacteristics (
            product_id INTEGER NOT NULL,
            name TEXT NOT NULL,
            unit TEXT,
            value TEXT NOT NULL,
            PRIMARY KEY (product_id, name),
            FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE
          )
        ''');

        // Восстанавливаем данные
        for (final row in oldData) {
          try {
            await db.insert('ProductCharacteristics', {
              'product_id': row['product_id'],
              'name': row['name'],
              'unit': row['unit'],
              'value': row['value'].toString(),
            }, conflictAlgorithm: ConflictAlgorithm.ignore);
          } catch (e) {
            print('Ошибка при восстановлении характеристики: $e');
          }
        }

        // Удаляем индексы старой структуры
        try { await db.execute('DROP INDEX idx_pc_characteristic_id'); } catch (_) {}
        try { await db.execute('DROP INDEX idx_c_name_unit'); } catch (_) {}

        // Создаем новый индекс
        await db.execute('CREATE INDEX IF NOT EXISTS idx_pc_product_id ON ProductCharacteristics(product_id)');

        print('Миграция 11: ProductCharacteristics успешно обновлена');
      }
    }

    if (oldVersion < 12) {
      // Миграция на версию 12: добавляем таблицу Favorites
      await db.execute('''
        CREATE TABLE IF NOT EXISTS Favorites (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id INTEGER NOT NULL,
          product_id INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          FOREIGN KEY (user_id) REFERENCES Users(Id) ON DELETE CASCADE,
          FOREIGN KEY (product_id) REFERENCES Products(id) ON DELETE CASCADE,
          UNIQUE(user_id, product_id)
        )
      ''');

      await db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_user_id ON Favorites(user_id)');
      await db.execute('CREATE INDEX IF NOT EXISTS idx_favorites_product_id ON Favorites(product_id)');

      print('Миграция 12: таблица Favorites создана');
    }

    if (oldVersion < 13) {
      // Миграция на версию 13: устанавливаем stock = 0 для первого товара для тестирования
      try {
        await db.execute('UPDATE Products SET stock = 0 WHERE id = 1');
        print('Миграция 13: установлено stock = 0 для товара с id = 1');
      } catch (e) {
        print('Миграция 13: ошибка при обновлении товара: $e');
      }
    }

    if (oldVersion < 14) {
      // Миграция на версию 14: устанавливаем stock = 0 для товара "Амортизатор KYB"
      try {
        // Сначала посмотрим, какие товары есть
        final productsBefore = await db.rawQuery('SELECT id, name, stock FROM Products WHERE name LIKE ?', ['%Амортизатор KYB%']);
        print('Миграция 14: товары до обновления: $productsBefore');

        final result = await db.rawQuery('UPDATE Products SET stock = 0 WHERE name LIKE ?', ['%Амортизатор KYB%']);
        print('Миграция 14: SQL результат: $result');

        // Проверим после обновления
        final productsAfter = await db.rawQuery('SELECT id, name, stock FROM Products WHERE name LIKE ?', ['%Амортизатор KYB%']);
        print('Миграция 14: товары после обновления: $productsAfter');

        print('Миграция 14: выполнена успешно');
      } catch (e) {
        print('Миграция 14: ошибка при обновлении товара: $e');
      }
    }

    if (oldVersion < 15) {
      // Миграция на версию 15: принудительно устанавливаем stock = 0 для товара "Амортизатор KYB"
      try {
        print('Миграция 15: начинаем принудительное обновление товара "Амортизатор KYB"');

        // Сначала посмотрим все товары
        final allProducts = await db.rawQuery('SELECT id, name, stock FROM Products ORDER BY id');
        print('Миграция 15: все товары в базе: $allProducts');

        // Найдем товар "Амортизатор KYB"
        final targetProduct = await db.rawQuery('SELECT id, name, stock FROM Products WHERE name LIKE ?', ['%Амортизатор KYB%']);
        print('Миграция 15: целевой товар: $targetProduct');

        if (targetProduct.isNotEmpty) {
          final productId = targetProduct.first['id'];
          await db.execute('UPDATE Products SET stock = 0 WHERE id = ?', [productId]);
          print('Миграция 15: установлено stock = 0 для товара id = $productId');

          // Проверим результат
          final result = await db.rawQuery('SELECT id, name, stock FROM Products WHERE id = ?', [productId]);
          print('Миграция 15: результат: $result');
        } else {
          print('Миграция 15: товар "Амортизатор KYB" не найден');
        }

        print('Миграция 15: выполнена успешно');
      } catch (e) {
        print('Миграция 15: ошибка: $e');
      }
    }
  }


  /// Обновляет пути к изображениям товаров в базе данных
  Future<void> updateProductImages(Database db) async {
    try {
      final products = await db.query('Products');

      int updatedCount = 0;
      for (final product in products) {
        final name = (product['name'] as String? ?? '').toLowerCase();

        String? imagePath;
        if (name.contains('gates') && (name.contains('ремень') || name.contains('грм'))) {
          imagePath = 'assets/images/gates_grm_1.png';
        }
        else if (name.contains('bosch') && name.contains('масляный')) {
          imagePath = 'assets/images/bosch_filter_2.png';
        } else if (name.contains('bosch') && name.contains('фильтр')) {
          imagePath = 'assets/images/bosch_filter_1.png';
        }
        else if (name.contains('ate') && name.contains('диск')) {
          imagePath = 'assets/images/ate_disc_1.png';
        } else if (name.contains('ate') && (name.contains('тормозной') || name.contains('колодки') || name.contains('тормозн') || name.contains('колодк'))) {
          imagePath = 'assets/images/ate_brake_1.png';
        }
        else if (name.contains('kyb') && (name.contains('амортизатор') || name.contains('амортиз'))) {
          imagePath = 'assets/images/kyb_amort_1.png';
        }
        else if (name.contains('mann') && name.contains('фильтр')) {
          imagePath = 'assets/images/mann_filter_1.png';
        }

        if (imagePath != null) {
          final currentImage = product['image_url'];
          if (currentImage != imagePath) {
            await db.update(
              'Products',
              {'image_url': imagePath},
              where: 'id = ?',
              whereArgs: [product['id']],
            );
            updatedCount++;
          }
        }
      }

      print('DatabaseHelper: обновлено изображений для $updatedCount товаров');
    } catch (e) {
      print('DatabaseHelper: ошибка обновления изображений: $e');
    }
  }

  /// Возвращает путь к файлу базы данных
  Future<String> getDatabasePath() async {
    final dbPath = await getDatabasesPath();
    return join(dbPath, 'autoparts.db');
  }



  /// Возвращает структуру таблицы (список колонок)
  Future<List<Map<String, dynamic>>> getTableStructure(String tableName) async {
    final db = await database;
    return await db.rawQuery('PRAGMA table_info($tableName)');
  }

  /// Возвращает данные из таблицы с пагинацией
  Future<List<Map<String, dynamic>>> getTableData(
    String tableName, {
    int limit = 100,
    int offset = 0,
  }) async {
    final db = await database;
    return await db.query(tableName, limit: limit, offset: offset);
  }

  /// Возвращает количество записей в таблице
  Future<int> getTableRowCount(String tableName) async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM $tableName');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<void> close() async {
    final db = await database;
    await db.close();
  }
}