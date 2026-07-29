import 'package:flutter/material.dart';
import 'package:qinglong_flutter/data/api/qinglong_api.dart';
import 'package:qinglong_flutter/data/models/models.dart';
import 'package:qinglong_flutter/theme/app_visuals.dart';
import 'package:qinglong_flutter/ui/components/shared_components.dart';

class NotifySettingsScreen extends StatefulWidget {
  const NotifySettingsScreen({super.key});

  @override
  State<NotifySettingsScreen> createState() => _NotifySettingsScreenState();
}

class _NotifySettingsScreenState extends State<NotifySettingsScreen> {
  final _api = QingLongApi.auth();
  final _controllers = <String, TextEditingController>{};
  final _draft = <String, String>{};
  NotificationConfig? _config;
  bool _loading = true;
  bool _saving = false;
  bool _showSecrets = false;
  String _type = 'closed';
  String? _error;
  String? _status;

  static const _modes = <_Mode>[
    _Mode('gotify', 'Gotify', Icons.notifications_active_outlined),
    _Mode('ntfy', 'Ntfy', Icons.campaign_outlined),
    _Mode('goCqHttpBot', 'GoCqHttpBot', Icons.chat_outlined),
    _Mode('serverChan', 'Server 酱', Icons.send_outlined),
    _Mode('pushDeer', 'PushDeer', Icons.pets_outlined),
    _Mode('bark', 'Bark', Icons.volume_up_outlined),
    _Mode('telegramBot', 'Telegram 机器人', Icons.send_to_mobile_outlined),
    _Mode('dingtalkBot', '钉钉机器人', Icons.work_outline),
    _Mode('weWorkBot', '企业微信机器人', Icons.business_outlined),
    _Mode('weWorkApp', '企业微信应用', Icons.apartment_outlined),
    _Mode('aibotk', '智能微秘书', Icons.smart_toy_outlined),
    _Mode('iGot', 'IGot', Icons.alternate_email),
    _Mode('pushPlus', 'PushPlus', Icons.add_alert_outlined),
    _Mode('wePlusBot', '微加机器人', Icons.support_agent_outlined),
    _Mode('wxPusherBot', 'wxPusher', Icons.message_outlined),
    _Mode('wxPusherSpt', 'WxPusher SPT', Icons.qr_code_2_outlined),
    _Mode('openiLink', 'OpeniLink', Icons.hub_outlined),
    _Mode('chat', '群晖 Chat', Icons.forum_outlined),
    _Mode('email', '邮箱', Icons.mail_outline),
    _Mode('lark', '飞书机器人', Icons.flutter_dash),
    _Mode('pushMe', 'PushMe', Icons.mobile_friendly_outlined),
    _Mode('chronocat', 'Chronocat', Icons.link_outlined),
    _Mode('webhook', '自定义通知', Icons.link),
    _Mode('closed', '已关闭', Icons.notifications_off_outlined),
  ];

