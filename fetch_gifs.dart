import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  try {
    final response = await http.get(Uri.parse('https://www.gifdotreino.com/'));
    if (response.statusCode == 200) {
      final html = response.body;
      final RegExp imgRegex = RegExp(r'<img[^>]+src="([^">]+)"');
      final matches = imgRegex.allMatches(html);
      
      final urls = matches.map((m) => m.group(1)).where((url) => url != null && url.contains('.gif')).toList();
      print('Found ${urls.length} GIFs');
      for (var url in urls.take(20)) {
        print(url);
      }
      
      // Also print some links to see how categories are structured
      final RegExp linkRegex = RegExp(r'<a[^>]+href="([^">]+)"');
      final linkMatches = linkRegex.allMatches(html);
      final links = linkMatches.map((m) => m.group(1)).toSet().toList();
      print('\nLinks:');
      for (var l in links.take(20)) {
        print(l);
      }
    } else {
      print('Status code: ${response.statusCode}');
    }
  } catch (e) {
    print('Error: $e');
  }
}
