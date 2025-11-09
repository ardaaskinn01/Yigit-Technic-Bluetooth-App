import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/app_state.dart';
import '../widgets/log_console.dart';

class LogScreen extends StatelessWidget {
  const LogScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Consumer<AppState>(
        builder: (context, app, child) {
          return LogConsole(
            lines: app.logs,
            onSendCommand: (command) {
              app.sendCommand(command);

              if (command.toLowerCase() == 'clear') {
                app.clearLogs();
              } else if (command.toLowerCase() == 'help') {
                app.logs.add('[SİSTEM] Kullanılabilir komutlar: A, K, V1-V7, VR, TEST, TEST_STOP, PUAN, DUR, aq');
              }
            },
          );
        },
      ),
    );
  }
}
