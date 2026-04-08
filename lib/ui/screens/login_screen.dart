import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensebox_bike/l10n/app_localizations.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/common/screen_wrapper.dart';
import 'package:sensebox_bike/ui/widgets/common/underlined_text_tabs.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(_handleTabChanged);
  }

  @override
  void dispose() {
    _tabController.removeListener(_handleTabChanged);
    _tabController.dispose();
    super.dispose();
  }

  void _handleTabChanged() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final osemBloc = context.read<OpenSenseMapBloc>();
    final localizations = AppLocalizations.of(context)!;

    return Center(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Text(
              localizations.loginScreenTitle,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ),
          UnderlinedTextTabs(
            items: [
              localizations.generalLogin,
              localizations.generalRegister,
            ],
            selectedIndex: _tabController.index,
            onSelected: (index) {
              _tabController.animateTo(index);
            },
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                LoginForm(bloc: osemBloc),
                RegisterForm(bloc: osemBloc),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
