import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'core/constants/app_colors.dart';
import 'core/constants/app_strings.dart';
import 'data/datasources/database_helper.dart';
import 'data/datasources/category_local_datasource.dart';
import 'data/datasources/product_local_datasource.dart';
import 'data/datasources/sale_local_datasource.dart';
import 'data/datasources/user_local_datasource.dart';
import 'data/datasources/cart_local_datasource.dart';
import 'data/repositories/category_repository_impl.dart';
import 'data/repositories/product_repository_impl.dart';
import 'data/repositories/sale_repository_impl.dart';
import 'data/repositories/cart_repository_impl.dart';
import 'domain/services/inventory_service.dart';
import 'presentation/providers/category_provider.dart';
import 'presentation/providers/product_provider.dart';
import 'presentation/providers/sale_provider.dart';
import 'presentation/providers/home_provider.dart';
import 'presentation/providers/auth_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Инициализация русской локализации для дат
  await initializeDateFormatting('ru_RU', null);

  // Обновим пути к изображениям товаров в базе данных
  try {
    final db = await DatabaseHelper.instance.database;
    final products = await db.query('Products');
    print('Найдено товаров: ${products.length}');

    int updatedCount = 0;
    for (final product in products) {
      final name = (product['name'] as String? ?? '').toLowerCase();
      final id = product['id'];
      final currentImage = product['image_url'];

      print('Проверяем товар: "${product['name']}", изображение: $currentImage');

      String? imagePath;
      // Gates ремень ГРМ
      if (name.contains('gates') && (name.contains('ремень') || name.contains('грм'))) {
        imagePath = 'assets/images/gates_grm_1.png';
      }
      // Bosch фильтры
      else if (name.contains('bosch') && name.contains('масляный')) {
        imagePath = 'assets/images/bosch_filter_2.png';
      } else if (name.contains('bosch') && name.contains('фильтр')) {
        imagePath = 'assets/images/bosch_filter_1.png';
      }
      // ATE тормозная система
      else if (name.contains('ate') && name.contains('диск')) {
        imagePath = 'assets/images/ate_disc_1.png';
      } else if (name.contains('ate') && (name.contains('тормозной') || name.contains('колодки') || name.contains('тормозн') || name.contains('колодк'))) {
        imagePath = 'assets/images/ate_brake_1.png';
      }
      // KYB амортизаторы
      else if (name.contains('kyb') && (name.contains('амортизатор') || name.contains('амортиз'))) {
        imagePath = 'assets/images/kyb_amort_1.png';
      }
      // Mann фильтры
      else if (name.contains('mann') && name.contains('фильтр')) {
        imagePath = 'assets/images/mann_filter_1.png';
      }

      if (imagePath != null && currentImage != imagePath) {
        await db.update(
          'Products',
          {'image_url': imagePath},
          where: 'id = ?',
          whereArgs: [id],
        );
        print('✓ Обновлено: "${product['name']}" -> $imagePath');
        updatedCount++;
      } else if (imagePath != null && currentImage == imagePath) {
        print('✓ Уже правильное изображение: "${product['name']}" -> $imagePath');
      } else {
        print('✗ Не найдено подходящее изображение для: "${product['name']}"');
      }
    }

    print('Обновлено изображений: $updatedCount');
  } catch (e) {
    print('Ошибка обновления базы данных: $e');
  }

  // Проверяем платформу перед запуском
  if (kIsWeb) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Веб-платформа не поддерживается',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text(
                    'Это приложение работает только на Android и iOS устройствах.\n'
                    'Пожалуйста, запустите приложение на мобильном устройстве или эмуляторе.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return;
  }

  try {
    // Initialize database (только для мобильных платформ)
    final dbHelper = DatabaseHelper.instance;
    await dbHelper.database;

    // Initialize data sources
    final categoryDataSource = CategoryLocalDataSource(dbHelper);
    final productDataSource = ProductLocalDataSource(dbHelper);
    final saleDataSource = SaleLocalDataSource(dbHelper);
    final userDataSource = UserLocalDataSource(dbHelper);
    final cartDataSource = CartLocalDataSource(dbHelper);

    // Initialize repositories
    final categoryRepository = CategoryRepositoryImpl(categoryDataSource);
    final productRepository = ProductRepositoryImpl(productDataSource);
    final saleRepository = SaleRepositoryImpl(saleDataSource);
    final cartRepository = CartRepositoryImpl(cartDataSource);

    // Initialize services
    final inventoryService = InventoryService(productRepository, cartRepository);

    // Категории загружаются из БД, инициализация не требуется
    // await _initializeDefaultCategories(categoryRepository);

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => CategoryProvider(categoryRepository),
          ),
          ChangeNotifierProvider(
            create: (_) => ProductProvider(productRepository, cartRepository),
          ),
          ChangeNotifierProxyProvider<ProductProvider, SaleProvider>(
            create: (_) => SaleProvider(saleRepository, inventoryService, cartRepository, productRepository),
            update: (_, productProvider, saleProvider) {
              saleProvider ??= SaleProvider(saleRepository, inventoryService, cartRepository, productRepository);
              saleProvider.connectProductProvider(productProvider);
              return saleProvider;
            },
          ),
          ChangeNotifierProvider(
            create: (_) => HomeProvider(saleRepository, productRepository),
          ),
          ChangeNotifierProvider(
            create: (_) => AuthProvider(userDataSource),
          ),
        ],
        child: const MyApp(),
      ),
    );
  } catch (e, stackTrace) {
    // Если есть ошибка при инициализации, показываем её
    runApp(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                const Text(
                  'Ошибка при запуске приложения',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    e.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  stackTrace.toString(),
                  style: const TextStyle(fontSize: 10),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppStrings.appName,
      debugShowCheckedModeBanner: false,
      locale: const Locale('ru', 'RU'),
      supportedLocales: const [
        Locale('ru', 'RU'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: ThemeData(
        colorScheme: AppColors.colorScheme,
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.background,
        appBarTheme: const AppBarTheme(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        floatingActionButtonTheme: const FloatingActionButtonThemeData(
          backgroundColor: AppColors.accent,
          foregroundColor: Colors.white,
        ),
      ),
      home: const HomeScreen(),
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)),
          child: child ?? const SizedBox.shrink(),
        );
      },
    );
  }
}
