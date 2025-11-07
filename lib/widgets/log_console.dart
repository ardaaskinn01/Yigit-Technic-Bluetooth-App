import 'package:flutter/material.dart';

class LogConsole extends StatefulWidget {
  final List<String> lines;
  final Function(String) onSendCommand;

  const LogConsole({
    super.key,
    required this.lines,
    required this.onSendCommand,
  });

  @override
  State<LogConsole> createState() => _LogConsoleState();
}

class _LogConsoleState extends State<LogConsole> {
  final TextEditingController _commandController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    // Loglar güncellendiğinde otomatik scroll
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  @override
  void didUpdateWidget(LogConsole oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Yeni log eklendiğinde otomatik scroll
    if (widget.lines.length > oldWidget.lines.length) {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  void _sendCommand() {
    final command = _commandController.text.trim();
    if (command.isNotEmpty) {
      widget.onSendCommand(command);
      _commandController.clear();
      FocusScope.of(context).unfocus(); // Klavyeyi kapat
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.blueGrey.shade900.withOpacity(0.9),
            Colors.blueGrey.shade800.withOpacity(0.9),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Başlık ve komut gönderme alanı
          Row(
            children: [
              const Text(
                'LOG KONSOLU',
                style: TextStyle(
                  color: Colors.white70,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Icon(
                Icons.terminal,
                color: Colors.blueAccent,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Komut gönderme alanı
          Container(
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commandController,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 14,
                      color: Colors.white,
                    ),
                    decoration: const InputDecoration(
                      hintText: 'Komut girin... (A, K, V1, TEST, vb.)',
                      hintStyle: TextStyle(color: Colors.white54),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      border: InputBorder.none,
                    ),
                    onSubmitted: (_) => _sendCommand(),
                  ),
                ),
                Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: Colors.blueAccent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.white, size: 18),
                    onPressed: _sendCommand,
                    tooltip: 'Komutu Gönder',
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Log listesi
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.25),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: Scrollbar(
                controller: _scrollController,
                child: ListView.builder(
                  controller: _scrollController,
                  itemCount: widget.lines.length,
                  itemBuilder: (ctx, i) {
                    final line = widget.lines[i];
                    Color textColor = Colors.white70;
                    // Komut satırlarını farklı renkte göster
                    if (line.contains('->')) {
                      textColor = Colors.blueAccent;
                    } else if (line.contains('HATA') || line.contains('ERROR')) {
                      textColor = Colors.redAccent;
                    } else if (line.contains('BAŞARILI') || line.contains('SUCCESS')) {
                      textColor = Colors.greenAccent;
                    } else if (line.contains('UYARI') || line.contains('WARN')) {
                      textColor = Colors.orangeAccent;
                    }

                    return Text(
                      line,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: textColor,
                        height: 1.2,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),

          // Alt bilgi
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                '${widget.lines.length} log',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  if (widget.lines.isNotEmpty) {
                    _scrollController.animateTo(
                      0,
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOut,
                    );
                  }
                },
                child: const Text(
                  '↑ Başa dön',
                  style: TextStyle(
                    color: Colors.blueAccent,
                    fontSize: 10,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _commandController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}