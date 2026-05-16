import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/agent.dart';
import '../../data/providers/profile_provider.dart';

class ProfileDetailScreen extends ConsumerWidget {
  final String profileId;
  final String profileName;

  const ProfileDetailScreen({super.key, required this.profileId, required this.profileName});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileDetailProvider(profileId));
    final agentsAsync = ref.watch(profileAgentsProvider(profileId));

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: Text(profileName, style: const TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFFECECEC)),
            onPressed: () {
              ref.invalidate(profileDetailProvider(profileId));
              ref.invalidate(profileAgentsProvider(profileId));
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Profile info card
          profileAsync.when(
            data: (profile) => Card(
              color: const Color(0xFF2A2A2A),
              margin: const EdgeInsets.all(12),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (profile.model != null)
                      _InfoRow(label: '模型', value: profile.model!),
                    if (profile.provider != null) ...[
                      const SizedBox(height: 4),
                      _InfoRow(label: '提供商', value: profile.provider!),
                    ],
                    const SizedBox(height: 4),
                    _InfoRow(label: '技能', value: '${profile.skills}'),
                  ],
                ),
              ),
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
          // Agents list
          Expanded(
            child: agentsAsync.when(
              data: (agents) => agents.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.smart_toy_outlined, size: 48, color: Colors.grey[700]),
                          const SizedBox(height: 12),
                          Text('暂无 Agent', style: TextStyle(color: Colors.grey[500], fontSize: 15)),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: agents.length,
                      itemBuilder: (context, index) => _AgentTile(agent: agents[index]),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.grey[600]),
                    const SizedBox(height: 12),
                    Text('加载失败', style: TextStyle(color: Colors.grey[500])),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(width: 60, child: Text('$label:', style: TextStyle(color: Colors.grey[500], fontSize: 13))),
        Expanded(child: Text(value, style: const TextStyle(color: Color(0xFFECECEC), fontSize: 13))),
      ],
    );
  }
}

class _AgentTile extends StatelessWidget {
  final Agent agent;

  const _AgentTile({required this.agent});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: const Color(0xFF2A2A2A),
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF5856D6),
          child: Text(
            agent.name.isNotEmpty ? agent.name[0].toUpperCase() : 'A',
            style: const TextStyle(color: Colors.white),
          ),
        ),
        title: Text(agent.name, style: const TextStyle(color: Color(0xFFECECEC))),
        subtitle: agent.description != null
            ? Text(agent.description!, style: TextStyle(color: Colors.grey[600], fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis)
            : null,
        trailing: agent.invited
            ? const Icon(Icons.check_circle, color: Color(0xFF34C759), size: 20)
            : TextButton(
                style: TextButton.styleFrom(foregroundColor: const Color(0xFF2AABEE), minimumSize: Size.zero, padding: const EdgeInsets.symmetric(horizontal: 8)),
                onPressed: () {
                  // TODO: implement invite to room
                },
                child: const Text('邀请', style: TextStyle(fontSize: 13)),
              ),
      ),
    );
  }
}
