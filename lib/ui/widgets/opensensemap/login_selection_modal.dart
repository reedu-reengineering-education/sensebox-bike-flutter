import 'package:flutter/material.dart';
import 'package:sensebox_bike/blocs/opensensemap_bloc.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/create_bike_box_dialog.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/login.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/register.dart';
import 'package:sensebox_bike/ui/widgets/opensensemap/sensebox_selection.dart';

void showLoginOrSenseBoxSelection(BuildContext context, OpenSenseMapBloc bloc) {
  showModalBottomSheet(
    context: context,
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
    height: MediaQuery.of(context).size.height * 0.7,
    child: DefaultTabController(
      length: 2,
      child: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(0, 32, 0, 8),
            child: Text('Login or Register', style: TextStyle(fontSize: 18)),
          ),
          const TabBar(
            tabs: [
              Tab(text: 'Login'),
              Tab(text: 'Register'),
            ],
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
          // create a row with two buttons and a text in the middle
          // left is a back button called Logout and right is a plus button called Add SenseBox
          // the text in the middle is called Select a SenseBox

          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () async => {
                  await bloc.logout(),
                  showLoginOrSenseBoxSelection(context, bloc)
                },
              ),
              const Spacer(),
              const Text('Select a senseBox', style: TextStyle(fontSize: 18)),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () async =>
                    {_showCreateSenseBoxDialog(context, bloc)},
              ),
            ],
          ),

          // const Text('Select a SenseBox', style: TextStyle(fontSize: 18)),
          // FilledButton(
          //     onPressed: () async => {await bloc.logout()},
          //     child: const Text("Logout")),
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
        return CreateBikeBoxDialog();
      });
}
