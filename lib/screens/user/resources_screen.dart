import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../theme.dart';

class ResourcesScreen extends StatelessWidget {
  const ResourcesScreen({super.key});

  Future<void> _call(String number) => launchUrl(Uri(scheme: 'tel', path: number));
  Future<void> _sms(String number) => launchUrl(Uri(scheme: 'sms', path: number));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Resources')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.emergency_outlined, color: Colors.red),
                SizedBox(width: 8),
                Expanded(
                  child: Text('If you or someone else is in immediate danger, call 911.',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('Crisis & Mental Health Support'),
          _ResourceTile(
            icon: Icons.self_improvement,
            title: '988 Suicide & Crisis Lifeline',
            subtitle: 'Free, confidential support 24/7 \u2014 call or text 988.',
            onCall: () => _call('988'),
            onText: () => _sms('988'),
          ),
          _ResourceTile(
            icon: Icons.support_agent,
            title: 'SAMHSA National Helpline',
            subtitle: 'Free, confidential help for mental health or substance use, 24/7.',
            onCall: () => _call('18006624357'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Safety'),
          _ResourceTile(
            icon: Icons.shield_outlined,
            title: 'National Domestic Violence Hotline',
            subtitle: 'Confidential support 24/7.',
            onCall: () => _call('18007997233'),
          ),
          _ResourceTile(
            icon: Icons.report_gmailerrorred_outlined,
            title: 'National Human Trafficking Hotline',
            subtitle: 'Confidential support 24/7.',
            onCall: () => _call('18883737888'),
          ),
          const SizedBox(height: 16),
          const _SectionLabel('Find Local Help'),
          _ResourceTile(
            icon: Icons.place_outlined,
            title: '211 \u2014 Local Community Services',
            subtitle: 'Connects you to nearby food, shelter, and utility assistance.',
            onCall: () => _call('211'),
          ),
          const SizedBox(height: 20),
          const _SectionLabel('A Quick Grounding Technique'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('5-4-3-2-1 Method', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 6),
                  Text(
                    'If you\'re feeling overwhelmed, try naming: 5 things you can see, '
                    '4 things you can touch, 3 things you can hear, 2 things you can smell, '
                    'and 1 thing you can taste. This can help bring your focus back to the '
                    'present moment.',
                    style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'This list is for general information and is not a substitute for professional care.',
            style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
    );
  }
}

class _ResourceTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onCall;
  final VoidCallback? onText;

  const _ResourceTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onCall,
    this.onText,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: AppColors.userPrimary),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.call), color: AppColors.primary, onPressed: onCall),
            if (onText != null)
              IconButton(icon: const Icon(Icons.sms_outlined), color: AppColors.primary, onPressed: onText),
          ],
        ),
      ),
    );
  }
}