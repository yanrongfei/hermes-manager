import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/providers/api_provider.dart';

final skillsProvider = FutureProvider<List<dynamic>>((ref) async {
  try {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/api/hermes/skills');
    return response.data as List<dynamic>;
  } catch (e) {
    return [];
  }
});

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final skillsAsync = ref.watch(skillsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF212121),
      appBar: AppBar(
        backgroundColor: const Color(0xFF2A2A2A),
        title: const Text('Skills', style: TextStyle(color: Color(0xFFECECEC))),
        iconTheme: const IconThemeData(color: Color(0xFFECECEC)),
      ),
      body: skillsAsync.when(
        data: (skills) => skills.isEmpty
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.psychology_outlined, size: 64, color: Colors.grey[700]),
                    const SizedBox(height: 16),
                    Text(
                      '暂无 Skills',
                      style: TextStyle(color: Colors.grey[600], fontSize: 16),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '添加 Gateway 后自动发现',
                      style: TextStyle(color: Colors.grey[700], fontSize: 13),
                    ),
                  ],
                ),
              )
            : ListView.builder(
                itemCount: skills.length,
                itemBuilder: (context, index) {
                  final skill = skills[index];
                  final name = skill['name'] ?? skill['id'] ?? 'Unknown';
                  final description = skill['description'] ?? '';

                  return Card(
                    color: const Color(0xFF2A2A2A),
                    margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0xFF5856D6),
                        child: Icon(Icons.flash_on, color: Colors.white, size: 20),
                      ),
                      title: Text(
                        name,
                        style: const TextStyle(color: Color(0xFFECECEC)),
                      ),
                      subtitle: Text(
                        description,
                        style: TextStyle(color: Colors.grey[500], fontSize: 13),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      trailing: Icon(Icons.chevron_right, color: Colors.grey[600]),
                    ),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: Colors.grey[700]),
              const SizedBox(height: 12),
              Text(
                '无法加载 Skills',
                style: TextStyle(color: Colors.grey[500]),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.refresh(skillsProvider),
                child: const Text('重试'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
