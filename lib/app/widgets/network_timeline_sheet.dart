import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:wifi_signal_visualizer/app/constant/app_colors.dart';
import 'package:wifi_signal_visualizer/app/services/network_timeline_service.dart';
import 'package:wifi_signal_visualizer/app/utils/signal_utils.dart';


class NetworkTimelineSheet extends StatelessWidget {
  const NetworkTimelineSheet({super.key});

  static void show() => Get.bottomSheet(
    const NetworkTimelineSheet(),
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
  );

  @override
  Widget build(BuildContext context) {
    final svc = Get.find<NetworkTimelineService>();

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.35,
      maxChildSize: 0.90,
      builder: (_, sc) => Container(
        decoration: BoxDecoration(
          color: AppColors.bgSurface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          border: Border(
              top: BorderSide(color: AppColors.bgCardBorder, width: 1.5)),
        ),
        child: Column(children: [
          // handle
          Center(child: Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppColors.bgCardBorder,
                borderRadius: BorderRadius.circular(2)))),
          // header
          Padding(padding: const EdgeInsets.fromLTRB(18, 0, 18, 10),
            child: Row(children: [
              const Icon(Icons.timeline_rounded,
                  color: AppColors.accent, size: 18),
              const SizedBox(width: 8),
              const Expanded(child: Text('Network Timeline',
                  style: TextStyle(color: AppColors.textPrimary, fontSize: 15,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'monospace'))),
              GestureDetector(
                onTap: svc.clear,
                child: const Icon(Icons.delete_sweep_rounded,
                    color: AppColors.textSecondary, size: 18)),
            ])),
          // list
          Expanded(child: Obx(() {
            if (svc.events.isEmpty) {
              return const Center(child: Text('No events yet',
                  style: TextStyle(color: AppColors.textMuted,
                      fontFamily: 'monospace')));
            }
            return ListView.builder(
              controller: sc,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: svc.events.length,
              itemBuilder: (_, i) => _EventTile(event: svc.events[i]),
            );
          })),
        ]),
      ),
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});
  final TimelineEvent event;

  @override
  Widget build(BuildContext context) {
    final (color, bgColor) = _colors();

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.35)),
      ),
      child: Row(children: [
        // Icon badge
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15), shape: BoxShape.circle),
          child: Center(child: Text(event.icon, style: TextStyle(
              color: color, fontSize: 14,
              fontWeight: FontWeight.w900)))),
        const SizedBox(width: 10),
        // Info
        Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(_label(), style: TextStyle(
              color: color, fontSize: 11,
              fontWeight: FontWeight.w700, fontFamily: 'monospace')),
          const SizedBox(height: 2),
          Text(event.ssid.isEmpty ? event.bssid : event.ssid,
              style: const TextStyle(color: AppColors.textPrimary,
                  fontSize: 12, fontWeight: FontWeight.w600,
                  fontFamily: 'monospace'),
              overflow: TextOverflow.ellipsis),
          if (event.frequencyMhz > 0)
            Text(SignalUtils.bandLabel(
                SignalUtils.bandFromMhz(event.frequencyMhz)),
                style: const TextStyle(color: AppColors.textSecondary,
                    fontSize: 9, fontFamily: 'monospace')),
        ])),
        // RSSI + time
        Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text('${event.rssi} dBm',
              style: TextStyle(
                  color: SignalUtils.qualityColor(
                      SignalUtils.qualityFromRssi(event.rssi)),
                  fontSize: 11, fontWeight: FontWeight.w800,
                  fontFamily: 'monospace')),
          const SizedBox(height: 3),
          Text(event.timeLabel, style: const TextStyle(
              color: AppColors.textMuted, fontSize: 9,
              fontFamily: 'monospace')),
        ]),
      ]),
    );
  }

  String _label() => switch (event.type) {
    TimelineEventType.appeared     => 'Network appeared',
    TimelineEventType.disappeared  => 'Network lost',
    TimelineEventType.signalJump   =>
        event.rssiDelta > 0
            ? 'Signal boosted +${event.rssiDelta} dBm'
            : 'Signal dropped ${event.rssiDelta} dBm',
    TimelineEventType.connected    => 'Connected',
    TimelineEventType.disconnected => 'Disconnected',
  };

  (Color, Color) _colors() => switch (event.type) {
    TimelineEventType.appeared     =>
        (AppColors.sigExcellent,  AppColors.sigExcellent.withOpacity(0.06)),
    TimelineEventType.disappeared  =>
        (AppColors.sigUnusable,   AppColors.sigUnusable.withOpacity(0.06)),
    TimelineEventType.signalJump   => event.rssiDelta > 0
        ? (AppColors.sigGood,     AppColors.sigGood.withOpacity(0.06))
        : (AppColors.sigPoor,     AppColors.sigPoor.withOpacity(0.06)),
    TimelineEventType.connected    =>
        (AppColors.selected,      AppColors.selected.withOpacity(0.06)),
    TimelineEventType.disconnected =>
        (AppColors.textSecondary, AppColors.bgCard),
  };
}