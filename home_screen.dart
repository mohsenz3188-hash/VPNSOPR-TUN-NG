import 'package:flutter/material.dart';

import '../theme.dart';
import '../core/vpn_controller.dart';
import '../widgets/cyber_background.dart';
import '../widgets/neon_connect_button.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});
  final VpnController controller;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final connected = controller.isConnected;
        final stats = controller.stats;
        return CyberBackground(
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    _buildHeader(),
                    const SizedBox(height: 22),
                    if (controller.lastError != null) ...[
                      _ErrorBanner(
                        message: controller.lastError!,
                        onClose: controller.clearError,
                      ),
                      const SizedBox(height: 14),
                    ],
                    _buildStatus(connected),
                    const SizedBox(height: 22),
                    Center(
                      child: NeonConnectButton(
                        connected: connected,
                        loading: controller.busy || controller.isTransitioning,
                        onPressed: controller.toggleConnection,
                      ),
                    ),
                    const SizedBox(height: 23),
                    _buildSelectedServer(context),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _TrafficCard(
                            icon: Icons.south_rounded,
                            label: 'دریافت',
                            speed: formatSpeed(stats?.downlink),
                            total: formatBytes(stats?.downlinkTotal),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _TrafficCard(
                            icon: Icons.north_rounded,
                            label: 'ارسال',
                            speed: formatSpeed(stats?.uplink),
                            total: formatBytes(stats?.uplinkTotal),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _buildQuickActions(context),
                    const SizedBox(height: 20),
                    _buildFooter(),
                  ]),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(15),
          child: Image.asset(
            'assets/vpnsopr_logo.jpg',
            width: 62,
            height: 62,
            fit: BoxFit.cover,
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('TUN VPNSOPR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 20, letterSpacing: 0.8)),
              SizedBox(height: 3),
              Text('SECURE • PRIVATE • CONNECTED', style: TextStyle(color: neonCyan, fontSize: 9, letterSpacing: 1.1, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          decoration: BoxDecoration(
            color: neonBlue.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: neonBlue.withValues(alpha: 0.25)),
          ),
          child: const Row(
            children: [
              Icon(Icons.verified_user_outlined, color: neonCyan, size: 14),
              SizedBox(width: 5),
              Text('PRO', style: TextStyle(color: neonCyan, fontWeight: FontWeight.w800, fontSize: 10)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStatus(bool connected) {
    final color = connected ? neonCyan : const Color(0xFF8DA4BF);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [BoxShadow(color: color.withValues(alpha: 0.7), blurRadius: 10)]),
        ),
        const SizedBox(width: 8),
        Text(
          connected ? 'اتصال برقرار است' : (controller.isTransitioning ? 'در حال برقراری ارتباط...' : 'اتصال برقرار نیست'),
          style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildSelectedServer(BuildContext context) {
    final profile = controller.selectedProfile;
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(19),
        border: Border.all(color: neonBlue.withValues(alpha: 0.20)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(color: neonBlue.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(13)),
            child: const Icon(Icons.dns_rounded, color: neonCyan),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('سرور انتخاب‌شده', style: TextStyle(color: mutedText, fontSize: 11)),
                const SizedBox(height: 4),
                Text(
                  profile?.name ?? 'هنوز کانفیگی اضافه نشده',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 14),
                ),
                const SizedBox(height: 3),
                Text(
                  profile == null ? 'از بخش سرورها کانفیگ وارد کن' : '${profile.outboundsCount ?? 1} مسیر قابل استفاده',
                  style: const TextStyle(color: mutedText, fontSize: 10),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'تست تأخیر',
            onPressed: controller.isConnected ? controller.testLatency : null,
            icon: const Icon(Icons.speed_rounded, color: neonCyan),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: controller.isConnected ? controller.testLatency : null,
            icon: const Icon(Icons.network_check_rounded, size: 18),
            label: const Text('تست تأخیر'),
            style: OutlinedButton.styleFrom(
              foregroundColor: neonCyan,
              side: BorderSide(color: neonBlue.withValues(alpha: 0.35)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () => _showServerSummary(context),
            icon: const Icon(Icons.storage_rounded, size: 18),
            label: Text('${controller.profiles.length} کانفیگ'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white,
              side: BorderSide(color: neonBlue.withValues(alpha: 0.20)),
              padding: const EdgeInsets.symmetric(vertical: 13),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
          ),
        ),
      ],
    );
  }

  void _showServerSummary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: panel,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('کانفیگ‌های ذخیره‌شده', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17)),
            const SizedBox(height: 10),
            for (final profile in controller.profiles.take(6))
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.dns_outlined, color: neonCyan),
                title: Text(profile.name, style: const TextStyle(color: Colors.white)),
                trailing: controller.selectedProfile?.id == profile.id ? const Icon(Icons.check_circle, color: neonCyan) : null,
              ),
            if (controller.profiles.isEmpty)
              const Text('هنوز سروری وارد نشده است.', style: TextStyle(color: mutedText)),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Center(
      child: Text(
        'SING-BOX CORE  ${controller.coreVersion ?? '—'}',
        style: TextStyle(color: mutedText.withValues(alpha: 0.65), fontSize: 9, letterSpacing: 1.2),
      ),
    );
  }
}

class _TrafficCard extends StatelessWidget {
  const _TrafficCard({required this.icon, required this.label, required this.speed, required this.total});
  final IconData icon;
  final String label;
  final String speed;
  final String total;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: panel.withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: neonCyan, size: 17),
              const SizedBox(width: 7),
              Text(label, style: const TextStyle(color: mutedText, fontSize: 11)),
            ],
          ),
          const SizedBox(height: 10),
          Text(speed, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text('مجموع: $total', style: const TextStyle(color: mutedText, fontSize: 10)),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onClose});
  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF4B1B2B).withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFF667A).withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Color(0xFFFF8291), size: 19),
          const SizedBox(width: 9),
          Expanded(child: Text(message, maxLines: 3, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Colors.white, fontSize: 11))),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close, color: Colors.white70, size: 18), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}
