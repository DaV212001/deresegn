import 'package:flutter_test/flutter_test.dart';
import 'package:deresegn/services/invoice_pdf_service.dart';

void main() {
  group('InvoicePdfService.amountInWordsAmharic', () {
    test('Zero Birr', () {
      expect(InvoicePdfService.amountInWordsAmharic(0), 'ዜሮ ብር');
    });

    test('Zero Birr with cents', () {
      expect(InvoicePdfService.amountInWordsAmharic(0.50), 'ዜሮ ብር ከ ሀምሳ ሳንቲም');
    });

    test('Single units', () {
      expect(InvoicePdfService.amountInWordsAmharic(1), 'አንድ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(5), 'አምስት ብር');
      expect(InvoicePdfService.amountInWordsAmharic(15), 'አስራ አምስት ብር');
    });

    test('Single hundred should have "አንድ መቶ", not bare "መቶ"', () {
      expect(InvoicePdfService.amountInWordsAmharic(100), 'አንድ መቶ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(115), 'አንድ መቶ አስራ አምስት ብር');
      expect(InvoicePdfService.amountInWordsAmharic(150), 'አንድ መቶ ሀምሳ ብር');
    });

    test('Multiple hundreds', () {
      expect(InvoicePdfService.amountInWordsAmharic(200), 'ሁለት መቶ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(500), 'አምስት መቶ ብር');
    });

    test('Single thousand should have "አንድ ሺህ", not bare "ሺህ"', () {
      expect(InvoicePdfService.amountInWordsAmharic(1000), 'አንድ ሺህ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(1150), 'አንድ ሺህ አንድ መቶ ሀምሳ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(1115), 'አንድ ሺህ አንድ መቶ አስራ አምስት ብር');
    });

    test('Tens and hundreds of thousands', () {
      expect(InvoicePdfService.amountInWordsAmharic(10000), 'አስር ሺህ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(100000), 'አንድ መቶ ሺህ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(115000), 'አንድ መቶ አስራ አምስት ሺህ ብር');
    });

    test('Millions and Billions', () {
      expect(InvoicePdfService.amountInWordsAmharic(1000000), 'አንድ ሚሊዮን ብር');
      expect(InvoicePdfService.amountInWordsAmharic(1100000), 'አንድ ሚሊዮን አንድ መቶ ሺህ ብር');
      expect(InvoicePdfService.amountInWordsAmharic(1000000000), 'አንድ ቢሊዮን ብር');
    });

    test('Amounts with cents', () {
      expect(
        InvoicePdfService.amountInWordsAmharic(115.25),
        'አንድ መቶ አስራ አምስት ብር ከ ሃያ አምስት ሳንቲም',
      );
      expect(
        InvoicePdfService.amountInWordsAmharic(1150.50),
        'አንድ ሺህ አንድ መቶ ሀምሳ ብር ከ ሀምሳ ሳንቲም',
      );
    });
  });
}
