import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fythaniya/core/theme/app_theme.dart';
import 'package:fythaniya/core/constants/constants.dart';
import 'package:fythaniya/data/models/models.dart';
import 'package:fythaniya/presentation/blocs/blocs.dart';
import 'package:fythaniya/presentation/widgets/common/widgets.dart';
import 'package:intl/intl.dart' as intl;

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});
  @override State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<NotifBloc>().add(NotifLoadEvent());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.bg,
    appBar: AppBar(
      title: const Text(S.notifTitle),
      leading: Navigator.of(context).canPop()
          ? IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => Navigator.pop(context))
          : null,
      actions: [
        BlocBuilder<NotifBloc, NotifState>(builder: (ctx, state) {
          if (state is NotifLoaded && state.unread > 0) {
            return TextButton(
              onPressed: () => ctx.read<NotifBloc>().add(NotifMarkAllEvent()),
              child: Text(S.markAllRead, style: TS.cap.copyWith(color: Colors.white, fontWeight: FontWeight.w600)),
            );
          }
          return const SizedBox.shrink();
        }),
      ],
    ),
    body: BlocBuilder<NotifBloc, NotifState>(builder: (ctx, state) {
      if (state is NotifLoading) return _NotifShimmer();
      if (state is NotifError) return AppErrorWidget(message: state.msg, onRetry: () => ctx.read<NotifBloc>().add(NotifLoadEvent()));
      if (state is NotifLoaded) {
        if (state.items.isEmpty) return EmptyState(icon: Icons.notifications_off_outlined, title: S.noNotif, subtitle: 'لا توجد إشعارات حتى الآن');
        return RefreshIndicator(
          color: AppColors.primary,
          onRefresh: () async => ctx.read<NotifBloc>().add(NotifLoadEvent()),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(D.md, D.md, D.md, D.xxl),
            itemCount: state.items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _NotifTile(notif: state.items[i]),
          ),
        );
      }
      return const SizedBox.shrink();
    }),
  );
}

class _NotifTile extends StatelessWidget {
  final NotificationModel notif;
  const _NotifTile({required this.notif});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = _priorityStyle(notif.priority);
    final dt = _formatTime(notif.createdAt);

    return AppCard(
      color: notif.isRead ? AppColors.surface : AppColors.infoBg.withOpacity(0.5),
      padding: const EdgeInsets.all(D.md),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(width: 42, height: 42,
          decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
          child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(notif.title, style: TS.bodyM.copyWith(fontWeight: notif.isRead ? FontWeight.w500 : FontWeight.w700))),
            if (!notif.isRead)
              Container(width: 8, height: 8, decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle)),
          ]),
          const SizedBox(height: 4),
          Text(notif.body, style: TS.cap.copyWith(color: AppColors.textSec), maxLines: 2, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 6),
          Row(children: [
            _PriorityBadge(priority: notif.priority),
            const Spacer(),
            Text(dt, style: TS.cap.copyWith(color: AppColors.textMuted, fontSize: 11)),
          ]),
        ])),
      ]),
    );
  }

  (IconData, Color) _priorityStyle(String p) {
    switch (p) {
      case 'CRITICAL': return (Icons.error_rounded, AppColors.error);
      case 'HIGH': return (Icons.warning_amber_rounded, AppColors.warning);
      case 'MEDIUM': return (Icons.notifications_rounded, AppColors.info);
      default: return (Icons.info_outline_rounded, AppColors.textMuted);
    }
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inMinutes < 1) return 'الآن';
    if (diff.inMinutes < 60) return 'منذ ${diff.inMinutes} دقيقة';
    if (diff.inHours < 24) return 'منذ ${diff.inHours} ساعة';
    if (diff.inDays < 7) return 'منذ ${diff.inDays} يوم';
    return intl.DateFormat('dd/MM/yyyy').format(dt);
  }
}

class _PriorityBadge extends StatelessWidget {
  final String priority;
  const _PriorityBadge({required this.priority});

  @override
  Widget build(BuildContext context) {
    Color bg, fg; String label;
    switch (priority) {
      case 'CRITICAL': bg = AppColors.errorBg; fg = AppColors.error; label = 'عاجل'; break;
      case 'HIGH': bg = AppColors.warningBg; fg = AppColors.warning; label = 'مهم'; break;
      case 'MEDIUM': bg = AppColors.infoBg; fg = AppColors.info; label = 'معلومة'; break;
      default: bg = AppColors.surfaceAlt; fg = AppColors.textMuted; label = 'عادي';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(10)),
      child: Text(label, style: TS.cap.copyWith(color: fg, fontSize: 10, fontWeight: FontWeight.w600)),
    );
  }
}

class _NotifShimmer extends StatelessWidget {
  @override
  Widget build(BuildContext context) => ListView.separated(
    padding: const EdgeInsets.all(D.md),
    itemCount: 6,
    separatorBuilder: (_, __) => const SizedBox(height: 8),
    itemBuilder: (_, __) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Shimmer(width: 42, height: 42, radius: 21),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Shimmer(width: 200, height: 14, radius: 4), const SizedBox(height: 6),
        Shimmer(width: double.infinity, height: 12, radius: 4), const SizedBox(height: 4),
        Shimmer(width: 160, height: 12, radius: 4),
      ])),
    ]),
  );
}
