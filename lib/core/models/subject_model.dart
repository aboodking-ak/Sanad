import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SubjectModel {
  final String label;
  final IconData icon;
  final List<PdfModel> pdfs;

  SubjectModel({
    required this.label,
    required this.icon,
    required this.pdfs,
  });

  static List<SubjectModel> fromSupabaseList(List<dynamic> data) {
    Map<String, List<PdfModel>> groupedData = {};

    for (var item in data) {
      // نأخذ الاسم كما هو من السيرفر (سواء إسلامية أو islamic)
      String rawLabel = (item['subject_name'] ?? 'unknown').toString().trim();
      
      PdfModel pdf = PdfModel(
        title: item['book_title'] ?? 'كتاب',
        url: item['file_url'] ?? '',
      );

      if (groupedData.containsKey(rawLabel)) {
        groupedData[rawLabel]!.add(pdf);
      } else {
        groupedData[rawLabel] = [pdf];
      }
    }

    return groupedData.entries.map((entry) {
      return SubjectModel(
        label: entry.key,
        icon: _getIconByLabel(entry.key),
        pdfs: entry.value,
      );
    }).toList();
  }

  static Future<List<SubjectModel>> fetchFromSupabase() async {
    final response = await Supabase.instance.client
        .from('books')
        .select();
    return fromSupabaseList(response);
  }

  static IconData _getIconByLabel(String label) {
    String l = label.toLowerCase();
    if (l.contains('islam') || l.contains('اسلام')) return Icons.menu_book_rounded;
    if (l.contains('arab') || l.contains('عرب')) return Icons.auto_stories_rounded;
    if (l.contains('eng') || l.contains('انكليز')) return Icons.language_rounded;
    if (l.contains('math') || l.contains('رياض')) return Icons.functions_rounded;
    if (l.contains('bio') || l.contains('احياء')) return Icons.biotech_rounded;
    if (l.contains('chem') || l.contains('كيمياء')) return Icons.science_rounded;
    if (l.contains('phys') || l.contains('فيزياء')) return Icons.bolt_rounded;
    return Icons.book_rounded;
  }
}

class PdfModel {
  final String title;
  final String url;

  PdfModel({required this.title, required this.url});
}
