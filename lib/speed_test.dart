import 'dart:math';
import 'package:http/http.dart' as http;

/// Phone side internet speed test. This measures the phone's own
/// internet connection, never the router WAN speed, and the UI must
/// label it that way. A failure is reported as a failure, never as
/// an invented number.
class SpeedResult {
  const SpeedResult({required this.downloadMbps, required this.uploadMbps, required this.bytesDownloaded});
  final double downloadMbps;
  final double uploadMbps;
  final int bytesDownloaded;
}

Future<SpeedResult> runPhoneSpeedTest({void Function(String stage)? onStage}) async {
  onStage?.call('Downloading');
  const downBytes = 5000000;
  final downUri = Uri.parse('https://speed.cloudflare.com/__down?bytes=$downBytes');
  final sw = Stopwatch()..start();
  final downRes = await http.get(downUri).timeout(const Duration(seconds: 30));
  sw.stop();
  if (downRes.statusCode != 200 || downRes.bodyBytes.isEmpty) {
    throw Exception('Phone speed test download failed (HTTP ${downRes.statusCode}).');
  }
  final downSeconds = sw.elapsedMilliseconds / 1000;
  if (downSeconds <= 0) throw Exception('Phone speed test could not measure time.');
  final downMbps = downRes.bodyBytes.length * 8 / downSeconds / 1000000;

  onStage?.call('Uploading');
  final rnd = Random();
  final payload = List<int>.generate(1000000, (_) => rnd.nextInt(256));
  final upUri = Uri.parse('https://speed.cloudflare.com/__up');
  final sw2 = Stopwatch()..start();
  final upRes = await http.post(upUri, body: payload).timeout(const Duration(seconds: 30));
  sw2.stop();
  if (upRes.statusCode != 200) {
    throw Exception('Phone speed test upload failed (HTTP ${upRes.statusCode}).');
  }
  final upSeconds = sw2.elapsedMilliseconds / 1000;
  if (upSeconds <= 0) throw Exception('Phone speed test could not measure time.');
  final upMbps = payload.length * 8 / upSeconds / 1000000;
  return SpeedResult(downloadMbps: downMbps, uploadMbps: upMbps, bytesDownloaded: downRes.bodyBytes.length);
}
