import 'package:flutter/material.dart';

class AigcStudioApp extends StatelessWidget {
  const AigcStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AIGC Studio',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const _SkeletonHomePage(),
    );
  }
}

class _SkeletonHomePage extends StatelessWidget {
  const _SkeletonHomePage();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AIGC Studio'),
      ),
      body: const Center(
        child: Text('Project skeleton ready'),
      ),
    );
  }
}
