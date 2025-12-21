import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sale_provider.dart';
import '../screens/auth_screen.dart';
import '../screens/profile_edit_screen.dart';

class ProfileSection extends StatelessWidget {
  const ProfileSection({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return SafeArea(
      bottom: false,
      child: Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 8, left: 12, right: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            if (auth.isGuest)
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  minimumSize: const Size(0, 0),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AuthScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.person_outline, size: 22),
                label: Text(
                  '${auth.displayName}  Войти',
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
              )
            else
              PopupMenuButton<String>(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.person_outline, size: 22),
                    const SizedBox(width: 4),
                    Text(
                      auth.displayName,
                      style: const TextStyle(fontSize: 15),
                    ),
                    const Icon(Icons.arrow_drop_down, size: 22),
                  ],
                ),
                onSelected: (value) async {
                  if (value == 'edit') {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const ProfileEditScreen(),
                      ),
                    );
                  } else if (value == 'logout') {
                    // Выполняем выход с обязательной очисткой корзины
                    // Это гарантирует, что при следующем входе корзина будет пустой
                    // и товары не перейдут к другому пользователю
                    final saleProvider = context.read<SaleProvider>();
                    await auth.logoutWithCartClear(saleProvider);

                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Вы вышли из аккаунта')),
                      );
                    }
                  }
                },
                itemBuilder: (context) {
                  final items = <PopupMenuEntry<String>>[];
                  if (auth.isClient) {
                    items.add(
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit, size: 20),
                            SizedBox(width: 8),
                            Text('Профиль'),
                          ],
                        ),
                      ),
                    );
                  }
                  items.add(
                    const PopupMenuItem(
                      value: 'logout',
                      child: Row(
                        children: [
                          Icon(Icons.logout, size: 20),
                          SizedBox(width: 8),
                          Text('Выйти'),
                        ],
                      ),
                    ),
                  );
                  return items;
                },
              ),
          ],
        ),
      ),
    );
  }
}
