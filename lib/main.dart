// import 'package:flutter/material.dart';
// import 'screens/home.dart';
//
// void main() => runApp(M3UPlayer());
//
// class M3UPlayer extends StatefulWidget {
//   @override
//   _M3UPlayerState createState() => _M3UPlayerState();
// }
//
// class _M3UPlayerState extends State<M3UPlayer> {
//   @override
//   Widget build(BuildContext context) {
//     return MaterialApp(
//       debugShowCheckedModeBanner: false,
//       title: 'Live Tv',
//       home: Scaffold(
//           appBar: AppBar(
//             title: const Text('Live TV'),
//           ),
//           body: const Home()),
//     );
//   }
// }


/////////////////////////////////////////////////////

import 'package:flutter/material.dart';

import 'screens/home.dart';

void main() => runApp(const M3UPlayer());

class M3UPlayer extends StatelessWidget {
  const M3UPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Live Tv',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Live TV'),
        ),
        body: const Home(),
      ),
    );
  }
}
