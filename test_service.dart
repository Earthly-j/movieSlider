import 'package:http/http.dart' as http;
import 'lib/services/tmdb_service.dart';

void main() async {
  final service = TmdbService();
  final movies = await service.fetchOfficialTopRated();
  print('Loaded ' + movies.length.toString() + ' movies');
}
