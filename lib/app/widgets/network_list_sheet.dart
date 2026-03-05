import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/data/models/wifi_network.dart';
import 'package:wifi_signal_visualizer/app/modules/scanner/controllers/scanner_controller.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class NetworkListSheet extends StatelessWidget {
  const NetworkListSheet({super.key});

  static void show() => Get.bottomSheet(
        const NetworkListSheet(),
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
      );

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ScannerController>();
    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize:     0.30,
      maxChildSize:     0.92,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(top: BorderSide(color: AppColors.bgCardBorder, width: 1.5)),
        ),
        child: Column(children: [
          // Handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(color: AppColors.bgCardBorder,
                borderRadius: BorderRadius.circular(2)))),

          // Header
          Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: Row(children: [
              const Text('Nearby Networks', style: TextStyle(
                color: AppColors.textPrimary, fontSize: 16,
                fontWeight: FontWeight.w800, fontFamily: 'monospace',
              )),
              const Spacer(),
              Obx(() => Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accent.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text('${ctrl.networks.length} found',
                    style: const TextStyle(color: AppColors.accent,
                        fontSize: 10, fontFamily: 'monospace')),
              )),
            ])),

          // Network list
          Expanded(child: Obx(() {
            if (ctrl.networks.isEmpty) {
              return const Center(child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  CircularProgressIndicator(
                      color: AppColors.accent, strokeWidth: 2),
                  SizedBox(height: 16),
                  Text('Scanning for networks…',
                      style: TextStyle(color: AppColors.textSecondary,
                          fontFamily: 'monospace')),
                ]),
              ));
            }
            return ListView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: ctrl.networks.length,
              itemBuilder: (_, i) {
                final net = ctrl.networks[i];
                return _NetworkTile(
                  net:        net,
                  isSelected: net.key == ctrl.selectedKey.value,
                  onTap: () { ctrl.selectNetwork(net.key); Get.back(); },
                );
              },
            );
          })),
        ]),
      ),
    );
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.net,
    required this.isSelected,
    required this.onTap,
  });
  final WifiNetwork  net;
  final bool         isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final qc     = SignalUtils.qualityColor(net.quality);
    final bc     = SignalUtils.bandColor(net.band);
    final filled = SignalUtils.qualityBars(net.rssi);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin:  const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.accent.withOpacity(0.10) : AppColors.bgCard,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.accent.withOpacity(0.8)
                : net.isConnected ? AppColors.selected.withOpacity(0.6)
                : AppColors.bgCardBorder,
            width: isSelected ? 1.5 : 1.0,
          ),
        ),
        child: Row(children: [
          // Signal bars
          Row(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) => Container(
              width: 4, height: 6.0 + i * 3.5,
              margin: const EdgeInsets.only(right: 2),
              decoration: BoxDecoration(
                color: i < filled ? qc : qc.withOpacity(0.18),
                borderRadius: BorderRadius.circular(1.5),
              )))),
          const SizedBox(width: 12),

          // SSID + meta
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Row(children: [
              Flexible(child: Text(net.displaySsid, style: TextStyle(
                color: isSelected ? AppColors.accent : AppColors.textPrimary,
                fontSize: 13, fontWeight: FontWeight.w700,
                fontFamily: 'monospace',
              ), overflow: TextOverflow.ellipsis)),
              if (net.isConnected) ...[const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color: AppColors.selected.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('connected',
                      style: TextStyle(color: AppColors.selected,
                          fontSize: 8, fontFamily: 'monospace')),
                )],
            ]),
            const SizedBox(height: 3),
            Text('${SignalUtils.bandLabel(net.band)}  ·  ${net.frequencyMhz} MHz',
                style: TextStyle(color: bc.withOpacity(0.75),
                    fontSize: 10, fontFamily: 'monospace')),
          ])),
          const SizedBox(width: 8),

          // dBm
          RichText(text: TextSpan(children: [
            TextSpan(text: '${net.rssi}', style: TextStyle(
                color: qc, fontSize: 16, fontWeight: FontWeight.w800,
                fontFamily: 'monospace')),
            const TextSpan(text: ' dBm', style: TextStyle(
                color: AppColors.textSecondary, fontSize: 9)),
          ])),
        ]),
      ),
    );
  }
}
