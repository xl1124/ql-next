import "dart:math" as math;

import "package:flutter/material.dart";
import "package:qinglong_flutter/ui/components/shared_components.dart";
import "package:qinglong_flutter/data/api/qinglong_api.dart";
import "package:qinglong_flutter/data/models/models.dart";

class DashboardScreen extends StatefulWidget {
  final QingLongApi? api;

  const DashboardScreen({super.key, this.api});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final QingLongApi _api;
  DashboardOverview? _overview;
  DashboardRuntime? _runtime;
  List<dynamic>? _trend, _topTime, _topCount;
  Map<String, dynamic>? _dashSys;
  int _ec = 0, _sc = 0, _dc = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _api = widget.api ?? QingLongApi.auth();
    _load();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final runtimeFuture = _api.getDashboardRuntime().catchError(
        (_) => QingLongResponse<DashboardRuntime>(code: 0),
      );
      var r = await Future.wait([
        _api.getDashboardOverview(),
        _api.getDashboardTrend(),
        _api.getDashboardTopTime(),
        _api.getDashboardTopCount(),
        _api.getDashboardSystem(),
        _api.getEnvironments(),
        _api.getSubscriptions(),
        _api.getDependencies(),
        runtimeFuture,
      ]);
      final overviewResponse = r[0] as QingLongResponse<DashboardOverview>;
      final trendResponse = r[1] as QingLongResponse<List<dynamic>>;
      final topTimeResponse = r[2] as QingLongResponse<List<dynamic>>;
      final topCountResponse = r[3] as QingLongResponse<List<dynamic>>;
      final systemResponse = r[4] as QingLongResponse<Map<String, dynamic>>;
      final environmentResponse = r[5] as QingLongResponse<List<Environment>>;
      final subscriptionResponse =
          r[6] as QingLongResponse<List<SubscriptionInfo>>;
      final dependencyResponse = r[7] as QingLongResponse<List<dynamic>>;
      final runtimeResponse = r[8] as QingLongResponse<DashboardRuntime>;

      _requireDashboardData(overviewResponse, "仪表盘概览加载失败");
      _requireDashboardData(trendResponse, "运行趋势加载失败");
      _requireDashboardData(topTimeResponse, "耗时任务加载失败");
      _requireDashboardData(topCountResponse, "运行任务加载失败");
      _requireDashboardData(systemResponse, "系统信息加载失败");
      _requireDashboardData(environmentResponse, "环境变量统计加载失败");
      _requireDashboardData(subscriptionResponse, "订阅统计加载失败");
      _requireDashboardData(dependencyResponse, "依赖统计加载失败");

      _overview = overviewResponse.data;
      _trend = trendResponse.data;
      _topTime = topTimeResponse.data;
      _topCount = topCountResponse.data;
      _dashSys = systemResponse.data;
      _runtime = runtimeResponse.code == 200 ? runtimeResponse.data : null;
      _ec = environmentResponse.data!.length;
      _sc = subscriptionResponse.data!.length;
      _dc = dependencyResponse.data!.length;
      if (!mounted) return;
      setState(() => _loading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_trSc.hasClients) _trSc.jumpTo(_trSc.position.maxScrollExtent);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _requireDashboardData<T>(QingLongResponse<T> response, String fallback) {
    if (response.code != 200 || response.data == null) {
      throw StateError(response.message ?? fallback);
    }
  }