  static const _fields = <String, List<_Field>>{
    'gotify': [
      _Field(
        'gotifyUrl',
        '服务地址',
        '例如 https://push.example.de:8080',
        required: true,
      ),
      _Field(
        'gotifyToken',
        '应用 Token',
        '填写 Gotify 应用 token',
        required: true,
        secret: true,
      ),
      _Field('gotifyPriority', '消息优先级', '可选'),
    ],
    'ntfy': [
      _Field('ntfyUrl', '服务地址', '例如 https://ntfy.sh', required: true),
      _Field('ntfyTopic', 'Topic', '填写 ntfy topic', required: true),
      _Field('ntfyPriority', '消息优先级', '可选'),
      _Field('ntfyToken', '访问 Token', '可选', secret: true),
      _Field('ntfyUsername', '用户名', '可选'),
      _Field('ntfyPassword', '密码', '可选', secret: true),
      _Field('ntfyActions', '用户动作', '可选'),
    ],
    'goCqHttpBot': [
      _Field(
        'goCqHttpBotUrl',
        '接口地址',
        '例如 http://127.0.0.1/send_private_msg',
        required: true,
      ),
      _Field('goCqHttpBotToken', '访问密钥', '可选', secret: true),
      _Field('goCqHttpBotQq', 'QQ 参数', '例如 user_id=123456', required: true),
    ],
    'serverChan': [
      _Field(
        'serverChanKey',
        'SendKey',
        '填写 Server 酱 SendKey',
        required: true,
        secret: true,
      ),
    ],
    'pushDeer': [
      _Field(
        'pushDeerKey',
        'Key',
        '填写 PushDeer Key',
        required: true,
        secret: true,
      ),
      _Field('pushDeerUrl', 'API 地址', '可选，默认官方接口'),
    ],
    'bark': [
      _Field(
        'barkPush',
        '设备地址',
        '例如 https://api.day.app/XXXXXXXX',
        required: true,
      ),
      _Field('barkIcon', '推送图标', '可选'),
      _Field('barkSound', '推送铃声', '可选'),
      _Field('barkGroup', '消息分组', '可选，默认 qinglong'),
      _Field('barkLevel', '消息时效性', '可选，默认 active'),
      _Field('barkUrl', '跳转地址', '可选'),
      _Field('barkArchive', '保存消息', '可选'),
    ],
    'telegramBot': [
      _Field(
        'telegramBotToken',
        '机器人 Token',
        '例如 123456:ABC...',
        required: true,
        secret: true,
      ),
      _Field('telegramBotUserId', '用户 ID', '例如 129000206', required: true),
      _Field('telegramBotProxyHost', '代理地址', '可选'),
      _Field('telegramBotProxyPort', '代理端口', '可选'),
      _Field(
        'telegramBotProxyAuth',
        '代理认证',
        '可选，格式 user:password',
        secret: true,
      ),
      _Field('telegramBotApiHost', 'API 地址', '可选'),
    ],
    'dingtalkBot': [
      _Field(
        'dingtalkBotToken',
        '机器人 Token',
        '填写 webhook token',
        required: true,
        secret: true,
      ),
      _Field('dingtalkBotSecret', '加签密钥', '可选', secret: true),
    ],
    'weWorkBot': [
      _Field(
        'weWorkBotKey',
        'Webhook Key',
        '填写企业微信机器人 key',
        required: true,
        secret: true,
      ),
      _Field('weWorkOrigin', '代理地址', '可选'),
    ],
    'weWorkApp': [
      _Field(
        'weWorkAppKey',
        '应用参数',
        '按后端要求用英文逗号分隔',
        required: true,
        secret: true,
      ),
      _Field('weWorkOrigin', '代理地址', '可选'),
    ],
    'aibotk': [
      _Field(
        'aibotkKey',
        'API Key',
        '填写 API Key',
        required: true,
        secret: true,
      ),
      _Field(
        'aibotkType',
        '发送目标',
        '选择目标',
        required: true,
        options: {'room': '群聊', 'contact': '好友'},
      ),
      _Field('aibotkName', '目标名称', '填写群名或好友昵称', required: true),
    ],
    'iGot': [
      _Field(
        'iGotPushKey',
        '推送地址',
        '例如 https://push.hellyw.com/XXXXXXXX',
        required: true,
        secret: true,
      ),
    ],
    'pushPlus': [
      _Field(
        'pushPlusToken',
        'Token',
        '填写 PushPlus Token',
        required: true,
        secret: true,
      ),
      _Field('pushPlusUser', '群组编码', '可选'),
      _Field('pushplusTemplate', '发送模板', '可选'),
      _Field('pushplusChannel', '发送渠道', '可选'),
      _Field('pushplusWebhook', 'Webhook 编码', '可选'),
      _Field('pushplusCallbackUrl', '回调地址', '可选'),
      _Field('pushplusTo', '好友令牌', '可选', secret: true),
    ],
    'wePlusBot': [
      _Field(
        'wePlusBotToken',
        '用户令牌',
        '填写微加机器人令牌',
        required: true,
        secret: true,
      ),
      _Field('wePlusBotReceiver', '消息接收人', '可选'),
      _Field('wePlusBotVersion', '调用版本', '可选，例如 pro 或 personal'),
    ],
    'wxPusherBot': [
      _Field(
        'wxPusherBotAppToken',
        'App Token',
        '填写 wxPusher AppToken',
        required: true,
        secret: true,
      ),
      _Field('wxPusherBotTopicIds', 'Topic IDs', '可选'),
      _Field('wxPusherBotUids', 'UIDs', '可选'),
    ],
    'wxPusherSpt': [
      _Field(
        'wxPusherSptList',
        'SPT',
        '填写 WxPusher SPT',
        required: true,
        secret: true,
      ),
    ],
    'openiLink': [
      _Field(
        'openiLinkAppToken',
        'App Token',
        '填写 OpeniLink App Token',
        required: true,
        secret: true,
      ),
      _Field('openiLinkHubUrl', 'Hub 地址', '可选'),
      _Field('openiLinkContextToken', 'Context Token', '可选', secret: true),
    ],
    'chat': [_Field('synologyChatUrl', '接口地址', '填写群晖 Chat 地址', required: true)],
    'email': [
      _Field('emailService', '邮件服务', '例如 126、163、Gmail、QQ', required: true),
      _Field('emailUser', '邮箱账号', '填写认证邮箱', required: true),
      _Field('emailPass', '邮箱密码', '服务商提供的特殊口令', required: true, secret: true),
      _Field('emailTo', '收件人', '多个地址使用分号分隔'),
    ],
    'lark': [
      _Field('larkKey', '机器人 Key', '填写飞书机器人 key', required: true, secret: true),
      _Field('larkSecret', '签名密钥', '可选', secret: true),
    ],
    'pushMe': [
      _Field('pushMeKey', 'Key', '填写 PushMe Key', required: true, secret: true),
      _Field('pushMeUrl', '服务地址', '可选'),
    ],
    'chronocat': [
      _Field('chronocatURL', '服务地址', '填写 Chronocat Red 地址', required: true),
      _Field(
        'chronocatQQ',
        'QQ 参数',
        '例如 user_id=xxx;group_id=xxxx',
        required: true,
      ),
      _Field(
        'chronocatToken',
        '访问 Token',
        '填写服务 token',
        required: true,
        secret: true,
      ),
    ],
    'webhook': [
      _Field(
        'webhookMethod',
        '请求方法',
        '选择请求方法',
        required: true,
        options: {'GET': 'GET', 'POST': 'POST', 'PUT': 'PUT'},
      ),
      _Field(
        'webhookContentType',
        'Content-Type',
        '选择请求头类型',
        required: true,
        options: {
          'text/plain': 'text/plain',
          'application/json': 'application/json',
          'multipart/form-data': 'multipart/form-data',
          'application/x-www-form-urlencoded':
              'application/x-www-form-urlencoded',
        },
      ),
      _Field('webhookUrl', '请求地址', r'必须包含 $title，可选 $content', required: true),
      _Field('webhookHeaders', '请求头', '每行一个 Header: value', multiline: true),
      _Field('webhookBody', '请求体', '每行一个 key: value', multiline: true),
    ],
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    if (mounted) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final response = await _api.getNotificationConfig();
      if (!mounted) return;
      if (response.code != 200 || response.data == null) {
        throw StateError(response.message ?? '读取通知配置失败');
      }
      _config = response.data;
      _draft
        ..clear()
        ..addAll(
          response.data!.values.map(
            (key, value) => MapEntry(key, value.toString()),
          ),
        );
      _type = _knownType(response.data!.type) ? response.data!.type : 'closed';
      _syncControllers();
      setState(() => _loading = false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = _errorText(error);
      });
    }
  }

  Future<void> _save() async {
    _collect();
    final values = <String, dynamic>{};
    for (final field in _fieldsFor(_type)) {
      final value = (_draft[field.key] ?? '').trim();
      if (field.required && value.isEmpty) {
        setState(() => _status = '请填写“${field.label}”');
        return;
      }
      if (value.isNotEmpty) values[field.key] = value;
    }
    setState(() {
      _saving = true;
      _status = null;
    });
    try {
      final response = await _api.updateNotificationConfig(
        NotificationConfig(
          type: _type == 'closed' ? '' : _type,
          values: values,
        ),
      );
      if (!mounted) return;
      if (response.code != 200) {
        throw StateError(response.message ?? '通知测试失败，请检查配置');
      }
      _config = NotificationConfig(type: _type, values: values);
      setState(() => _status = _type == 'closed' ? '通知已关闭' : '测试通知发送成功，配置已保存');
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_status!)));
    } catch (error) {
      if (!mounted) return;
      setState(() => _status = _errorText(error));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_status!)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _changeType(String? value) {
    if (value == null || value == _type) return;
    _collect();
    setState(() {
      _type = value;
      _status = null;
      _syncControllers();
    });
  }

  void _syncControllers() {
    for (final field in _fieldsFor(_type)) {
      final controller = _controllers.putIfAbsent(
        field.key,
        TextEditingController.new,
      );
      var value = _draft[field.key] ?? _config?.value(field.key) ?? '';
      if (field.options != null && !field.options!.containsKey(value)) {
        value = field.options!.keys.first;
        _draft[field.key] = value;
      }
      controller.text = value;
      controller.selection = TextSelection.collapsed(
        offset: controller.text.length,
      );
    }
  }

  void _collect() {
    for (final field in _fieldsFor(_type)) {
      _draft[field.key] = _controllers[field.key]?.text ?? '';
    }
  }

  List<_Field> _fieldsFor(String type) => _fields[type] ?? const [];
  bool _knownType(String type) => _modes.any((mode) => mode.value == type);
  _Mode get _selectedMode => _modes.firstWhere(
    (mode) => mode.value == _type,
    orElse: () => _modes.last,
  );
  String _errorText(Object error) {
    final text = error.toString();
    return text.startsWith('Bad state: ') ? text.substring(11) : text;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        _header(cs),
        Expanded(child: RepaintBoundary(child: _body(cs))),
        _footer(cs),
      ],
    );
  }

  Widget _header(ColorScheme cs) {
    return Column(
      children: [
        const QlSheetHandle(),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 2, 16, 12),
          child: Row(
            children: [
              _headerAction(
                cs: cs,
                icon: Icons.close,
                tooltip: '关闭',
                onPressed: _saving ? null : () => Navigator.pop(context),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通知管理',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      _selectedMode.label,
                      style: TextStyle(
                        color: AppVisuals.palette(context).textMuted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              _headerAction(
                cs: cs,
                icon: _showSecrets
                    ? Icons.visibility_off_outlined
                    : Icons.visibility_outlined,
                tooltip: _showSecrets ? '隐藏密钥' : '显示密钥',
                onPressed: _loading || _saving
                    ? null
                    : () => setState(() => _showSecrets = !_showSecrets),
              ),
              const SizedBox(width: 8),
              _headerAction(
                cs: cs,
                icon: Icons.refresh,
                tooltip: '刷新',
                onPressed: _loading || _saving ? null : _load,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _headerAction({
    required ColorScheme cs,
    required IconData icon,
    required String tooltip,
    required VoidCallback? onPressed,
  }) {
    final enabled = onPressed != null;
    final actionColor = cs.primary.withValues(alpha: enabled ? 0.07 : 0.04);
    final borderColor = cs.primary.withValues(alpha: enabled ? 0.24 : 0.14);
    return Tooltip(
      message: tooltip,
      child: Material(
        color: actionColor,
        shape: CircleBorder(side: BorderSide(color: borderColor, width: 0.8)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(
              icon,
              size: 22,
              color: cs.primary.withValues(alpha: enabled ? 1 : 0.42),
            ),
          ),
        ),
      ),
    );
  }

  Widget _body(ColorScheme cs) {
    if (_loading) return const Center(child: LoadingIndicator());
    if (_error != null) {
      return QlErrorState(title: '通知设置加载失败', message: _error!, onRetry: _load);
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      children: [
        _modePicker(cs),
        const SizedBox(height: 16),
        if (_type == 'closed')
          _closedState(cs)
        else ...[
          _info(cs),
          const SizedBox(height: 12),
          ..._fieldsFor(_type).map((field) => _field(cs, field)),
        ],
      ],
    );
  }

  Widget _modePicker(ColorScheme cs) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: _saving ? null : _showModePicker,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: cs.primary.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
          ),
          child: Row(
            children: [
              Icon(_selectedMode.icon, color: cs.primary, size: 21),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '通知方式',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _selectedMode.label,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.keyboard_arrow_down_rounded,
                color: cs.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showModePicker() async {
    final selected = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return FractionallySizedBox(
          heightFactor: 0.82,
          child: AppVisuals.glassSurface(
            context: ctx,
            blur: 8,
            withShadow: false,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            child: SafeArea(
              top: false,
              child: Column(
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 12, bottom: 8),
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: cs.onSurface.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                    child: Row(
                      children: [
                        Icon(_selectedMode.icon, color: cs.primary, size: 22),
                        const SizedBox(width: 10),
                        Text(
                          '选择通知方式',
                          style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 16),
                      itemCount: _modes.length,
                      itemBuilder: (context, index) =>
                          _modeOption(context, _modes[index]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    if (!mounted || selected == null) return;
    _changeType(selected);
  }

  Widget _modeOption(BuildContext ctx, _Mode mode) {
    final cs = Theme.of(ctx).colorScheme;
    final isSelected = mode.value == _type;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Material(
        color: cs.primary.withValues(alpha: 0.07),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: cs.primary.withValues(alpha: 0.24)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(ctx).pop(mode.value),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(mode.icon, size: 16, color: cs.primary),
                ),
                const SizedBox(width: 12),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: cs.primary,
                  ),
                ),
                const Spacer(),
                Icon(
                  isSelected ? Icons.check : Icons.arrow_forward_ios,
                  size: isSelected ? 18 : 14,
                  color: cs.primary.withValues(alpha: 0.6),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _info(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: cs.secondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.secondary.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 19, color: cs.secondary),
          const SizedBox(width: 9),
          Expanded(
            child: Text(
              '保存时后端会发送一条测试通知，测试成功后才会保存配置。',
              style: TextStyle(
                color: cs.onSurfaceVariant,
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _closedState(ColorScheme cs) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: Column(
        children: [
          Icon(Icons.notifications_off_outlined, size: 38, color: cs.primary),
          const SizedBox(height: 10),
          const Text(
            '通知已关闭',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          ),
          const SizedBox(height: 5),
          Text(
            '选择一种通知方式并填写配置后即可启用。',
            style: TextStyle(color: cs.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _field(ColorScheme cs, _Field field) {
    final controller = _controllers.putIfAbsent(
      field.key,
      TextEditingController.new,
    );
    if (field.options != null) {
      final current = controller.text;
      return Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
        decoration: BoxDecoration(
          color: cs.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
        ),
        child: DropdownButtonFormField<String>(
          value: current,
          decoration: InputDecoration(
            labelText: field.label + (field.required ? ' *' : ''),
            prefixIcon: Icon(Icons.tune_outlined, size: 20, color: cs.primary),
            border: InputBorder.none,
            isDense: true,
          ),
          items: field.options!.entries
              .map(
                (item) =>
                    DropdownMenuItem(value: item.key, child: Text(item.value)),
              )
              .toList(),
          onChanged: _saving
              ? null
              : (value) => controller.text = value ?? current,
        ),
      );
    }
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: cs.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.primary.withValues(alpha: 0.24)),
      ),
      child: TextField(
        controller: controller,
        enabled: !_saving,
        obscureText: field.secret && !_showSecrets,
        maxLines: field.multiline ? 4 : 1,
        minLines: field.multiline ? 2 : 1,
        decoration: InputDecoration(
          labelText: field.label + (field.required ? ' *' : ''),
          hintText: field.hint,
          prefixIcon: Icon(
            field.secret ? Icons.key_outlined : Icons.tune_outlined,
            size: 20,
            color: cs.primary,
          ),
          floatingLabelStyle: TextStyle(color: cs.primary),
          border: InputBorder.none,
          isDense: true,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 14,
          ),
        ),
        style: const TextStyle(fontSize: 14),
      ),
    );
  }

  Widget _footer(ColorScheme cs) {
    final success =
        _status != null && (_status!.contains('成功') || _status!.contains('关闭'));
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: [
            if (_status != null)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _status!,
                    style: TextStyle(
                      color: success ? cs.primary : cs.error,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: FilledButton.icon(
                onPressed: _loading || _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 19,
                        height: 19,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save_outlined),
                label: Text(_saving ? '测试并保存中...' : '测试并保存'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Mode {
  final String value;
  final String label;
  final IconData icon;
  const _Mode(this.value, this.label, this.icon);
}

class _Field {
  final String key;
  final String label;
  final String hint;
  final bool required;
  final bool secret;
  final bool multiline;
  final Map<String, String>? options;
  const _Field(
    this.key,
    this.label,
    this.hint, {
    this.required = false,
    this.secret = false,
    this.multiline = false,
    this.options,
  });
}
