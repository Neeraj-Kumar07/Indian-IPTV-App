// // import 'package:flutter/material.dart';
// // import 'screens/home.dart';
// //
// // void main() => runApp(M3UPlayer());
// //
// // class M3UPlayer extends StatefulWidget {
// //   @override
// //   _M3UPlayerState createState() => _M3UPlayerState();
// // }
// //
// // class _M3UPlayerState extends State<M3UPlayer> {
// //   @override
// //   Widget build(BuildContext context) {
// //     return MaterialApp(
// //       debugShowCheckedModeBanner: false,
// //       title: 'Live Tv',
// //       home: Scaffold(
// //           appBar: AppBar(
// //             title: const Text('Live TV'),
// //           ),
// //           body: const Home()),
// //     );
// //   }
// // }
//
// // THIS FILE CONTAIN "MAIN.DART" FILE CODE :
// /////////////////////////////////////////////////////
//
// import 'package:flutter/material.dart';
//
// import 'screens/home.dart';
//
// void main() => runApp(const M3UPlayer());
//
// class M3UPlayer extends StatelessWidget {
//   const M3UPlayer({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Live Tv',
//       home: Scaffold(
//         appBar: AppBar(
//           title: const Text('Live TV'),
//
//         ),
//         body: const Home(),
//
//       ),
//     );
//   }
// }


// MAIN.DART
import 'package:flutter/material.dart';

import 'screens/home.dart';

void main() => runApp(const M3UPlayer());

class M3UPlayer extends StatelessWidget {
  const M3UPlayer({super.key});

  // Same breakpoint as home.dart: below = phone, above = TV / tablet.
  static const double _phoneBreakpoint = 600;

  // App bar heights. Phone keeps the Material default (56).
  static const double _phoneBarHeight = kToolbarHeight; // 56
  static const double _tvBarHeight = 40; // lower this for a smaller gap

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Tv',
      // Builder gives us a context that is BELOW MaterialApp, so
      // MediaQuery returns the real screen size.
      home: Builder(
        builder: (context) {
          final isTv =
              MediaQuery.sizeOf(context).width >= _phoneBreakpoint;

          return Scaffold(
            appBar: AppBar(
              title: const Text('Live TV'),
              toolbarHeight: isTv ? _tvBarHeight : _phoneBarHeight,
            ),
            body: const Home(),
          );
        },
      ),
    );
  }
}