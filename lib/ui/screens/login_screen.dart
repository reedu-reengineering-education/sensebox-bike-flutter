import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final OpenSenseMapBloc osemBloc = Provider.of<OpenSenseMapBloc>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(AppLocalizations.of(context)!.loginScreenTitle),
      ),
      body: Center(
        child: DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabAlignment: TabAlignment.start,
            isScrollable: true,
            tabs: [
              Tab(
                text: AppLocalizations.of(context)!.generalLogin,
                height: 64,
              ),
              Tab(
                text: AppLocalizations.of(context)!.generalRegister,
                height: 64,
              ),
            ],
            dividerHeight: 0,
          ),
          Expanded(
            child: TabBarView(
              children: [
                LoginForm(bloc: osemBloc),
                RegisterForm(bloc: osemBloc),
              ],
            ),
          ),
        ],
      ),
    ),
      ),
    );
  }
}