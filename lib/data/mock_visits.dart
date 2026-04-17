import 'dart:math';

final List<(String, String, String)> allMockVisits = _generateMockVisits(100);

List<(String, String, String)> _generateMockVisits(int count) {
  final gyms = [
    'Gymmaster Central',
    'Branch Demo',
    'Studio Sukajadi',
    'Gymmaster Dago',
    'Studio Buah Batu',
    'Gymmaster Antapani',
    'Studio Setiabudi',
    'Gymmaster Pasteur',
    'Studio Cihampelas',
    'Gymmaster Riau'
  ];
  final statuses = [
    'Sesi selesai',
    'Sesi selesai',
    'Sesi selesai',
    'Sesi selesai',
    'Check-in berhasil'
  ];

  return List.generate(count, (i) {
    // Generate decreasing dates starting from a base fixed date
    var date = DateTime(2026, 4, 10, 19, 10).subtract(Duration(
      hours: i * 11,
      minutes: (i * 37) % 60,
    ));
    var y = date.year;
    var m = date.month.toString().padLeft(2, '0');
    var d = date.day.toString().padLeft(2, '0');
    var h = date.hour.toString().padLeft(2, '0');
    var min = date.minute.toString().padLeft(2, '0');
    
    return (
      gyms[i % gyms.length],
      '$y-$m-$d $h:$min',
      i == 0 ? 'Check-in berhasil' : statuses[i % statuses.length],
    );
  });
}
