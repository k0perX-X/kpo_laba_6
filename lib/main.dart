import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:xml/xml.dart';
import 'dart:developer' as dev;
import 'package:dropdown_search/dropdown_search.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  static const String _title = 'KPOLaba6';

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      restorationScopeId: 'app',
      title: _title,
      home: MyStatefulWidget(restorationId: 'main'),
    );
  }
}

class MyStatefulWidget extends StatefulWidget {
  const MyStatefulWidget({Key? key, this.restorationId}) : super(key: key);

  final String? restorationId;

  @override
  State<MyStatefulWidget> createState() => _MyStatefulWidgetState();
}

class Curs {
  String Vname;
  int Vnom;
  double Vcurs;
  int Vcode;
  String VchCode;

  Curs(this.Vname, this.Vnom, this.Vcurs, this.Vcode, this.VchCode);
}

/// RestorationProperty objects can be used because of RestorationMixin.
class _MyStatefulWidgetState extends State<MyStatefulWidget>
    with RestorationMixin {
  // In this example, the restoration ID for the mixin is passed in through
  // the [StatefulWidget]'s constructor.
  @override
  String? get restorationId => widget.restorationId;

  String selectedCurrency = "";
  Map<String, Curs> currencies = <String, Curs>{};

  var rusAmount = TextEditingController();
  var currencyAmount = TextEditingController();

  void convertToRuble() {
    try {
      double x = double.parse(currencyAmount.text);
      Curs curs = currencies[selectedCurrency]!;
      rusAmount.text = (x / curs.Vnom * curs.Vcurs).toStringAsFixed(4);
    } catch (e, s) {
      showErrorMessage(e);
    }
  }
  void convertToCurrency() {
    try {
      double x = double.parse(rusAmount.text);
      Curs curs = currencies[selectedCurrency]!;
      currencyAmount.text = (x * curs.Vnom / curs.Vcurs).toStringAsFixed(4);
    } catch (e, s) {
      showErrorMessage(e);
    }
  }

  void showErrorMessage(e) async {
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text("Error"),
          content: Text(e.toString()),
          actions: <Widget>[
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  final RestorableDateTime _selectedDate = RestorableDateTime(DateTime.now());
  late final RestorableRouteFuture<DateTime?> _restorableDatePickerRouteFuture =
      RestorableRouteFuture<DateTime?>(
    onComplete: _selectDate,
    onPresent: (NavigatorState navigator, Object? arguments) {
      return navigator.restorablePush(
        _datePickerRoute,
        arguments: _selectedDate.value.millisecondsSinceEpoch,
      );
    },
  );

  static Route<DateTime> _datePickerRoute(
    BuildContext context,
    Object? arguments,
  ) {
    return DialogRoute<DateTime>(
      context: context,
      builder: (BuildContext context) {
        return DatePickerDialog(
          restorationId: 'date_picker_dialog',
          initialEntryMode: DatePickerEntryMode.calendarOnly,
          initialDate: DateTime.fromMillisecondsSinceEpoch(arguments! as int),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
      },
    );
  }

  @override
  void restoreState(RestorationBucket? oldBucket, bool initialRestore) {
    registerForRestoration(_selectedDate, 'selected_date');
    registerForRestoration(
        _restorableDatePickerRouteFuture, 'date_picker_route_future');
  }

  void _selectDate(DateTime? newSelectedDate) {
    if (newSelectedDate != null) {
      setState(() {
        _selectedDate.value = newSelectedDate;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:
              Text('Selected: ${DateFormat.yMd().format(_selectedDate.value)}'),
        ));
      });
    }
  }

  Future<List<Widget>> getExchangeRates(BuildContext context) async {
    var uri = Uri.https("www.cbr.ru", "DailyInfoWebServ/DailyInfo.asmx");
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="utf-8"');
    builder.element('soap:Envelope', attributes: {
      "xmlns:xsi": "http://www.w3.org/2001/XMLSchema-instance",
      "xmlns:xsd": "http://www.w3.org/2001/XMLSchema",
      "xmlns:soap": "http://schemas.xmlsoap.org/soap/envelope/"
    }, nest: () {
      builder.element("soap:Body", nest: () {
        builder.element("GetCursOnDateXML",
            attributes: {"xmlns": "http://web.cbr.ru/"}, nest: () {
          builder.element("On_date", nest: () {
            builder.text(_selectedDate.value.toIso8601String());
          });
        });
      });
    });
    var document = builder.buildDocument();
    dev.log(document.toString());
    var r = await http.post(uri,
        headers: {"Content-Type": "text/xml; charset=utf-8"},
        body: document.toString());
    document = XmlDocument.parse(r.body);
    currencies = Map<String, Curs>.fromEntries(
        document.findAllElements('ValuteCursOnDate').map((e) {
      return MapEntry(
          e.getElement("VchCode")!.text,
          Curs(
              e.getElement("Vname")!.text,
              int.parse(e.getElement("Vnom")!.text),
              double.parse(e.getElement("Vcurs")!.text),
              int.parse(e.getElement("Vcode")!.text),
              e.getElement("VchCode")!.text));
    }));
    selectedCurrency = currencies.keys.first;

    return [
      Row(
        mainAxisSize: MainAxisSize.max,
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 50,
                width: 300,
                child: Center(
                  child: Text(
                    "RUB",
                    style: Theme.of(context).textTheme.headline6,
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 50,
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Colors.black),
                  controller: rusAmount,
                  decoration: InputDecoration(
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      hintText: "Enter amount",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      )),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: convertToCurrency,
                child: const Text("Convert to currency"),
              ),
            ],
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                  height: 50,
                  width: 300,
                  child: DropdownSearch<String>(
                      // popupProps: PopupProps.menu(
                      //   showSelectedItems: true,
                      //   disabledItemFn: (String s) => s.startsWith('I'),
                      // ),
                      selectedItem: currencies.keys.first,
                      items: currencies.keys.toList(),
                      onChanged: (e) {
                        selectedCurrency = e as String;
                      })),
              const SizedBox(
                height: 10,
              ),
              SizedBox(
                height: 50,
                width: 300,
                child: TextField(
                  style: const TextStyle(color: Colors.black),
                  controller: currencyAmount,
                  decoration: InputDecoration(
                      fillColor: Colors.grey.shade100,
                      filled: true,
                      hintText: "Enter amount",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                      )),
                ),
              ),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: convertToRuble,
                child: const Text("Convert to ruble"),
              ),
            ],
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text("Enter date: "),
                OutlinedButton(
                  onPressed: () {
                    _restorableDatePickerRouteFuture.present();
                  },
                  child: Text(DateFormat.yMd().format(_selectedDate.value)),
                ),
              ],
            ),
            const SizedBox(height: 10),
            FutureBuilder<List<Widget>>(
                future: getExchangeRates(context),
                builder: (BuildContext context,
                    AsyncSnapshot<List<Widget>> snapshot) {
                  List<Widget> children;
                  if (snapshot.hasData) {
                    children = snapshot.data!;
                  } else if (snapshot.hasError) {
                    children = <Widget>[
                      const Icon(
                        Icons.error_outline,
                        color: Colors.red,
                        size: 60,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Text(snapshot.error.toString()),
                      )
                    ];
                  } else {
                    children = <Widget>[
                      const SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Text("Loading"),
                      )
                    ];
                  }
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: children,
                  );
                }),
          ],
        ),
      ),
    );
  }
}
