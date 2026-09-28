import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/pages/profiles/profiles_controller.dart';
import 'package:clash_for_flutter/app/utils/utils.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;

enum _ProfileAction { rename, edit, remove }

class SelectableCard extends StatelessWidget {
  const SelectableCard({
    super.key,
    required this.profile,
    this.selected = false,
    this.isLoading = false,
    required this.onTap,
    required this.onUpdate,
    required this.onEdit,
    required this.onChangeName,
    required this.onRemove,
  });

  final bool selected;
  final ProfileShow profile;
  final bool isLoading;
  final VoidCallback onTap;
  final VoidCallback onUpdate;
  final VoidCallback onEdit;
  final VoidCallback onChangeName;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final used = profile.use;
    final total = profile.total;
    final hasUsage = used != null && total != null && total > 0;
    final progress = hasUsage ? (used / total).clamp(0.0, 1.0) : null;

    return Semantics(
      button: true,
      selected: selected,
      label: '${profile.title}，${selected ? '当前订阅' : '未选择'}',
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 1.6 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 17, 10, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: selected
                            ? scheme.primaryContainer
                            : scheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        profile.type == ProfileType.URL
                            ? Icons.link_rounded
                            : Icons.description_outlined,
                        color: selected
                            ? scheme.primary
                            : scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  profile.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(
                                    context,
                                  ).textTheme.titleMedium,
                                ),
                              ),
                              if (selected) ...[
                                const SizedBox(width: 8),
                                Icon(
                                  Icons.check_circle_rounded,
                                  size: 19,
                                  color: scheme.primary,
                                  semanticLabel: '当前订阅',
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${profile.type.value} · ${timeago.format(profile.lastUpdate, locale: 'zh_cn')}',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasUsage) ...[
                  const SizedBox(height: 20),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHigh,
                    ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '已用 ${dataformat(used)} / ${dataformat(total)}',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      if (profile.expire != null)
                        Text(
                          '到期 ${DateFormat('yyyy/MM/dd').format(profile.expire!)}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                    ],
                  ),
                ] else if (profile.expire != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    '到期 ${DateFormat('yyyy/MM/dd HH:mm').format(profile.expire!)}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else ...[
                      if (profile.type == ProfileType.URL)
                        IconButton(
                          tooltip: '更新订阅',
                          onPressed: onUpdate,
                          icon: const Icon(Icons.refresh_rounded),
                        ),
                      PopupMenuButton<_ProfileAction>(
                        tooltip: '更多操作',
                        icon: const Icon(Icons.more_horiz_rounded),
                        onSelected: (action) {
                          switch (action) {
                            case _ProfileAction.rename:
                              onChangeName();
                            case _ProfileAction.edit:
                              onEdit();
                            case _ProfileAction.remove:
                              onRemove();
                          }
                        },
                        itemBuilder: (context) => const [
                          PopupMenuItem(
                            value: _ProfileAction.rename,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.edit_note_outlined),
                              title: Text('重命名'),
                            ),
                          ),
                          PopupMenuItem(
                            value: _ProfileAction.edit,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.code_outlined),
                              title: Text('修改来源'),
                            ),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: _ProfileAction.remove,
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(Icons.delete_outline_rounded),
                              title: Text('移除'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
