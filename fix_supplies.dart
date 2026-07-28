import 'dart:io';

void main() {
  final file = File('lib/screens/supplies_screen.dart');
  var content = file.readAsStringSync();

  content = content.replaceAll(
    "backgroundColor: const Color(0xFF1F1F1F),",
    "backgroundColor: Get.theme.cardColor,"
  );

  content = content.replaceAll(
    "style: const TextStyle(color: Colors.white),",
    "style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),"
  );

  content = content.replaceAll(
    "dropdownColor: const Color(0xFF1F1F1F),",
    "dropdownColor: Get.theme.cardColor,"
  );

  content = content.replaceAll(
    "style: TextStyle(color: Colors.white),",
    "style: TextStyle(color: Get.theme.textTheme.bodyLarge?.color),"
  );

  content = content.replaceAll(
    "fillColor: const Color(0xFF181818),",
    "fillColor: Get.theme.inputDecorationTheme.fillColor,"
  );

  content = content.replaceAll(
    "color: theme.appBarTheme.foregroundColor ?? Colors.white,",
    "color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,"
  );

  content = content.replaceAll(
    "color: Colors.white,\n                                fontSize: 18,\n                                fontWeight: FontWeight.bold,",
    "color: theme.textTheme.bodyLarge?.color,\n                                fontSize: 18,\n                                fontWeight: FontWeight.bold,"
  );

  content = content.replaceAll(
    "color: const Color(0xFF1F1F1F),",
    "color: Theme.of(context).cardColor,"
  );

  content = content.replaceAll(
    "border: Border.all(color: Colors.white.withOpacity(0.03), width: 1),",
    "border: Border.all(color: Theme.of(context).dividerColor, width: 1),"
  );

  content = content.replaceAll(
    "color: Colors.white,\n                                    fontSize: 17,",
    "color: Theme.of(context).textTheme.bodyLarge?.color,\n                                    fontSize: 17,"
  );

  content = content.replaceAll(
    "color: Colors.white.withOpacity(0.3),",
    "color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),"
  );

  content = content.replaceAll(
    "color: Colors.white,\n                              fontSize: 24,",
    "color: Theme.of(context).textTheme.bodyLarge?.color,\n                              fontSize: 24,"
  );

  content = content.replaceAll(
    "color: const Color(0xFF2C2C2C),",
    "color: Theme.of(context).cardColor,"
  );

  content = content.replaceAll(
    "color: Colors.white,\n                  fontSize: 14,\n                  fontWeight: FontWeight.w600,",
    "color: Theme.of(context).textTheme.bodyLarge?.color,\n                  fontSize: 14,\n                  fontWeight: FontWeight.w600,"
  );

  file.writeAsStringSync(content);
}
