import 'dart:io';

void main() {
  final file1 = File('lib/screens/invoice_generator_screen.dart');
  var content = file1.readAsStringSync();

  content = content.replaceAll(
    "const Text(\n          'New Invoice',\n          style: TextStyle(\n            color: Colors.white,",
    "Text(\n          'New Invoice',\n          style: TextStyle(\n            color: theme.appBarTheme.foregroundColor ?? theme.colorScheme.onSurface,"
  );
  
  content = content.replaceAll(
    "const Text(\n                        'Walk-in Customer',\n                        style: TextStyle(\n                          color: Colors.white,",
    "Text(\n                        'Walk-in Customer',\n                        style: TextStyle(\n                          color: theme.textTheme.bodyLarge?.color,"
  );

  content = content.replaceAll(
    "const Divider(color: Colors.white10, height: 1)",
    "Divider(color: theme.dividerColor, height: 1)"
  );

  content = content.replaceAll(
    "backgroundColor: const Color(0xFF1F1F1F),\n              foregroundColor: Colors.white,",
    "backgroundColor: theme.cardColor,\n              foregroundColor: theme.textTheme.bodyLarge?.color,"
  );

  content = content.replaceAll(
    "color: const Color(0xFF1F1F1F),\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Colors.white.withOpacity(0.05)),",
    "color: Theme.of(context).cardColor,\n        borderRadius: BorderRadius.circular(20),\n        border: Border.all(color: Theme.of(context).dividerColor),"
  );

  content = content.replaceAll(
    "style: const TextStyle(\n                                    color: Colors.white,\n                                    fontWeight: FontWeight.bold,\n                                    fontSize: 15,\n                                  ),",
    "style: TextStyle(\n                                    color: Theme.of(context).textTheme.bodyLarge?.color,\n                                    fontWeight: FontWeight.bold,\n                                    fontSize: 15,\n                                  ),"
  );

  content = content.replaceAll(
    "style: TextStyle(\n                              color: Colors.white.withOpacity(0.4),\n                              fontSize: 12,\n                            ),",
    "style: TextStyle(\n                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),\n                              fontSize: 12,\n                            ),"
  );

  content = content.replaceAll(
    "color: const Color(0xFF1F1F1F),\n              borderRadius: BorderRadius.circular(24),\n              border: Border.all(color: Colors.white.withOpacity(0.05)),",
    "color: Theme.of(context).cardColor,\n              borderRadius: BorderRadius.circular(24),\n              border: Border.all(color: Theme.of(context).dividerColor),"
  );

  content = content.replaceAll(
    "const Text(\n                        'Invoice Summary',\n                        style: TextStyle(\n                          color: Colors.white,",
    "Text(\n                        'Invoice Summary',\n                        style: TextStyle(\n                          color: Theme.of(context).textTheme.bodyLarge?.color,"
  );

  content = content.replaceAll(
    "style: const TextStyle(\n                          color: Colors.white,\n                          fontWeight: FontWeight.w900,\n                          fontSize: 20,\n                          letterSpacing: -0.5,\n                        ),",
    "style: TextStyle(\n                          color: Theme.of(context).textTheme.bodyLarge?.color,\n                          fontWeight: FontWeight.w900,\n                          fontSize: 20,\n                          letterSpacing: -0.5,\n                        ),"
  );

  content = content.replaceAll(
    "const Text(\n                    'Additional Details',\n                    style: TextStyle(\n                      color: Colors.white,",
    "Text(\n                    'Additional Details',\n                    style: TextStyle(\n                      color: Theme.of(context).textTheme.bodyLarge?.color,"
  );

  content = content.replaceAll(
    "color: Colors.white,\n                              borderRadius: BorderRadius.circular(16),",
    "color: Theme.of(context).colorScheme.surface,\n                              borderRadius: BorderRadius.circular(16),"
  );

  content = content.replaceAll(
    "style: TextStyle(\n                              color: Colors.white.withOpacity(0.3),\n                              fontSize: 10,\n                              fontFamily: 'monospace',\n                            ),",
    "style: TextStyle(\n                              color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),\n                              fontSize: 10,\n                              fontFamily: 'monospace',\n                            ),"
  );

  content = content.replaceAll(
    "style: TextStyle(\n                        color: Colors.white.withOpacity(0.3),\n                        fontWeight: FontWeight.bold,\n                        fontSize: 12,\n                      ),",
    "style: TextStyle(\n                        color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.3),\n                        fontWeight: FontWeight.bold,\n                        fontSize: 12,\n                      ),"
  );

  content = content.replaceAll(
    "style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),",
    "style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color, fontWeight: FontWeight.w600),"
  );

  content = content.replaceAll(
    "color: Colors.white.withOpacity(0.4),\n          fontSize: 14,",
    "color: Theme.of(context).textTheme.bodyLarge?.color?.withOpacity(0.4),\n          fontSize: 14,"
  );

  content = content.replaceAll(
    "fillColor: const Color(0xFF181818),",
    "fillColor: Theme.of(context).inputDecorationTheme.fillColor,"
  );

  content = content.replaceAll(
    "borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),",
    "borderSide: BorderSide(color: Theme.of(context).dividerColor),"
  );

  content = content.replaceAll(
    "dropdownColor: const Color(0xFF1F1F1F),",
    "dropdownColor: Theme.of(context).cardColor,"
  );

  content = content.replaceAll(
    "color: highlight ? const Color(0xFFFF3366) : Colors.white,",
    "color: highlight ? Theme.of(context).colorScheme.secondary : Theme.of(context).textTheme.bodyLarge?.color,"
  );

  content = content.replaceAll(
    "style: const TextStyle(color: Colors.white),",
    "style: TextStyle(color: Theme.of(context).colorScheme.onPrimary),"
  );

  file1.writeAsStringSync(content);
}
