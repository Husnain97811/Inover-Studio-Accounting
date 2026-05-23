// lib/core/utils/formatters.dart
import 'package:intl/intl.dart';

class Fmt {
  Fmt._();

  static String pkr(double amount) {
    if (amount >= 10000000) return 'PKR ${(amount/10000000).toStringAsFixed(2)} Cr';
    if (amount >= 100000)   return 'PKR ${(amount/100000).toStringAsFixed(2)} L';
    return 'PKR ${NumberFormat('#,##0.00', 'en_PK').format(amount)}';
  }

  static String pkrCompact(double amount) {
    if (amount >= 10000000) return '${(amount/10000000).toStringAsFixed(1)}Cr';
    if (amount >= 100000)   return '${(amount/100000).toStringAsFixed(1)}L';
    if (amount >= 1000)     return '${(amount/1000).toStringAsFixed(1)}K';
    return amount.toStringAsFixed(0);
  }

  static String pkrShort(double amount) =>
      NumberFormat('#,##0', 'en_PK').format(amount);

  static String date(DateTime dt)     => DateFormat('dd/MM/yyyy').format(dt);
  static String dateTime(DateTime dt) => DateFormat('dd/MM/yyyy HH:mm').format(dt);
  static String timeOnly(DateTime dt) => DateFormat('HH:mm').format(dt);
  static String dayMonth(DateTime dt) => DateFormat('d MMM').format(dt);
  static String monthYear(DateTime dt)=> DateFormat('MMM yyyy').format(dt);

  static String qty(double q) =>
      q == q.truncateToDouble() ? q.toInt().toString() : q.toStringAsFixed(2);

  static String pct(double p) => '${p.toStringAsFixed(1)}%';

  static String invoiceNo(int seq) => 'INV-${seq.toString().padLeft(6, '0')}';
  static String poNo(int seq)      => 'PO-${seq.toString().padLeft(5, '0')}';

  static String whatsappNo(String phone) {
    phone = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    if (phone.startsWith('0'))  return '92${phone.substring(1)}';
    if (phone.startsWith('+'))  return phone.substring(1);
    if (phone.startsWith('3'))  return '92$phone';
    return phone;
  }
}
