import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;

String city = 'Örebro'; //global var for the city

//for accessing methods outside state classes
final GlobalKey<_WeatherPageState> _weatherPageKey = GlobalKey<_WeatherPageState>();
final GlobalKey<_ForecastPageState> _forecastPageKey = GlobalKey<_ForecastPageState>();

void main() async {

 await dotenv.load(); //get API key from .env file
 runApp(const MyApp()
  );
}

class MyApp extends StatelessWidget
{
  const MyApp({super.key});

  @override
  Widget build(BuildContext context)
  {
    return MaterialApp(
      title: "Weather app",
      home: Scaffold(
        appBar: AppBar(
          title: const Text("Weather app"), 
          leading: const Icon(Icons.flutter_dash)
        ),
        body: const Pages(),
      )
    );
  }
}

class OWAPICaller //Helper class to handle API calls
{
  final apiKey = dotenv.env['API_key'];
  Future<http.Response> getWeatherNow()
  {
    return http.get(Uri.parse('https://api.openweathermap.org/data/2.5/weather?q=$city&appid=$apiKey&lang=sv'));
  }

  Future<http.Response> getWeatherForecast()
  {
    return http.get(Uri.parse('https://api.openweathermap.org/data/2.5/forecast?q=$city&appid=$apiKey&lang=sv'));
  }
}

class Pages extends StatefulWidget //for managing the different pages and the bottomnavbar
{
  const Pages({super.key});

  @override
  State<Pages> createState() => _PagesState();
}

class _PagesState extends State<Pages> //for managing the different pages and the bottomnavbar, search field
{

  int currentPage = 0;
  static List<Widget> appPages = <Widget>[
    WeatherPage(key: _weatherPageKey),
    ForecastPage(key: _forecastPageKey),
    const AboutPage()
  ];
  final TextEditingController _controller = TextEditingController();

  void _onItemTapped(int index) //bottomnavbar
  {
      setState(() {
        currentPage = index;
      });
  }

  void _updateCity() //search field
  {
    FocusScope.of(context).unfocus(); //remove keyboard
    String newCity = _controller.text;
    if (newCity != "")
    {
      city = newCity;
    }
    //make use of globalkeys to update the state for the weather
    _weatherPageKey.currentState?.getWeatherFromAPI();
    _forecastPageKey.currentState?.getForecastFromAPI();
  }

  @override
  Widget build(BuildContext context)
  {
    return Scaffold(
      body: Column(children: [
           TextField(
              controller: _controller,
              decoration: InputDecoration(
                floatingLabelBehavior: FloatingLabelBehavior.never,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15.0),),
                labelText: 'Sök stad',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.search),
                  onPressed: _updateCity)
              ),
            onSubmitted: (_) => _updateCity(), //so you can use enter
          ),
          Expanded(child: appPages[currentPage])
        ]
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.home),
            label: 'Weather',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.date_range),
            label: 'Forecast',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.info),
            label: 'About',
          )
        ],
        currentIndex: currentPage,
        selectedItemColor: const Color.fromARGB(255, 0, 255, 64),
        onTap: _onItemTapped,
      ),
      
    );
  }
}

class AboutPage extends StatelessWidget //for the aboutpage, stateless, only text
{
  const AboutPage({super.key});

  @override
  Widget build(BuildContext context)
  {
    return const Scaffold(
      body: Center(child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [ 
                        Text("Weather app", style:TextStyle(
                        fontSize: 40,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.bold)),
                        Text("This is a weather app developed as a part of a summer course in flutter given at the Linneaus University 2024. The weather data is retrieved using the OpenWeatherMap API.\n",style:TextStyle(
                        fontSize: 15,
                        fontStyle: FontStyle.normal,), textAlign: TextAlign.center),
                        Text("Developed by Johannes Ferm", textAlign: TextAlign.center,style:TextStyle(
                        fontSize: 20,
                        fontStyle: FontStyle.italic))
          ]
        ),
      )
    );
  }
}

class WeatherPage extends StatefulWidget //for the current weather
{
  const WeatherPage({super.key});

  @override
  State<WeatherPage> createState() => _WeatherPageState();
}

class _WeatherPageState extends State<WeatherPage> //for the current weather 
{
  final OWAPICaller weatherAPI = OWAPICaller(); 
  String description = '';
  String city = '';
  double tempNum = 0;
  String tempString = '';
  String weatherIcon = '';
  String time = '';
  Timer? _timer;
  bool error = false;

  @override
  void initState()
  {
    super.initState();
    getWeatherFromAPI();
    _timer = Timer.periodic(const Duration(seconds: 10), (_) => getWeatherFromAPI()); //update every 10 seconds to ensure the time shown is at most 10 seconds off
  }

