import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../data/models/gateway.dart';
import '../../data/providers/gateway_provider.dart';
import '../../data/providers/room_provider.dart';

class CreateSessionScreen extends ConsumerStatefulWidget {
  const CreateSessionScreen({super.key});

  @override
  ConsumerState<CreateSessionScreen> createState() => _CreateSessionScreenState();
}

class _CreateSessionScreenState extends ConsumerState<CreateSessionScreen> {
  final Set<String> _selectedAgentIds = {};
  String _selectedMode = 'broadcast';
  bool _isCreating = false;

  List<GatewayStatus> _agents = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchAgents();
  }

  Future<void> _fetchAgents() async {
    setState(() { _loading = true; _error = null; });
    try {
      final notifier = ref.read(gatewaysNotifierProvider.notifier);
      final statuses = await notifier.fetchGatewayStatus();
      setState(() { _agents = statuses; _loading = false; });
    } catch (e) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  bool get _isSingleSelection => _selectedAgentIds.length == 1;
  bool get _isMultiSelection => _selectedAgentIds.length >= 2;
  bool get _canCreate => _selectedAgentIds.isNotEmpty;

  String get _roomName {
    if (_isSingleSelection) {
      final agent = _agents.firstWhere((a) => a.profile == _selectedAgentIds.first);
      return '与 ${agent.profile} 的对话';
    }
    final names = _selectedAgentIds.toList();
    return '群聊 ${names.take(3).join(', ')}${names.length > 3 ? '...' : ''}';
  }

  String get _buttonText {
    if (_isSingleSelection) {
      final agent = _agents.firstWhere((a) => a.profile == _selectedAgentIds.first);
      return '开始与 ${agent.profile} 对话';
    }
    return '创建群聊';
  }

  Future<void> _createSession() async {
    if (!_canCreate || _isCreating) return;

    setState(() { _isCreating = true; });
    try {
      final mode = _isSingleSelection ? 'direct' : _selectedMode;
      final room = await ref.read(roomsProvider.notifier).createRoom(
        name: _roomName,
        agentIds: _selectedAgentIds.toList(),
        mode: mode,
      );
      if (mounted) {
        context.pushReplacement('/chat/${room.id}?name=${Uri.encodeComponent(room.name)}');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('创建会话失败: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() { _isCreating = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Color(0xFFECECEC)),
          onPressed: () => context.pop(),
        ),
        title: const Text('新建对话', style: TextStyle(color: Color(0xFFECECEC))),
        actions: [
          IconButton(
            icon: const Icon(Icons.close, color: Color(0xFFECECEC)),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.error_outline, size: 64, color: Colors.grey[600]),
                      const SizedBox(height: 16),
                      Text('加载失败', style: TextStyle(color: Colors.grey[500])),
                      TextButton(onPressed: _fetchAgents, child: const Text('重试')),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Agent selection header
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  '选择 Agent',
                                  style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                                ),
                                if (_selectedAgentIds.isEmpty)
                                  const Text(
                                    '至少选择 1 个',
                                    style: TextStyle(color: Color(0xFF8E8E93), fontSize: 12),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Agent list
                            Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E1E1E),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: ListView.separated(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _agents.length,
                                separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFF3A3A3C)),
                                itemBuilder: (context, index) => _AgentSelectionItem(
                                  agent: _agents[index],
                                  isSelected: _selectedAgentIds.contains(_agents[index].profile),
                                  onToggle: () {
                                    setState(() {
                                      final id = _agents[index].profile;
                                      if (_selectedAgentIds.contains(id)) {
                                        _selectedAgentIds.remove(id);
                                      } else {
                                        _selectedAgentIds.add(id);
                                      }
                                    });
                                  },
                                ),
                              ),
                            ),

                            // Mode selection (only for multi-select)
                            if (_isMultiSelection) ...[
                              const SizedBox(height: 24),
                              const Text(
                                '协作模式',
                                style: TextStyle(color: Color(0xFFB0B0B0), fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  _ModeChip(
                                    label: '广播',
                                    isSelected: _selectedMode == 'broadcast',
                                    onTap: () => setState(() => _selectedMode = 'broadcast'),
                                  ),
                                  const SizedBox(width: 8),
                                  _ModeChip(
                                    label: '指定',
                                    isSelected: _selectedMode == 'mention',
                                    onTap: () => setState(() => _selectedMode = 'mention'),
                                  ),
                                  const SizedBox(width: 8),
                                  _ModeChip(
                                    label: '路由',
                                    isSelected: _selectedMode == 'router',
                                    onTap: () => setState(() => _selectedMode = 'router'),
                                  ),
                                ],
                              ),
                            ],

                            // 1:1 hint
                            if (_isSingleSelection) ...[
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5856D6).withAlpha(25),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: const Color(0xFF5856D6).withAlpha(50)),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(Icons.lightbulb_outline, color: Color(0xFF5856D6), size: 18),
                                    SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '将创建 1:1 对话',
                                        style: TextStyle(color: Color(0xFF5856D6), fontSize: 13),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),

                    // Create button
                    Container(
                      padding: const EdgeInsets.all(16),
                      child: SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _canCreate && !_isCreating ? _createSession : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _canCreate ? const Color(0xFF5856D6) : const Color(0xFF3A3A3C),
                            disabledBackgroundColor: const Color(0xFF3A3A3C),
                            foregroundColor: Colors.white,
                            disabledForegroundColor: const Color(0xFF8E8E93),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _isCreating
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(_buttonText, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }
}

class _AgentSelectionItem extends StatelessWidget {
  final GatewayStatus agent;
  final bool isSelected;
  final VoidCallback onToggle;

  const _AgentSelectionItem({
    required this.agent,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        color: isSelected ? const Color(0xFF262626) : Colors.transparent,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: const Color(0xFF5856D6),
              child: Text(
                agent.profile.isNotEmpty ? agent.profile[0].toUpperCase() : 'A',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    agent.profile,
                    style: const TextStyle(
                      color: Color(0xFFECECEC),
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: agent.running ? const Color(0xFF34C759) : const Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        agent.running ? '在线' : '离线',
                        style: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? const Color(0xFF5856D6) : Colors.transparent,
                border: Border.all(
                  color: isSelected ? const Color(0xFF5856D6) : const Color(0xFF3A3A3C),
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _ModeChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF5856D6) : const Color(0xFF2A2A2A),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFF5856D6) : const Color(0xFF3A3A3C),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(Icons.check, size: 16, color: Colors.white),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : const Color(0xFF8E8E93),
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
