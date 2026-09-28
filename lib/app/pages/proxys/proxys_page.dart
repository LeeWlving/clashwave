import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/component/loading_component.dart';
import 'package:clash_for_flutter/app/component/sys_app_bar.dart';
import 'package:clash_for_flutter/app/enum/type_enum.dart';
import 'package:clash_for_flutter/app/pages/proxys/proxys_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';

enum MenuType { Sort }

/// 代理配置页
class ProxysPage extends StatefulWidget {
  const ProxysPage({super.key});

  @override
  State<ProxysPage> createState() => _ProxysPageState();
}

class _ProxysPageState extends State<ProxysPage> {
  final ScrollController _scrollController = ScrollController();
  final ProxysController _controller = Modular.get<ProxysController>();
  bool _showFab = true;

  @override
  void initState() {
    super.initState();
    _controller.initState();
    _scrollController.addListener(_scrollListener);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollListener() {
    if (_scrollController.position.userScrollDirection ==
            ScrollDirection.reverse &&
        _showFab) {
      setState(() => _showFab = false);
    }
    if (_scrollController.position.userScrollDirection ==
            ScrollDirection.forward &&
        !_showFab) {
      setState(() => _showFab = true);
    }
  }

  void testDelay(TabController tabController) async {
    var overlay = Loading.builder();
    Asuka.addOverlay(overlay);
    await _controller.delayGroup(_controller.model.groups[tabController.index]);
    overlay.remove();
  }

  moreMenu(MenuType type) {
    switch (type) {
      // 排序
      case MenuType.Sort:
        sortAction();
        break;
    }
  }

  sortAction() {
    change(sortType, BuildContext context) {
      _controller.sort(sortType);
      Navigator.of(context).pop();
    }

    Asuka.showModalBottomSheet(
      backgroundColor: Colors.transparent,
      builder: (cxt) => Material(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        elevation: 7,
        child: SizedBox(
          height: SortType.values.length * 50,
          child: ListView.builder(
            itemCount: SortType.values.length,
            itemBuilder: (_, i) {
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                onTap: () => change(SortType.values[i], cxt),
                title: Text(SortType.values[i].showName),
                trailing: Radio<SortType>(
                  value: SortType.values[i],
                  groupValue: _controller.model.sortType,
                  onChanged: (v) => change(v, cxt),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Observer(
      builder: (c) {
        var groups = _controller.model.groups;
        return DefaultTabController(
          length: groups.length,
          child: Scaffold(
            appBar: SysAppBar(
              title: groups.isNotEmpty
                  ? TabBar(
                      labelColor: Theme.of(context).textTheme.titleLarge?.color,
                      tabs: groups.map((e) => Tab(text: e.name)).toList(),
                      isScrollable: true,
                    )
                  : const Text("代理"),
              actions: [
                IconButton(
                  tooltip: "排序",
                  icon: const Icon(Icons.sort_outlined),
                  onPressed: sortAction,
                ),
              ],
            ),
            body: groups.isNotEmpty
                ? TabBarView(
                    children: groups.map((group) {
                      var groupName = group.name;
                      var groupNow = group.now;
                      var list = _controller.getShowList(group);
                      return ListView.separated(
                        controller: _scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 10, 12, 88),
                        itemBuilder: (_, i) {
                          var show = list[i];
                          var name = show.name;
                          final selected = groupNow == name;
                          final delay = show.delay < 0
                              ? null
                              : Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.surfaceContainerHigh,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    show.delay == 0
                                        ? '测试中'
                                        : '${show.delay} ms',
                                    style: Theme.of(
                                      context,
                                    ).textTheme.labelSmall,
                                  ),
                                );
                          return ListTile(
                            visualDensity: const VisualDensity(
                              vertical: VisualDensity.minimumDensity,
                            ),
                            minTileHeight: 56,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            selectedTileColor: Theme.of(
                              context,
                            ).colorScheme.primaryContainer,
                            selected: selected,
                            leading: selected
                                ? Icon(
                                    Icons.check_circle_rounded,
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.primary,
                                  )
                                : const Icon(Icons.circle_outlined, size: 18),
                            title: Text(
                              name,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w500,
                                  ),
                            ),
                            subtitle: Text(
                              show.subTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: delay,
                            onTap: () => _controller.select(
                              name: groupName,
                              select: name,
                            ),
                          );
                        },
                        separatorBuilder: (_, _) => const SizedBox(height: 4),
                        itemCount: list.length,
                      );
                    }).toList(),
                  )
                : const _EmptyProxies(),
            floatingActionButton: _showFab
                ? Builder(
                    builder: (cxt) {
                      var tabController = DefaultTabController.of(cxt);
                      return FloatingActionButton(
                        tooltip: "测延迟",
                        onPressed: () {
                          if (groups.isNotEmpty) {
                            testDelay(tabController);
                          }
                        },
                        child: const Icon(Icons.flash_on),
                      );
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

class _EmptyProxies extends StatelessWidget {
  const _EmptyProxies();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.cloud_off_outlined, size: 48, color: scheme.outline),
          const SizedBox(height: 14),
          Text('暂无可选节点', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          Text(
            '请先添加并选择一个有效订阅',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}
