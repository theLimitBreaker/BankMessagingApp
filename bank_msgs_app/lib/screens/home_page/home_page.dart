import 'package:bank_msgs_app/models/bnk_transaction.dart';
import 'package:bank_msgs_app/screens/home_page/bank_list_item.dart';
import 'package:bank_msgs_app/utils/database_helper.dart';
import 'package:bank_msgs_app/utils/values.dart';
import 'package:flutter/material.dart';
import 'package:sms/sms.dart';
import 'package:sqflite/sqflite.dart';

class HomePage extends StatefulWidget {
  @override
  State createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  DatabaseHelper _databaseHelper = DatabaseHelper();
  Set<String> bnkSet;
  Map<String, List<SmsMessage>> bnkMsgsMap = Map();

  final SmsQuery _query = new SmsQuery();

  @override
  void initState() {
    super.initState();
    _query.getAllSms;
  }

  bool _loading = true;
  int count = 0;

  void updateBankList() {
    final Future<Database> dbFuture = _databaseHelper.initializeDatabase();
    dbFuture.then((database) {
      Future<List<BnkTransaction>> bnkTransactionListFuture =
          _databaseHelper.getBnkTransactionList();
      bnkTransactionListFuture.then((bnkTransactionList) {
        setState(() {
          _loading = false;
          bnkTransactionList.forEach((listItem) {
            bnkSet.add(listItem.bank);
          });
          count = bnkSet.length;
        });
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (bnkSet == null) {
      bnkSet = Set();
      updateBankList();
    }

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        appBar: AppBar(
          title: Text('Bank Messages'),
          backgroundColor: Colors.teal[900],
          actions: <Widget>[
            IconButton(
              icon: Icon(Icons.receipt),
              onPressed: () {},
              tooltip: "Report Chart",
            )
          ],
        ),
        body: _homePageWidgets(),
        floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.teal[900],
          child: Icon(Icons.refresh),
          tooltip: 'Scan New Messages',
          onPressed: () async {
            _databaseHelper.delete().then((res) {
              setState(() {
                _loading = true;
              });
              _query.querySms(kinds: [SmsQueryKind.Inbox]).then(_getMsgs);
            });
          },
        ),
      ),
    );
  }

  Widget _homePageWidgets() {
    if (_loading) {
      return Center(
        child: CircularProgressIndicator(),
      );
    }
    if (bnkSet.isEmpty) {
      return Align(
        alignment: Alignment.center,
        child: Container(
          padding: EdgeInsets.all(16),
          decoration: BoxDecoration(
              borderRadius: BorderRadius.all(Radius.circular(30)),
              border: Border.all(
                  color: Colors.teal[900], width: 2, style: BorderStyle.solid)),
          child: Text(
            "Looks Like, its empty here \n Click Refresh button to scan Transaction",
            softWrap: true,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16
            ),
          ),
        ),
      );
    }
    return Padding(
        padding: EdgeInsets.fromLTRB(10.0, 20.0, 10.0, 20.0),
        child: GridView.count(
          crossAxisCount: 2,
          childAspectRatio: 1,
          children: bnkSet.map((String string) {
            return BankListItem(string);
          }).toList(growable: false),
        ));
  }

  void _getMsgs(List<SmsMessage> messages) async {
    List<SmsMessage> _messages = new List();
    _messages = messages;
    print(_messages);
    if (_messages != null) {
      mapMsgsToBankNames(_messages);
    }
  }

  void mapMsgsToBankNames(List<SmsMessage> _messages) {
    bnkMsgsMap = {
      'BOI': List(),
      'CANARA': List(),
      'KVB': List(),
      'HDFC': List(),
      'AXIS': List(),
    };
    for (var i = 0; i < _messages.length; i++) {
      String msgAddress = _messages[i].address;
      SmsMessage msg = _messages[i];
      print(msg);
      if (msgAddress.endsWith("BOIIND")) {
        bnkMsgsMap['BOI'].add(msg);
      } else if (msgAddress.endsWith("CANBNK")) {
        bnkMsgsMap['CANARA'].add(msg);
      } else if (msgAddress.endsWith("KVBANK")) {
        bnkMsgsMap['KVB'].add(msg);
      } else if (msgAddress.endsWith("HDFCBK")) {
        bnkMsgsMap['HDFC'].add(msg);
      } else if (msgAddress.endsWith("AxisBk")) {
        bnkMsgsMap['AXIS'].add(msg);
      }
    }
    makingTransactionObjects();
  }

