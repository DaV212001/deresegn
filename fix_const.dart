import 'dart:io';

void main() {
  final file = File('lib/screens/supplies_screen.dart');
  var content = file.readAsStringSync();

  // Fix const TextStyle with Theme.of(context) - product description
  content = content.replaceAll(
    'style: const TextStyle(\n                                    color: Theme.of(context).textTheme.bodyLarge?.color,\n                                    fontSize: 17,',
    'style: TextStyle(\n                                    color: Theme.of(context).textTheme.bodyLarge?.color,\n                                    fontSize: 17,'
  );

  // Fix CRLF variant
  content = content.replaceAll(
    'style: const TextStyle(\r\n                                    color: Theme.of(context).textTheme.bodyLarge?.color,\r\n                                    fontSize: 17,',
    'style: TextStyle(\r\n                                    color: Theme.of(context).textTheme.bodyLarge?.color,\r\n                                    fontSize: 17,'
  );

  // Fix const TextStyle with Theme.of(context) - unit price
  content = content.replaceAll(
    'style: const TextStyle(\n                               color: Theme.of(context).textTheme.bodyLarge?.color,\n                               fontSize: 24,',
    'style: TextStyle(\n                               color: Theme.of(context).textTheme.bodyLarge?.color,\n                               fontSize: 24,'
  );

  content = content.replaceAll(
    'style: const TextStyle(\r\n                               color: Theme.of(context).textTheme.bodyLarge?.color,\r\n                               fontSize: 24,',
    'style: TextStyle(\r\n                               color: Theme.of(context).textTheme.bodyLarge?.color,\r\n                               fontSize: 24,'
  );

  file.writeAsStringSync(content);
  print('Done');
}