  @override
  Widget build(BuildContext c) {
    final cs = Theme.of(c).colorScheme;
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(MediaQuery.of(c).padding.top + 60),
        child: QlTopBar(
          title: "仪表盘",
          trailing: [
            QlTopBarActionButton(
              tooltip: "刷新仪表盘",
              onPressed: _loading ? null : _load,
              icon: Icons.refresh,
            ),
          ],
        ),
      ),
      body: _loading
          ? const LoadingIndicator()
          : _error != null
          ? _buildError(cs)
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                children: [
                  _card(cs, "任务概览", Icons.assignment, _ov(cs)),
                  const SizedBox(height: 12),
                  _card(cs, "全局概览", Icons.dashboard, _gl(cs)),
                  const SizedBox(height: 12),
                  _card(
                    cs,
                    "运行状态",
                    Icons.monitor_heart_outlined,
                    _runtimeView(cs),
                  ),
                  const SizedBox(height: 12),
                  _card(cs, "运行趋势", Icons.trending_up, _tr(cs)),
                  const SizedBox(height: 12),
                  _card(cs, "Top 任务", Icons.leaderboard, _tp(cs)),
                  const SizedBox(height: 12),
                  _card(cs, "系统信息", Icons.memory, _sy(cs)),
                ],
              ),
            ),
    );
  }

  Widget _buildError(ColorScheme cs) {
    return QlErrorState(
      title: "仪表盘数据加载失败",
      message: _error ?? "未知错误",
      onRetry: _load,
      hint: "请检查服务器连接后重试",
    );
  }

  Widget _card(ColorScheme c, String t, IconData ic, Widget w) {
    final cardRadius = BorderRadius.circular(16);
    return Material(
      color: c.primary.withValues(alpha: 0.07),
      shape: RoundedRectangleBorder(
        borderRadius: cardRadius,
        side: BorderSide(color: c.primary.withValues(alpha: 0.24)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: c.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(ic, size: 18, color: c.primary),
                ),
                const SizedBox(width: 10),
                Text(
                  t,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          w,
        ],
      ),
    );
  }

  Widget _ov(ColorScheme c) {
    final o = _overview;
    if (o == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sysRow(
            Icons.assignment_outlined,
            "任务总数",
            o.total.toString(),
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.check_circle_outline,
            "已启用",
            o.enabled.toString(),
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.cancel_outlined,
            "已禁用",
            o.disabled.toString(),
            c,
            accent: c.outline,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.play_arrow_outlined,
            "今日运行",
            o.todayRuns.toString(),
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.task_alt,
            "今日成功",
            o.todaySuccess.toString(),
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.error_outline,
            "今日失败",
            o.todayFail.toString(),
            c,
            accent: c.error,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.trending_up,
            "成功率",
            '${o.successRate}%',
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.timer_outlined,
            "平均耗时",
            _fmt(o.avgTime),
            c,
            accent: c.onSurfaceVariant,
          ),
        ],
      ),
    );
  }

  Widget _gl(ColorScheme c) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sysRow(Icons.code_outlined, "环境变量", _ec.toString(), c),
          const SizedBox(height: 8),
          _sysRow(Icons.rss_feed_outlined, "订阅", _sc.toString(), c),
          const SizedBox(height: 8),
          _sysRow(Icons.download_outlined, "依赖", _dc.toString(), c),
        ],
      ),
    );
  }

  Widget _runtimeView(ColorScheme c) {
    final runtime = _runtime;
    if (runtime == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.info_outline, size: 18, color: c.onSurfaceVariant),
            const SizedBox(width: 10),
            Text('运行状态暂不可用', style: TextStyle(color: c.onSurfaceVariant)),
          ],
        ),
      );
    }

    final running = runtime.running.take(5).toList();
    final idle = runtime.idleTasks.take(3).toList();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sysRow(
            Icons.play_circle_outline,
            '运行中',
            runtime.runningCount.toString(),
            c,
            accent: c.primary,
          ),
          const SizedBox(height: 8),
          _sysRow(
            Icons.pending_actions_outlined,
            '排队中',
            runtime.queuedCount.toString(),
            c,
            accent: c.tertiary,
          ),
          if (running.isNotEmpty) ...[
            const SizedBox(height: 14),
            _runtimeSectionTitle(c, Icons.play_arrow, '当前运行任务'),
            const SizedBox(height: 6),
            ...running.map((task) => _runtimeTaskRow(c, task)),
          ],
          if (idle.isNotEmpty) ...[
            const Divider(height: 20),
            _runtimeSectionTitle(c, Icons.schedule_outlined, '超过 24 小时未运行'),
            const SizedBox(height: 6),
            ...idle.map((task) => _idleTaskRow(c, task)),
          ],
        ],
      ),
    );
  }

  Widget _runtimeSectionTitle(ColorScheme c, IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 16, color: c.primary),
        const SizedBox(width: 7),
        Text(
          title,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.primary,
          ),
        ),
      ],
    );
  }

  Widget _runtimeTaskRow(ColorScheme c, DashboardRunningTask task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 7, color: c.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            _formatElapsed(task.elapsed),
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  Widget _idleTaskRow(ColorScheme c, DashboardIdleTask task) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.schedule_outlined, size: 16, color: c.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              task.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: c.onSurface),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            task.lastRun,
            style: TextStyle(fontSize: 12, color: c.onSurfaceVariant),
          ),
        ],
      ),
    );
  }

  final ScrollController _trSc = ScrollController();

  @override
  void dispose() {
    _trSc.dispose();
    super.dispose();
  }

  Widget _tr(ColorScheme c) {
    final d = _trend;
    if (d == null || d.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text("暂无趋势数据"));
    }
    final points = d
        .whereType<Map>()
        .map(
          (item) => _TrendPoint(
            date: item["date"]?.toString() ?? "",
            total: _trendValue(item["total"]),
            success: _trendValue(item["success"]),
            fail: _trendValue(item["fail"]),
          ),
        )
        .toList();
    if (points.isEmpty) {
      return const Padding(padding: EdgeInsets.all(16), child: Text("暂无趋势数据"));
    }
    return SizedBox(
      height: 244,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Column(
          children: [
            _trendLegend(c),
            const SizedBox(height: 8),
            Expanded(
              child: LayoutBuilder(
                builder: (_, constraints) {
                  final chartWidth = math.max(
                    constraints.maxWidth,
                    points.length * 68.0,
                  );
                  return SingleChildScrollView(
                    controller: _trSc,
                    scrollDirection: Axis.horizontal,
                    child: SizedBox(
                      width: chartWidth,
                      height: 188,
                      child: RepaintBoundary(
                        child: CustomPaint(
                          isComplex: true,
                          willChange: false,
                          painter: _TrendBarPainter(
                            points: points,
                            totalColor: c.tertiary,
                            successColor: c.primary,
                            failColor: c.error,
                            labelColor: c.onSurfaceVariant,
                            gridColor: c.outline.withValues(alpha: 0.18),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _trendLegend(ColorScheme c) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        _legendItem("总执行", c.tertiary),
        const SizedBox(width: 14),
        _legendItem("成功", c.primary),
        const SizedBox(width: 14),
        _legendItem("失败", c.error),
      ],
    );
  }

  Widget _legendItem(String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 11)),
      ],
    );
  }

  double _trendValue(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _tp(ColorScheme c) {
    final tt = _topTime, tc = _topCount;
    if ((tt == null || tt.isEmpty) && (tc == null || tc.isEmpty)) {
      return const Padding(padding: EdgeInsets.all(16), child: Text("暂无数据"));
    }
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tt != null && tt.isNotEmpty) ...[
            Text(
              "耗时最长",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(tt.length > 5 ? 5 : tt.length, (i) {
              var rank = i + 1;
              var rcol = rank <= 1
                  ? c.primary
                  : rank <= 2
                  ? c.tertiary
                  : c.onSurfaceVariant;
              var m = tt[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        "#${rank.toString()}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rcol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m["name"]?.toString() ?? "",
                        style: TextStyle(fontSize: 13, color: c.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _fmtDuration((m["avgTime"] as int?) ?? 0),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
          if (tt != null && tt.isNotEmpty && tc != null && tc.isNotEmpty)
            const Divider(height: 16),
          if (tc != null && tc.isNotEmpty) ...[
            Text(
              "运行最多",
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.primary,
              ),
            ),
            const SizedBox(height: 8),
            ...List.generate(tc.length > 5 ? 5 : tc.length, (i) {
              var rank = i + 1;
              var rcol = rank <= 1
                  ? c.primary
                  : rank <= 2
                  ? c.tertiary
                  : c.onSurfaceVariant;
              var m = tc[i] as Map;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 24,
                      child: Text(
                        "#${rank.toString()}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: rcol,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        m["name"]?.toString() ?? "",
                        style: TextStyle(fontSize: 13, color: c.onSurface),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "${m["runCount"]?.toString() ?? "-"} 次",
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: c.primary,
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  String _fmtDuration(int ms) {
    if (ms < 1000) return "${ms}ms";
    if (ms < 60000) {
      var s = (ms / 1000).toStringAsFixed(1);
      return "${s}s";
    }
    var m = (ms / 60000).toStringAsFixed(1);
    return "${m}m";
  }

  Widget _sy(ColorScheme c) {
    var s = _dashSys;
    if (s == null) return const SizedBox();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _sysRow(Icons.devices, "平台", s["platform"] as String? ?? "", c),
          const SizedBox(height: 8),
          _sysRow(
            Icons.memory,
            "内存",
            "${s["memUsagePercent"]?.toString() ?? "?"}%",
            c,
          ),
          const SizedBox(height: 8),
          _sysRow(Icons.memory, "CPU", "${s["cpus"]?.toString() ?? "?"} 核", c),
          const SizedBox(height: 8),
          _sysRow(
            Icons.access_time,
            "运行",
            _uptime(s["uptime"] as int? ?? 0),
            c,
          ),
        ],
      ),
    );
  }

  Widget _sysRow(
    IconData ic,
    String l,
    String v,
    ColorScheme c, {
    Color? accent,
  }) {
    final iconColor = accent ?? c.tertiary;
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Icon(ic, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Text(l, style: TextStyle(fontSize: 14, color: c.onSurfaceVariant)),
        const Spacer(),
        Text(
          v,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: c.onSurface,
          ),
        ),
      ],
    );
  }

  String _uptime(int s) {
    var d = s ~/ 86400;
    var h = (s % 86400) ~/ 3600;
    var m = ((s % 86400) % 3600) ~/ 60;
    return "$d天$h时$m分";
  }

  String _formatElapsed(int seconds) {
    if (seconds < 60) return '${seconds}s';
    if (seconds < 3600) return '${seconds ~/ 60}m';
    if (seconds < 86400) return '${seconds ~/ 3600}h';
    return '${seconds ~/ 86400}d';
  }

  String _fmt(int ms) {
    if (ms < 1000) return "${ms}ms";
    if (ms < 60000) {
      var s = (ms / 1000).toStringAsFixed(1);
      return "${s}s";
    }
    var m = (ms / 60000).toStringAsFixed(1);
    return "${m}m";
  }
}

class _TrendPoint {
  final String date;
  final double total;
  final double success;
  final double fail;

  const _TrendPoint({
    required this.date,
    required this.total,
    required this.success,
    required this.fail,
  });

  double get maxValue => math.max(total, math.max(success, fail));
}

class _TrendBarPainter extends CustomPainter {
  final List<_TrendPoint> points;
  final Color totalColor;
  final Color successColor;
  final Color failColor;
  final Color labelColor;
  final Color gridColor;

  _TrendBarPainter({
    required this.points,
    required this.totalColor,
    required this.successColor,
    required this.failColor,
    required this.labelColor,
    required this.gridColor,
  });

  late final double _maxValue = points.fold<double>(
    1,
    (current, point) => math.max(current, point.maxValue),
  );
  late final Paint _totalPaint = Paint()..color = totalColor;
  late final Paint _successPaint = Paint()..color = successColor;
  late final Paint _failPaint = Paint()..color = failColor;
  late final Paint _gridPaint = Paint()
    ..color = gridColor
    ..strokeWidth = 1;
  List<TextPainter>? _labels;
  double? _labelSlotWidth;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || size.width <= 0 || size.height <= 0) return;

    const topPadding = 10.0;
    const bottomPadding = 30.0;
    final plotHeight = math.max(0.0, size.height - topPadding - bottomPadding);
    final baseline = topPadding + plotHeight;
    final slotWidth = size.width / points.length;
    final barWidth = math.min(14.0, math.max(8.0, slotWidth * 0.16));
    final barGap = math.max(3.0, barWidth * 0.35);
    final groupWidth = barWidth * 3 + barGap * 2;

    for (var i = 0; i <= 3; i++) {
      final y = baseline - plotHeight * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), _gridPaint);
    }

    final barPaths = [Path(), Path(), Path()];
    for (var index = 0; index < points.length; index++) {
      final point = points[index];
      final groupLeft = index * slotWidth + (slotWidth - groupWidth) / 2;

      for (var barIndex = 0; barIndex < 3; barIndex++) {
        final value = switch (barIndex) {
          0 => point.total,
          1 => point.success,
          _ => point.fail,
        };
        if (value <= 0) continue;
        final barHeight = plotHeight * value / _maxValue;
        final left = groupLeft + barIndex * (barWidth + barGap);
        final rect = Rect.fromLTWH(
          left,
          baseline - barHeight,
          barWidth,
          barHeight,
        );
        barPaths[barIndex].addRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(3)),
        );
      }
    }

    canvas.drawPath(barPaths[0], _totalPaint);
    canvas.drawPath(barPaths[1], _successPaint);
    canvas.drawPath(barPaths[2], _failPaint);

    final labels = _getLabels(slotWidth);
    for (var index = 0; index < points.length; index++) {
      final label = labels[index];
      label.paint(canvas, Offset(index * slotWidth, baseline + 8));
    }
  }

  List<TextPainter> _getLabels(double slotWidth) {
    if (_labels != null && _labelSlotWidth == slotWidth) return _labels!;
    final labels = points
        .map(
          (point) => TextPainter(
            text: TextSpan(
              text: point.date,
              style: TextStyle(fontSize: 10, color: labelColor),
            ),
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.center,
            maxLines: 1,
          )..layout(maxWidth: slotWidth),
        )
        .toList();
    _labels = labels;
    _labelSlotWidth = slotWidth;
    return labels;
  }

  @override
  bool shouldRepaint(covariant _TrendBarPainter oldDelegate) {
    if (totalColor != oldDelegate.totalColor ||
        successColor != oldDelegate.successColor ||
        failColor != oldDelegate.failColor ||
        labelColor != oldDelegate.labelColor ||
        gridColor != oldDelegate.gridColor ||
        points.length != oldDelegate.points.length) {
      return true;
    }
    for (var i = 0; i < points.length; i++) {
      final current = points[i];
      final previous = oldDelegate.points[i];
      if (current.date != previous.date ||
          current.total != previous.total ||
          current.success != previous.success ||
          current.fail != previous.fail) {
        return true;
      }
    }
    return false;
  }
}
