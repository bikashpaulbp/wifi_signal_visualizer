import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


/// Security scanner: lists all networks with security level,
/// flags OPEN / WEP / default-SSID networks.
class SecuritySheet extends StatelessWidget {
  const SecuritySheet({super.key, required this.networks});
  final List<WifiNetwork> networks;

  static void show(List<WifiNetwork> nets) => Get.bottomSheet(
    SecuritySheet(networks: nets),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );

  @override
  Widget build(BuildContext context) {
    final sorted = [...networks]..sort((a, b) {
      final sa = SignalUtils.securityFromCapabilities(a.capabilities).index;
      final sb = SignalUtils.securityFromCapabilities(b.capabilities).index;
      return sa.compareTo(sb); // open first
    });

    final openCount = networks.where((n) =>
        SignalUtils.securityFromCapabilities(n.capabilities) == SecurityLevel.open
    ).length;
    final wepCount = networks.where((n) =>
        SignalUtils.securityFromCapabilities(n.capabilities) == SecurityLevel.wep
    ).length;
    final defaultCount = networks.where((n) =>
        SignalUtils.isDefaultSsid(n.ssid)).length;

    return DraggableScrollableSheet(
      initialChildSize: 0.70,
      minChildSize: 0.40,
      maxChildSize: 0.92,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.bgCardBorder, width: 1.5)),
        ),
        child: Column(children: [
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.bgCardBorder,
                borderRadius: BorderRadius.circular(2)))),
          // Header
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
            child: Row(children: [
              const Icon(Icons.security_rounded, color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Security Scanner',
                style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
                    fontWeight: FontWeight.w800, fontFamily: 'monospace'))),
              _Badge('${networks.length} networks', AppColors.textSecondary),
            ])),
          // Summary chips
          if (openCount > 0 || wepCount > 0 || defaultCount > 0)
            Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 12),
              child: Row(children: [
                if (openCount > 0)
                  _AlertChip('$openCount OPEN', AppColors.danger),
                if (wepCount > 0) ...[
                  const SizedBox(width: 6),
                  _AlertChip('$wepCount WEP', const Color(0xFFFF8C00)),
                ],
                if (defaultCount > 0) ...[
                  const SizedBox(width: 6),
                  _AlertChip('$defaultCount default SSID', AppColors.sigFair),
                ],
              ])),
          // List
          Expanded(child: ListView.builder(
            controller: sc,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: sorted.length,
            itemBuilder: (_, i) => _SecurityTile(network: sorted[i]),
          )),
        ]),
      ),
    );
  }
}

class _SecurityTile extends StatelessWidget {
  const _SecurityTile({required this.network});
  final WifiNetwork network;

  @override
  Widget build(BuildContext context) {
    final sec   = SignalUtils.securityFromCapabilities(network.capabilities);
    final sc    = SignalUtils.securityColor(sec);
    final isWrn = SignalUtils.isSecurityWarning(sec);
    final isDef = SignalUtils.isDefaultSsid(network.ssid);
    final qc    = SignalUtils.qualityColor(network.quality);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: isWrn ? AppColors.danger.withOpacity(0.06) : AppColors.bgCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: isWrn ? sc.withOpacity(0.5) : AppColors.bgCardBorder),
      ),
      child: Row(children: [
        // Security icon
        Container(width: 36, height: 36,
          decoration: BoxDecoration(
              color: sc.withOpacity(0.15), shape: BoxShape.circle),
          child: Icon(
            sec == SecurityLevel.open    ? Icons.lock_open_rounded :
            sec == SecurityLevel.wep     ? Icons.lock_clock_outlined :
            sec == SecurityLevel.wpa3    ? Icons.verified_user_rounded :
            Icons.lock_rounded,
            color: sc, size: 18)),
        const SizedBox(width: 12),
        // SSID + details
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Row(children: [
            Flexible(child: Text(network.displaySsid,
              style: TextStyle(color: isWrn ? sc : AppColors.textPrimary,
                  fontSize: 13, fontWeight: FontWeight.w700,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis)),
            if (isDef) ...[const SizedBox(width: 6),
              _SmallBadge('DEFAULT SSID', AppColors.sigFair)],
          ]),
          const SizedBox(height: 3),
          Row(children: [
            _SmallBadge(SignalUtils.securityLabel(sec), sc),
            const SizedBox(width: 6),
            Text(SignalUtils.bandLabel(network.band),
                style: TextStyle(color: AppColors.textSecondary,
                    fontSize: 9, fontFamily: 'monospace')),
          ]),
          if (isWrn) ...[
            const SizedBox(height: 4),
            Text(
              sec == SecurityLevel.open
                  ? '⚠ No encryption — traffic is visible to anyone nearby'
                  : '⚠ WEP is broken — easily cracked in under 1 minute',
              style: const TextStyle(color: AppColors.danger, fontSize: 9,
                  fontFamily: 'monospace'),
            ),
          ],
          if (isDef && !isWrn)
            const Padding(padding: EdgeInsets.only(top: 4),
              child: Text('⚠ Default router SSID — may use default credentials',
                style: TextStyle(color: AppColors.sigFair, fontSize: 9,
                    fontFamily: 'monospace'))),
        ])),
        const SizedBox(width: 8),
        // dBm
        Text('${network.rssi}', style: TextStyle(color: qc, fontSize: 14,
            fontWeight: FontWeight.w800, fontFamily: 'monospace')),
      ]),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge(this.label, this.color);
  final String label; final Color color;
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(6)),
    child: Text(label, style: TextStyle(color: color,
        fontSize: 10, fontFamily: 'monospace')));
}

class _AlertChip extends StatelessWidget {
  const _AlertChip(this.label, this.color);
  final String label; final Color color;
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.5))),
    child: Text(label, style: TextStyle(color: color, fontSize: 10,
        fontWeight: FontWeight.w700, fontFamily: 'monospace')));
}

class _SmallBadge extends StatelessWidget {
  const _SmallBadge(this.label, this.color);
  final String label; final Color color;
  @override Widget build(BuildContext ctx) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
    decoration: BoxDecoration(color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(4)),
    child: Text(label, style: TextStyle(color: color, fontSize: 8,
        fontWeight: FontWeight.w700, fontFamily: 'monospace')));
}