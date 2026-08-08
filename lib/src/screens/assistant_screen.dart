import 'package:flutter/material.dart';

import '../services/citizen_assistant_service.dart';

class AssistantScreen extends StatefulWidget {
  const AssistantScreen({super.key});

  @override
  State<AssistantScreen> createState() => _AssistantScreenState();
}

class _Message {
  const _Message(this.text, {required this.fromUser, this.engineLabel});

  final String text;
  final bool fromUser;
  final String? engineLabel;
}

class _AssistantScreenState extends State<AssistantScreen> {
  final _controller = TextEditingController();
  final CitizenAssistantService _service = CitizenAssistantService();
  final _messages = <_Message>[];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _messages.add(
      _Message(
        'Hello. Ask me about flood, landslide, elephant, or waste safety.',
        fromUser: false,
        engineLabel: 'SAFETY ASSISTANT',
      ),
    );
  }

  Future<void> _send([String? suggestion]) async {
    final question = suggestion ?? _controller.text.trim();
    if (question.isEmpty || _busy) return;
    _controller.clear();
    setState(() {
      _messages.add(_Message(question, fromUser: true, engineLabel: null));
      _busy = true;
    });
    final reply = await _service.ask(question);
    if (!mounted) return;
    setState(() {
      _messages.add(_Message(reply.text,
          fromUser: false, engineLabel: reply.engineLabel));
      _busy = false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _service.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Citizen AI assistant')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final prompt in const [
                  'What should I do during a flood?',
                  'Elephant near my house',
                  'Landslide warning signs',
                  'Bin is 90% full',
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ActionChip(
                      label: Text(prompt),
                      onPressed: () => _send(prompt),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                return Align(
                  alignment: message.fromUser
                      ? Alignment.centerRight
                      : Alignment.centerLeft,
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 330),
                    margin: const EdgeInsets.only(bottom: 10),
                    padding: const EdgeInsets.all(13),
                    decoration: BoxDecoration(
                      color: message.fromUser
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context)
                              .colorScheme
                              .surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          message.text,
                          style: TextStyle(
                            color: message.fromUser ? Colors.white : null,
                            height: 1.4,
                          ),
                        ),
                        if (!message.fromUser &&
                            message.engineLabel != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            message.engineLabel!,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          if (_busy) const LinearProgressIndicator(),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: const InputDecoration(
                        hintText: 'Ask a safety question',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _busy ? null : _send,
                    icon: const Icon(Icons.send_rounded),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
