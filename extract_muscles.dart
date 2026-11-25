import 'dart:convert';
import 'dart:io';

void main() {
  final file = File('assets/data/exercises.json');
  final jsonList = jsonDecode(file.readAsStringSync()) as List<dynamic>;
  
  final muscles = <String>{};
  for (var item in jsonList) {
    final pm = item['primaryMuscles'] as List<dynamic>?;
    if (pm != null) {
      for (var m in pm) {
        muscles.add(m.toString());
      }
    }
  }
  print(muscles.toList().join(', '));
}