  void makingTransactionObjects() {
    bnkMsgsMap.forEach((bnkName, msgs) async {
      if (msgs.length != 0) {
        print(msgs.length);

        var currentMonth = DateTime.now().month;
        var prevMonth1 = previousMonth(currentMonth);
        var prevMonth2 = previousMonth(prevMonth1);
        var prevMonth3 = previousMonth(prevMonth2);
        double creditedAmt1 = 0;
        double creditedAmt2 = 0;
        double creditedAmt3 = 0;
        double debitedAmt1 = 0;
        double debitedAmt3 = 0;
        double debitedAmt2 = 0;

        int i = 0;
        RegExp expForCredit1 = RegExp(
            r"(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*.*CREDITED",
            caseSensitive: false);
        RegExp expForCredit2 = RegExp(
            r"CREDITED.*(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*",
            caseSensitive: false);
        RegExp expForDebit1 = RegExp(
            r"(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*.*DEBITED",
            caseSensitive: false);
        RegExp expForDebit2 = RegExp(
            r"DEBITED.*(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*",
            caseSensitive: false);
        RegExp expForDeposit1 = RegExp(
            r"(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*.*DEPOSTED",
            caseSensitive: false);
        RegExp expForDeposit2 = RegExp(
            r"DEPOSITED.*(INR|INR |Rs\.|Rs\. |Rs|Rs )\d+\.*\d*",
            caseSensitive: false);
        msgs.forEach((msg) {
          if (expForCredit1.firstMatch(msg.body) != null) {
            var string = expForCredit1.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              creditedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              creditedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              creditedAmt3 += _getAmountFromString(string);
            }
          } else if (expForCredit2.firstMatch(msg.body) != null) {
            var string = expForCredit2.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              creditedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              creditedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              creditedAmt3 += _getAmountFromString(string);
            }
          } else if (expForDebit1.firstMatch(msg.body) != null) {
            var string = expForDebit1.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              debitedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              debitedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              debitedAmt3 += _getAmountFromString(string);
            }
          } else if (expForDebit2.firstMatch(msg.body) != null) {
            var string = expForDebit2.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              debitedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              debitedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              debitedAmt3 += _getAmountFromString(string);
            }
          } else if (expForDeposit1.firstMatch(msg.body) != null) {
            var string = expForDeposit1.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              creditedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              creditedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              creditedAmt3 += _getAmountFromString(string);
            }
          } else if (expForDeposit2.firstMatch(msg.body) != null) {
            var string = expForDeposit2.stringMatch(msg.body);
            if (msg.date.month == prevMonth1) {
              creditedAmt1 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth2) {
              creditedAmt2 += _getAmountFromString(string);
            } else if (msg.date.month == prevMonth3) {
              creditedAmt3 += _getAmountFromString(string);
            }
          }
          // print("$i : $creditedAmt1 , $debitedAmt1");
          print(msg.body);
        });
        BnkTransaction transMonth1 =
            BnkTransaction(bnkName, prevMonth1, debitedAmt1, creditedAmt1);
        BnkTransaction transMonth2 =
            BnkTransaction(bnkName, prevMonth2, debitedAmt2, creditedAmt2);
        BnkTransaction transMonth3 =
            BnkTransaction(bnkName, prevMonth3, debitedAmt3, creditedAmt3);

        _databaseHelper.insert(transMonth1);
        _databaseHelper.insert(transMonth2);
        _databaseHelper.insert(transMonth3);
      }
    });
    updateBankList();
  }

  double _getAmountFromString(String string) {
    RegExp exp = new RegExp(r"\d+\.*\d*");
    double amount = double.parse(exp.stringMatch(string));
    return amount;
  }
}
