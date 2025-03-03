import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_dialog.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

void showLoginOrSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc) {
  showModalBottomSheet(
    context: context,
    clipBehavior: Clip.antiAlias,
    isScrollControlled: true,
    builder: (BuildContext context) {
      if (bloc.isAuthenticated) {
        return _buildSenseBoxSelection(context, bloc);
      } else {
        return _buildLoginRegisterTabs(context, bloc);
      }
    },
  );
}

Widget _buildLoginRegisterTabs(BuildContext context, OpenSenseMapBloc bloc) {
  return SizedBox(
    height: MediaQuery.of(context).size.height * 0.8,
    child: DefaultTabController(
      length: 2,
      child: Column(
        children: [
          TabBar(
            tabs: [
              Tab(
                text: AppLocalizations.of(context)!.openSenseMapLoginShort,
                height: 64,
              ),
              Tab(
                text: AppLocalizations.of(context)!.openSenseMapRegister,
                height: 64,
              ),
            ],
            dividerHeight: 0,
          ),
          Expanded(
            child: TabBarView(
              children: [
                LoginForm(bloc: bloc),
                RegisterForm(bloc: bloc),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc) {
  return SizedBox(
    height: MediaQuery.of(context).size.height * 0.8,
    child: Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          Row(
            children: [
              TextButton.icon(
                label: Text(AppLocalizations.of(context)!.openSenseMapLogout),
                icon: const Icon(Icons.logout),
                onPressed: () async => {
                  await bloc.logout(),
                  Navigator.pop(context),
                  showLoginOrSenseBoxSelection(context, bloc)
                },
              ),
              const Spacer(),
              IconButton.filled(
                icon: const Icon(Icons.add),
                onPressed: () async =>
                    {_showCreateSenseBoxDialog(context, bloc)},
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Expanded(child: SenseBoxSelectionWidget())
        ],
      ),
    ),
  );
}

Future<void> _showCreateSenseBoxDialog(
    BuildContext context, OpenSenseMapBloc bloc) {
  return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return const CreateBikeBoxDialog();
      });
}
