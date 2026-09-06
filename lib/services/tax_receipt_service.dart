import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/restaurant.dart';
import '../models/food_listing.dart';

class TaxReceiptService {
  static Future<Uint8List> generateAnnualReceipt({
    required Restaurant restaurant,
    required List<FoodListing> completedListings,
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final doc = pw.Document();
    final currency = NumberFormat.currency(symbol: '\$');
    final dateFmt = DateFormat('MMM d, yyyy');

    final inPeriod = completedListings.where((l) {
      final d = l.completedAt;
      return d != null &&
          !d.isBefore(periodStart) &&
          !d.isAfter(periodEnd) &&
          l.completedCount > 0;
    }).toList()
      ..sort((a, b) =>
          (a.completedAt ?? DateTime(0)).compareTo(b.completedAt ?? DateTime(0)));

    double totalValue = 0;
    int totalPortions = 0;
    for (final l in inPeriod) {
      totalValue += (l.cost ?? 0) * l.completedCount;
      totalPortions += l.completedCount;
    }

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text('Donation Summary for Your Accountant',
              style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text(
              'Period: ${dateFmt.format(periodStart)} \u2013 ${dateFmt.format(periodEnd)}'),
          pw.SizedBox(height: 16),
          pw.Text(restaurant.name,
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.Text(restaurant.address),
          pw.Text(restaurant.contactInfo),
          if ((restaurant.businessLicenseNumber ?? '').isNotEmpty)
            pw.Text('Business License #: ${restaurant.businessLicenseNumber}'),
          if ((restaurant.stateRegistrationNumber ?? '').isNotEmpty)
            pw.Text('State Registration #: ${restaurant.stateRegistrationNumber}'),
          pw.SizedBox(height: 20),
          pw.Text('Donation Summary',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          pw.Table.fromTextArray(
            headers: ['Date Completed', 'Item', 'Portions Donated', 'Est. Value'],
            data: inPeriod
                .map((l) => [
                      dateFmt.format(l.completedAt!),
                      l.item,
                      l.completedCount.toString(),
                      currency.format((l.cost ?? 0) * l.completedCount),
                    ])
                .toList(),
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total portions donated:'),
              pw.Text(totalPortions.toString(),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Text('Total self-reported donation value:'),
              pw.Text(currency.format(totalValue),
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
            ],
          ),
          pw.SizedBox(height: 24),
          pw.Text('To Complete Before Filing',
              style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('EIN / Tax ID: ${restaurant.einOrTaxId?.isNotEmpty == true ? restaurant.einOrTaxId : '_______________________'}'),
          pw.SizedBox(height: 4),
          pw.Text('Recipient organization name (if donated through a nonprofit): _______________________'),
          pw.SizedBox(height: 4),
          pw.Text('Recipient organization EIN: _______________________'),
          pw.SizedBox(height: 4),
          pw.Text('Recipient\'s written acknowledgment attached?  \u25a1 Yes   \u25a1 No'),
          pw.SizedBox(height: 4),
          pw.Text('Preparer name / date: _______________________'),
          pw.SizedBox(height: 16),
          pw.Text(
            'This document is a self-reported summary of donations logged in FoodRescue. It is not '
            'IRS Form 8283, does not calculate the IRC \u00a7170(e)(3) enhanced-deduction amount (which '
            'differs from simple cost \u00d7 portions), and does not substitute for the recipient '
            'organization\'s written acknowledgment required for that deduction. If total similar-item '
            'donations for the year exceed \$5,000, a qualified appraisal may be required. Consult a '
            'tax professional before filing.',
            style: pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ],
      ),
    );

    return doc.save();
  }
}