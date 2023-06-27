import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:local_auth/local_auth.dart';
import 'package:photo_album/screens/dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  final LocalAuthentication localAuth = LocalAuthentication();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: GestureDetector(
      onTap: () async {
        bool weCanCheckBiometrics = await localAuth.canCheckBiometrics;

        if (weCanCheckBiometrics) {
          bool authenticated = await localAuth.authenticate(
            localizedReason: "Authenticate to see your photos",
          );
          if (authenticated) {
            Navigator.push(context,
                MaterialPageRoute(builder: (context) => DashboardScreen()));
          }
        }
      },
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(
            Icons.touch_app,
            size: 124.0,
          ),
          Text(
            "Touch to unlock",
            style: GoogleFonts.spaceMono(
              fontSize: 32.0,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    ));
  }
}
