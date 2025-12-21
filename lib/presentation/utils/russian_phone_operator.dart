final Map<String, String> russianOperators = {
  // МТС
  '910': 'МТС', '911': 'МТС', '912': 'МТС', '913': 'МТС', '914': 'МТС', '915': 'МТС', '916': 'МТС', '917': 'МТС',
  // Beeline
  '903': 'Билайн', '905': 'Билайн', '906': 'Билайн', '909': 'Билайн',
  // Tele2
  '900': 'Tele2', '901': 'Tele2', '902': 'Tele2', '904': 'Tele2',
};

String? detectRussianOperator(String formattedPhone) {
  // formattedPhone: +7 (xxx) xxx-xx-xx
  final reg = RegExp(r'\+7 \((\d{3})\)');
  final match = reg.firstMatch(formattedPhone);
  if (match != null && match.groupCount >= 1) {
    final code = match.group(1)!;
    return russianOperators[code];
  }
  return null;
}

