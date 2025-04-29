import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:geolocator/geolocator.dart';
import 'package:intl/intl.dart';
import 'package:intl/date_symbol_data_local.dart';

const String apiKey = "5881b731e2801854cae0d2bd2bcbcce7"; // Замени с твоя API ключ

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('bg_BG', null);
  runApp(const WeatherApp());
}

class WeatherApp extends StatelessWidget {
  const WeatherApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Прогноза за времето",
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: createMaterialColor(Color(0xFFE0EEEE)),
        scaffoldBackgroundColor: Color(0xFFE0EEEE),
        // Можете да персонализирате и други свойства на темата тук,
        // като цвят на текста, акцентен цвят и т.н.
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: Colors.black87), // Пример за цвят на текста
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: Color(0xFFE0EEEE),
          titleTextStyle: TextStyle(color: Colors.black87),
        ),
      ),
      home: const WeatherScreen(),
    );
  }
}
MaterialColor createMaterialColor(Color color) {
  List strengths = <double>[.05];
  Map<int, Color> swatch = <int, Color>{};
  final int r = color.red, g = color.green, b = color.blue;

  for (int i = 1; i < 10; i++) {
    strengths.add(0.1 * i);
  }
  strengths.forEach((strength) {
    final double ds = 0.5 - strength;
    swatch[(strength * 1000).round()] = Color.fromRGBO(
      r + ((ds < 0 ? r : (255 - r)) * ds).round(),
      g + ((ds < 0 ? g : (255 - g)) * ds).round(),
      b + ((ds < 0 ? b : (255 - b)) * ds).round(),
      1,
    );
  });
  return MaterialColor(color.value, swatch);
}


class WeatherScreen extends StatefulWidget {
  const WeatherScreen({super.key});

  @override
  _WeatherScreenState createState() => _WeatherScreenState();
}

class _WeatherScreenState extends State<WeatherScreen> {
  final TextEditingController _cityController = TextEditingController();

  String temperature = "Няма данни";
  String weatherDescription = "";
  String iconUrl = "";
  String currentCity = "Определяне на локацията...";
  List<Map<String, dynamic>> forecastList = [];
  List<Map<String, dynamic>> hourlyForecast = [];
  String feelsLikeTemperature = "Няма данни";
  String uvIndex = "Няма данни";
  String sunriseTime = "Няма данни"; // Добавете тази декларация
  String sunsetTime = "Няма данни";  // Добавете тази декларация 
  String humidity = "Няма данни"; // Нова променлива за влажност
  String visibility = "Няма данни"; // Нова променлива за видимост
  String windSpeed = "Няма данни"; // Нова променлива за скорост на вятъра

  @override
  void initState() {
    super.initState();
    _getLocationAndWeather();
  }

