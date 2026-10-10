import 'package:asuka/asuka.dart';
import 'package:clash_for_flutter/app/bean/profile_base_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_file_bean.dart';
import 'package:clash_for_flutter/app/bean/profile_url_bean.dart';
import 'package:clash_for_flutter/app/component/loading_component.dart';
import 'package:clash_for_flutter/app/component/sys_app_bar.dart';
import 'package:clash_for_flutter/app/pages/profiles/profile_item.dart';
import 'package:clash_for_flutter/app/pages/profiles/profiles_controller.dart';
import 'package:clash_for_flutter/app/source/app_config.dart';
import 'package:clash_for_flutter/app/utils/app_json.dart';
import 'package:clash_for_flutter/app/source/desktop_dialogs.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_modular/flutter_modular.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:path/path.dart' hide context;

/// 配置文件页
class ProfilesPage extends StatefulWidget {
  const ProfilesPage({super.key});

  @override
  State<ProfilesPage> createState() => _ProfilesPageState();
}

class _ProfilesPageState extends State<ProfilesPage> {
  final _config = Modular.get<AppConfig>();
  final ProfileController _controller = Modular.get<ProfileController>();
  final ScrollController _scrollController = ScrollController();
  final List<String> _loadingList = [];
  bool _showFab = true;

  @override
  initState() {
    super.initState();
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

  showAddProfiles() {
    Asuka.showModalBottomSheet(
      backgroundColor: Colors.transparent,
      builder: (cxt) => Material(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(16),
          topRight: Radius.circular(16),
        ),
        elevation: 7,
        child: SizedBox(
          height: 100,
          child: ListView(
            children: [
              ListTile(
                title: const Text("文件"),
                onTap: () {
                  Navigator.of(cxt).pop();
                  dialogPickerFile(
                    label: "文件",
                    onOk: (v) {
                      var profile = ProfileFile.emptyBean()
                        ..path = v
                        ..name = basename(v);
                      addProfile(profile);
                    },
                  );
                },
              ),
              ListTile(
                title: const Text("URL"),
                onTap: () {
                  Navigator.of(cxt).pop();
                  dialogInputValue(
                    label: "URL",
                    onOk: (v) {
                      addProfile(ProfileURL.emptyBean()..url = v);
                    },
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  addProfile(ProfileBase profile) {
    var loading = Loading.builder();
    Asuka.addOverlay(loading);
    _controller.addProfile(profile).then((_) => loading.remove()).catchError((
      e,
    ) {
      loading.remove();
      Asuka.showSnackBar(SnackBar(content: Text("导入异常: $e")));
    });
  }

  Future<void> dialogPickerFile({
    required String label,
    required void Function(String) onOk,
    String? initialValue,
  }) async {
    try {
      final path = await DesktopDialogs.pickProfileFile();
      if (path != null && path.isNotEmpty && mounted) onOk(path);
    } catch (_) {
      Asuka.showSnackBar(const SnackBar(content: Text('无法打开系统文件选择器')));
    }
  }

  dialogInputValue({
    required String label,
    required void Function(String) onOk,
    String? initialValue,
  }) {
    showDialog(
      context: context,
      builder: (cxt) {
        var textController = TextEditingController(text: initialValue);
        return AlertDialog(
          title: Text(label),
          content: TextField(
            decoration: InputDecoration(labelText: label),
            controller: textController,
          ),
          actions: [
            TextButton(
              child: const Text("取消"),
              onPressed: () => Navigator.of(cxt).pop(),
            ),
            TextButton(
              child: const Text("确认"),
              onPressed: () {
                if (textController.text.isEmpty) return;
                Navigator.of(cxt).pop();
                onOk(textController.text);
              },
            ),
          ],
        );
      },
    );
  }

  edit(ProfileBase profile) {
    if (profile is ProfileFile) {
      dialogPickerFile(
        label: "文件",
        initialValue: profile.path,
        onOk: (v) => _controller.replaceFile(profile, v),
      );
    } else if (profile is ProfileURL) {
      dialogInputValue(
        label: "URL",
        initialValue: profile.url,
        onOk: (v) =>
            _controller.edit(AppJson.cloneProfileUrl(profile)..url = v.trim()),
      );
    }
  }

  changeName(ProfileBase profile) {
    dialogInputValue(
      label: "名称",
      initialValue: profile.name,
      onOk: (v) => _controller.edit(profile..name = v),
    );
  }

  upgradeProfile(String file) {
    setState(() => _loadingList.add(file));
    _controller
        .updateProfile(file)
        .catchError((err) {
          Asuka.showSnackBar(SnackBar(content: Text(err.message ?? "未知异常")));
        })
        .then((value) => setState(() => _loadingList.remove(file)));
  }

  removeProfile(String file) {
    Asuka.showSnackBar(
      SnackBar(
        content: const Text("确定移除？"),
        action: SnackBarAction(
          label: "确定",
          onPressed: () => _controller.removeProfile(file),
        ),
      ),
    );
  }

  Widget _buildPanel(int index) {
    var profile = _config.profiles[index];
    var show = ProfileShow(
      title: profile.name,
      type: profile.type,
      lastUpdate: profile.time,
    );
    if (profile is ProfileURL) {
      var userinfo = profile.userinfo;
      if (userinfo != null) {
        show
          ..expire = userinfo.expire == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch((userinfo.expire!) * 1000)
          ..use = (userinfo.upload ?? 0) + (userinfo.download ?? 0)
          ..total = userinfo.total ?? 0;
      }
    }
    return Observer(
      builder: (_) => SelectableCard(
        profile: show,
        selected: profile.file == _config.selectedFile,
        isLoading: _loadingList.contains(profile.file),
        onTap: () => _controller.select(profile.file),
        onUpdate: () => upgradeProfile(profile.file),
        onEdit: () => edit(profile),
        onRemove: () => removeProfile(profile.file),
        onChangeName: () => changeName(profile),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const SysAppBar(title: Text('订阅')),
      body: LayoutBuilder(
        builder: (BuildContext context, BoxConstraints constraints) {
          final crossAxisCount = constraints.maxWidth < 720 ? 1 : 2;

          return Observer(
            builder: (_) => _config.profiles.isEmpty
                ? const _EmptyProfiles()
                : MasonryGridView.count(
                    controller: _scrollController,
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 88),
                    itemCount: _config.profiles.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _buildPanel(index);
                    },
                  ),
          );
        },
      ),
      floatingActionButton: _showFab
          ? FloatingActionButton.extended(
              tooltip: "新增",
              onPressed: showAddProfiles,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加订阅'),
            )
          : null,
    );
  }
}

class _EmptyProfiles extends StatelessWidget {
  const _EmptyProfiles();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.layers_outlined, size: 52, color: scheme.outline),
            const SizedBox(height: 16),
            Text('还没有订阅', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text(
              '点击右下角，从 URL 或本地配置文件添加。',
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
