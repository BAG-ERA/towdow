// Full-screen navigation screen for mobile
// Shows the same content as the drawer/sidebar, but as a page

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../widgets/navbar/app_sidebar.dart';

class NavScreen extends ConsumerWidget {
  const NavScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: AppSidebar(currentDestination: null, fullWidth: true),
      ),
    );
  }
}