  void getWeatherFromAPI() async //async method to update the weather with data from API
  {
    final apiResponse = await weatherAPI.getWeatherNow();
    final weatherData = jsonDecode(apiResponse.body);
    if (mounted && apiResponse.statusCode == 200) //avoid error about setState after dispose etc, comes when clicking too fast on startup
    {
      setState(()
      {
        //avoid the issue of 0.0 flashing when changing pages, empty string won't show anything
        tempNum = weatherData['main']['temp'] - 273.15;
        tempString = "${tempNum.toStringAsFixed(1)}\u2103";

        //set rest of info from api
        description = weatherData['weather'][0]['description'];
        city = weatherData['name'];
        weatherIcon = 'https://openweathermap.org/img/w/${weatherData['weather'][0]['icon']}.png';

        //not from api but should still use timer
        time = DateTime.now().toUtc().add(const Duration(hours:2)).toString().substring(0,16);

        error = false;
      });
    }
    else if(mounted && apiResponse.statusCode != 200) //if api response is not okay, catches faulty input
     {
      setState(() {
            error = true;
      });
     }
  }
  
  @override
  Widget build(BuildContext context)
  {
    if(error)
    {
      return const Center(child:Text("Something went wrong. Try again!", style:TextStyle(
                        fontSize: 40,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.bold), 
                        textAlign: TextAlign.center), 
                        );
    }
    return Scaffold(
      body: Center(child: 
        Column(children: [const Padding(padding: EdgeInsets.all(100)),
            Image.network(weatherIcon,  errorBuilder: (context, error, stackTrace) {return Container();}
          //if the url is empty, default to an empty image, this is necessary for the app to work with page switching, freezes otherwise
            ),
            Text(tempString, style:const TextStyle(
                        fontSize: 40,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.bold)),
            Text(city,  style:const TextStyle(
                        fontSize: 25,
                        fontStyle: FontStyle.normal)),
            Text(description),
            Text(time)
          ]
        )
      )
    );
  }
}

class ForecastPage extends StatefulWidget //for the weather forecast
{
  const ForecastPage({super.key});

  @override
  State<ForecastPage> createState() => _ForecastPageState();
}

class _ForecastPageState extends State<ForecastPage> //for the weather forecast
{
  final OWAPICaller weatherAPI = OWAPICaller(); 
  Timer? _timer;
  Map<String, List<dynamic>> forecast = {}; //holds the forecast, {time:[temp, description, icon], ...}'
  bool error = false;

  @override
  void initState()
  {
    super.initState();
    getForecastFromAPI();
    _timer = Timer.periodic(const Duration(minutes: 15), (_) =>  getForecastFromAPI()); //update every 15 minutes to ensure the forecast stays up to date
  }

  void getForecastFromAPI() async //async method to update the weather with data from API
  {
    final apiResponse = await weatherAPI.getWeatherForecast();
    final forecastData = jsonDecode(apiResponse.body)['list'];
    if (mounted && apiResponse.statusCode == 200) //avoid error about setState after dispose etc, comes when clicking too fast on startup
    {
      setState(()
      {
         String time;
         for (var entry in forecastData)
         {
          //convert from unix time
          time = entry['dt_txt'].substring(0,16);
          
          //fill forecast map
          forecast[time] = [entry['main']['temp'], entry['weather'][0]['description'], entry['weather'][0]['icon']];
         }
         error = false;
      });
     }
     else if(mounted && apiResponse.statusCode != 200) //if api response is not okay, catches faulty input
     {
      setState(() {
            error = true;
      });
     }
  }

  @override
  Widget build(BuildContext context)
  {
    if(error)
    {
      return const Center(child:Text("Something went wrong. Try again!", style:TextStyle(
                        fontSize: 40,
                        fontStyle: FontStyle.normal,
                        fontWeight: FontWeight.bold), 
                        textAlign: TextAlign.center), 
                        );
    }
    return Scaffold(
      body: Column(children:[  Expanded(
              child: ListView.builder(
                itemCount: forecast.length,
                itemBuilder: (BuildContext txt, int index) 
                {
                  String buildTime = forecast.keys.elementAt(index);

                  //get temp, convert to Celsius and to string
                  double buildTempNum = forecast[buildTime]?[0] - 273.15;
                  String buildTempStr = "${buildTempNum.toStringAsFixed(1)}\u2103";

                  String buildDesc = forecast[buildTime]?[1];

                  //get the icon
                  String buildIcon = forecast[buildTime]?[2];
                  String buildIconURL = 'https://openweathermap.org/img/w/$buildIcon.png';

                  return ListTile(
                    leading: SizedBox(
                      width: 50, 
                      height: 50,
                      child: Image.network(buildIconURL,  errorBuilder: (context, error, stackTrace) {return Container();})
                    ),
                    title: Text(buildTime),
                    subtitle: Text('$buildDesc - Temperatur: $buildTempStr'),
                    
                    );
                }
              )
          )
         ]
        )
      );
  }
}