  Future<void> _getLocationAndWeather() async {
    Position position = await _determinePosition();
    await _fetchCityFromCoordinates(position.latitude, position.longitude);
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception("Локацията е изключена.");
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception("Няма разрешение за локация.");
      }
    }

    if (permission == LocationPermission.deniedForever) {
      throw Exception("Локацията е забранена завинаги.");
    }

    return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high);
  }

  Future<void> _fetchCityFromCoordinates(double lat, double lon) async {
    final String apiUrl =
        "https://api.openweathermap.org/geo/1.0/reverse?lat=$lat&lon=$lon&limit=1&appid=$apiKey";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data.isNotEmpty) {
          String cityName = data[0]['name'];
          setState(() {
            currentCity = cityName;
            _cityController.text = cityName;
          });
          _updateWeather(cityName);
        }
      }
    } catch (e) {
      setState(() {
        currentCity = "Грешка при получаване на град";
      });
    }
  }

  void _updateWeather(String city) {
    _fetchWeather(city);
    _fetchForecast(city);
    currentCity = city;
  }

  Future<void> _fetchWeather(String city) async {
    final String apiUrl =
        "https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&units=metric&lang=bg";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        print("Full Weather API Response: $data");
        setState(() {
          temperature = _formatTemperature(data['main']['temp']);
          weatherDescription = data['weather'][0]['description'];
          String iconCode = data['weather'][0]['icon'];
          iconUrl = "http://openweathermap.org/img/wn/$iconCode@2x.png";
          feelsLikeTemperature = _formatTemperature(data['main']['feels_like']);
          uvIndex = "Няма данни";
          if (data['sys'] != null && data['sys'].containsKey('sunrise') && data['sys'].containsKey('sunset')) {
            final sunriseEpoch = data['sys']['sunrise'];
            final sunsetEpoch = data['sys']['sunset'];
            final sunriseUtc = DateTime.fromMillisecondsSinceEpoch(sunriseEpoch * 1000, isUtc: true);
            final sunsetUtc = DateTime.fromMillisecondsSinceEpoch(sunsetEpoch * 1000, isUtc: true);
            sunriseTime = DateFormat.Hm().format(sunriseUtc.toLocal());
            sunsetTime = DateFormat.Hm().format(sunsetUtc.toLocal());
          } else {
            sunriseTime = "Няма данни";
            sunsetTime = "Няма данни";
          }
          if (data['main'] != null && data['main'].containsKey('humidity')) {
            humidity = "${data['main']['humidity']}%";
          } else {
            humidity = "Няма данни";
          }
          if (data.containsKey('visibility')) {
            visibility = "${(data['visibility'] / 1000).toStringAsFixed(1)} км";
          } else {
            visibility = "Няма данни";
          }
          if (data.containsKey('wind') && data['wind'].containsKey('speed')) {
            windSpeed = "${data['wind']['speed']} м/с"; // Можете да конвертирате към км/ч, ако желаете
          } else {
            windSpeed = "Няма данни";
          }
        });
        if (data.containsKey('coord')) {
          _fetchUvIndex(data['coord']['lat'], data['coord']['lon']);
        }
      }
    } catch (e) {
      setState(() {
        temperature = "Грешка";
        weatherDescription = "Няма връзка";
        iconUrl = "";
        feelsLikeTemperature = "Грешка";
        uvIndex = "Грешка";
        sunriseTime = "Грешка";
        sunsetTime = "Грешка";
        humidity = "Грешка";
        visibility = "Грешка";
        windSpeed = "Грешка";
      });
    }
  }

  Future<void> _fetchUvIndex(double lat, double lon) async {
    final String uvApiUrl =
        "https://api.openweathermap.org/data/2.5/uvi?lat=$lat&lon=$lon&appid=$apiKey";
    try {
      final response = await http.get(Uri.parse(uvApiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          uvIndex = data['value'].toStringAsFixed(1);
        });
      } else {
        setState(() {
          uvIndex = "Грешка";
        });
      }
    } catch (e) {
      setState(() {
        uvIndex = "Грешка";
      });
    }
  }

  Future<void> _fetchForecast(String city) async {
    final String apiUrl =
        "https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&units=metric&lang=bg";
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        DateTime nowUtc = DateTime.now().toUtc();
        DateTime nextFullHourUtc = DateTime(nowUtc.year, nowUtc.month, nowUtc.day, nowUtc.hour + 1, 0, 0, 0, 0);
        DateTime twentyFourHoursLaterUtc = nowUtc.add(const Duration(hours: 24));

        List<Map<String, dynamic>> hourlyData = [];
        Map<String, Map<String, dynamic>> dailyData = {};

        for (var item in data['list']) {
          DateTime dateTimeUtc = DateTime.parse(item['dt_txt']).toUtc();

          if (dateTimeUtc.isAfter(nextFullHourUtc) && dateTimeUtc.isBefore(twentyFourHoursLaterUtc)) {
            hourlyData.add({
              "time": DateFormat.Hm().format(dateTimeUtc.toLocal()),
              "temp": _formatTemperature(item['main']['temp']),
              "icon": item['weather'][0]['icon']
            });
          }

          String date = item['dt_txt'].split(" ")[0];
          double tempMin = item['main']['temp_min'];
          double tempMax = item['main']['temp_max'];

          if (!dailyData.containsKey(date)) {
            dailyData[date] = {
              "min": tempMin,
              "max": tempMax,
              "icon": item['weather'][0]['icon'],
              "description": item['weather'][0]['description'],
            };
          } else {
            dailyData[date]!["min"] =
                tempMin < dailyData[date]!["min"] ? tempMin : dailyData[date]!["min"];
            dailyData[date]!["max"] =
                tempMax > dailyData[date]!["max"] ? tempMax : dailyData[date]!["max"];
          }
        }

        setState(() {
          hourlyForecast = hourlyData;
          forecastList = dailyData.entries
              .map((e) => {
                    "date": e.key,
                    "min": _formatTemperature(e.value["min"]),
                    "max": _formatTemperature(e.value["max"]),
                    "icon": e.value["icon"],
                    "description": e.value["description"],
                  })
              .toList();
          print("Hourly Forecast Data: $hourlyForecast");
        });
      }
    } catch (e) {
      setState(() {
        hourlyForecast = [];
        forecastList = [];
      });
    }
  }

  String _formatTemperature(double temp) {
    double roundedTemp = (temp * 2).round() / 2;
    return roundedTemp.toStringAsFixed(1) + "°C";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Прогноза за времето")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cityController,
                    decoration: const InputDecoration(
                      labelText: "Въведете град",
                    ),
                    onSubmitted: (value) => _updateWeather(value),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: () {
                    _updateWeather(_cityController.text);
                  },
                ),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Column(
                children: [
                  Text(
                    currentCity,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  if (iconUrl.isNotEmpty) Image.network(iconUrl),
                  Text(
                    temperature,
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold),
                  ),
                  Text(weatherDescription, style: const TextStyle(fontSize: 20)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (hourlyForecast.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "24-часова прогноза",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 100,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: hourlyForecast.length,
                        itemBuilder: (context, index) {
                          final item = hourlyForecast[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(item["time"], style: const TextStyle(fontSize: 16)),
                                SizedBox(
                                  height: 40,
                                  child: Image.network(
                                      "http://openweathermap.org/img/wn/${item['icon']}@2x.png"),
                                ),
                                Text(item["temp"], style: const TextStyle(fontSize: 14)),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            if (forecastList.isNotEmpty)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16.0),
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15.0),
                  border: Border.all(color: Colors.grey.shade700),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "5-дневна прогноза",
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    const Divider(color: Colors.grey),
                    const SizedBox(height: 10),
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: forecastList.length,
                      itemBuilder: (context, index) {
                        final item = forecastList[index];
                        final DateTime date = DateTime.parse(item['date']);
                        final String dayOfWeek =
                            DateFormat('EEEE', 'bg_BG').format(date);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8.0),
                          child: Row(
                            children: [
                              Text(
                                dayOfWeek,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 10),
                              Image.network(
                                "http://openweathermap.org/img/wn/${item['icon']}@2x.png",
                                height: 30,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                "${item['min']} / ${item['max']}",
                                style: const TextStyle(fontSize: 16),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Усеща се като",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          feelsLikeTemperature,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "UV Индекс",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          uvIndex,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Изгрев",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sunriseTime,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Залез",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          sunsetTime,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Влажност",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          humidity,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Видимост",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          visibility,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 8.0),
                    padding: const EdgeInsets.all(16.0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15.0),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          "Скорост на вятъра",
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          windSpeed,
                          style: const TextStyle(fontSize: 20),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}