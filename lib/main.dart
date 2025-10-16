import 'package:flutter/material.dart';
import 'audio_waveform_viewer.dart';
import 'opfs_test_widget.dart';
import 'pages/sign_in_demo_page.dart';
import 'pages/live_record_viewer.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter AI Speech',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.lightGreen),
      ),
      home: MyHomePage(),
    );
  }
}



class MyHomePage extends StatefulWidget {
  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    // Use IndexedStack to maintain state for all pages
    final pages = [
      AudioWaveformViewer(),
      OPFSTestWidget(),
      SignInDemo(),
      const LiveRecordViewer(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        return Scaffold(
          body: Row(
            children: [
              SafeArea(
                child: NavigationRail(
                  extended: constraints.maxWidth >= 600,
                  destinations: [
                    NavigationRailDestination(
                      icon: Icon(Icons.audiotrack),
                      label: Text('Waveform'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.storage),
                      label: Text('OPFS Test'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.cloud),
                      label: Text('Drive Demo'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.mic),
                      label: Text('Live Record'),
                    ),
                  ],
                  selectedIndex: selectedIndex,
                  onDestinationSelected: (value) {
                    setState(() {
                      selectedIndex = value;
                    });
                  },
                ),
              ),
              Expanded(
                child: Container(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: IndexedStack(
                    index: selectedIndex,
                    children: pages,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    );
  }
}


