import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/product_model.dart';
import '../services/api_service.dart';
import '../utils/helpers.dart';
import 'report_export.dart';

/// Dashboard phân tích tồn kho (phong cách shadcn/ui):
/// tỷ trọng, tỷ suất và tương quan giá – số lượng.
/// Mọi chỉ số đều tính từ 4 trường name, price, soluong, image.
class DashboardScreen extends StatefulWidget {
  /// Dữ liệu dựng sẵn (chỉ dùng để xem trước / chụp ảnh); null = đọc Firestore
  final List<ProductModel>? previewData;

  const DashboardScreen({super.key, this.previewData});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

// =====================================================================
// TOKENS: màu giao diện (zinc) + bảng màu biểu đồ đã kiểm tra mù màu
// =====================================================================
class _T {
  final bool d;
  const _T(this.d);

  Color get page => d ? const Color(0xFF09090B) : const Color(0xFFF4F4F5);
  Color get card => d ? const Color(0xFF111113) : Colors.white;
  Color get border => d ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
  Color get ink => d ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
  Color get ink2 => d ? const Color(0xFFD4D4D8) : const Color(0xFF3F3F46);
  Color get muted => d ? const Color(0xFFA1A1AA) : const Color(0xFF71717A);
  Color get grid => d ? const Color(0xFF27272A) : const Color(0xFFE4E4E7);
  Color get track => d ? const Color(0xFF27272A) : const Color(0xFFF4F4F5);
  Color get chip => d ? const Color(0xFF18181B) : const Color(0xFFF4F4F5);
  Color get primary => d ? const Color(0xFFFAFAFA) : const Color(0xFF09090B);
  Color get onPrimary => d ? const Color(0xFF09090B) : Colors.white;

  // Màu cho từng sản phẩm (tối đa 6; nhiều hơn gộp vào "Khác")
  List<Color> get series => d
      ? const [
          Color(0xFFE35A26),
          Color(0xFF159C94),
          Color(0xFFBF8400),
          Color(0xFF3A84CC),
          Color(0xFFCF4F84),
          Color(0xFF8C70E8),
        ]
      : const [
          Color(0xFFF4511E),
          Color(0xFF14A39A),
          Color(0xFFDDA000),
          Color(0xFF1D72B8),
          Color(0xFFE0679A),
          Color(0xFF7C5CE0),
        ];
  Color get other => const Color(0xFF898781);
  Color get teal => series[1];
  Color get blue => series[3];

  // Trạng thái (luôn đi kèm icon + chữ)
  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const critical = Color(0xFFD03B3B);

  // Badge
  Color get goodBg => d ? const Color(0xFF052E16) : const Color(0xFFDCFCE7);
  Color get goodFg => d ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
  Color get badBg => d ? const Color(0xFF450A0A) : const Color(0xFFFEE2E2);
  Color get badFg => d ? const Color(0xFFF87171) : const Color(0xFFB91C1C);
}

class _Item {
  final String name;
  final Color color;
  final List<ProductModel> members;
  _Item(this.name, this.color, this.members);

  int get value => members.fold(0, (s, p) => s + p.price * p.soluong);
  int get qty => members.fold(0, (s, p) => s + p.soluong);
}

enum _Metric { value, qty }

class _DashboardScreenState extends State<DashboardScreen> {
  StreamSubscription<List<ProductModel>>? _sub;
  List<ProductModel> _products = [];
  bool _loading = true;
  String? _error;

  int _touchedPie = -1;
  _Metric _paretoMetric = _Metric.value;
  _Metric _donutMetric = _Metric.value;
  final _tableKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.previewData != null) {
      _products = widget.previewData!;
      _loading = false;
      return;
    }
    _sub = ApiService().watchProducts().listen(
      (list) {
        if (!mounted) return;
        setState(() {
          _products = list;
          _loading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = '$e';
          _loading = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  // =====================================================================
  // TÍNH TOÁN
  // =====================================================================
  int get _totalValue => _products.fold(0, (s, p) => s + p.price * p.soluong);
  int get _totalQty => _products.fold(0, (s, p) => s + p.soluong);
  int _metricOf(ProductModel p, _Metric m) =>
      m == _Metric.value ? p.price * p.soluong : p.soluong;

  double? get _pearson {
    final n = _products.length;
    if (n < 3) return null;
    final xs = _products.map((p) => p.price.toDouble()).toList();
    final ys = _products.map((p) => p.soluong.toDouble()).toList();
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    double sxy = 0, sxx = 0, syy = 0;
    for (var i = 0; i < n; i++) {
      sxy += (xs[i] - mx) * (ys[i] - my);
      sxx += (xs[i] - mx) * (xs[i] - mx);
      syy += (ys[i] - my) * (ys[i] - my);
    }
    if (sxx == 0 || syy == 0) return null;
    return sxy / math.sqrt(sxx * syy);
  }

  String _strength(double r) {
    final a = r.abs();
    if (a >= 0.7) return 'mạnh';
    if (a >= 0.4) return 'trung bình';
    if (a >= 0.2) return 'yếu';
    return 'rất yếu';
  }

  /// Màu cố định theo tên sản phẩm; >6 SP thì 5 SP lớn nhất + "Khác"
  List<_Item> _items(_T t) {
    final byValue = List<ProductModel>.from(_products)
      ..sort((a, b) => (b.price * b.soluong).compareTo(a.price * a.soluong));
    final keep = byValue.length <= 6 ? byValue : byValue.take(5).toList();
    final rest = byValue.length <= 6
        ? <ProductModel>[]
        : byValue.skip(5).toList();
    final byName = List<ProductModel>.from(keep)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return [
      for (var i = 0; i < byName.length; i++)
        _Item(byName[i].name, t.series[i], [byName[i]]),
      if (rest.isNotEmpty) _Item('Khác (${rest.length} SP)', t.other, rest),
    ];
  }

  Color _colorOf(ProductModel p, List<_Item> items, _T t) {
    for (final it in items) {
      if (it.members.contains(p)) return it.color;
    }
    return t.other;
  }

  String _pct(num part, num whole, {int digits = 1}) => whole == 0
      ? '0%'
      : '${(part * 100 / whole).toStringAsFixed(digits).replaceAll('.', ',')}%';

  String _short(int vnd) {
    String f(double v) => v.toStringAsFixed(1).replaceAll('.', ',');
    if (vnd >= 1000000000) return '${f(vnd / 1e9)} tỷ';
    if (vnd >= 1000000) return '${f(vnd / 1e6)} tr';
    if (vnd >= 1000) return '${(vnd / 1e3).round()}k';
    return '$vnd';
  }

  TextStyle _num(double size, Color c, {FontWeight w = FontWeight.w600}) =>
      TextStyle(
        fontSize: size,
        fontWeight: w,
        color: c,
        letterSpacing: -0.3,
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  // =====================================================================
  // KHUNG TRANG
  // =====================================================================
  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context);
    final t = _T(base.brightness == Brightness.dark);

    return Scaffold(
      backgroundColor: t.page,
      body: SafeArea(
        child: DefaultTextStyle.merge(
          style: TextStyle(fontFamily: GoogleFonts.inter().fontFamily),
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text('Lỗi nạp dữ liệu: $_error'))
              : _content(context, t),
        ),
      ),
    );
  }

  Widget _content(BuildContext context, _T t) {
    final width = MediaQuery.of(context).size.width;
    final pad = width >= 700 ? 28.0 : 14.0;
    final wide = width >= 1100;
    final mid = width >= 760;

    if (_products.isEmpty) {
      return Column(
        children: [
          _header(context, t, width),
          const Expanded(
            child: Center(
              child: Text(
                'Chưa có sản phẩm để phân tích.\nHãy thêm sản phẩm hoặc khôi phục dữ liệu mẫu.',
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ],
      );
    }

    final items = _items(t);
    const gap = 16.0;

    Widget row(List<Widget> children, List<int> flex) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: gap),
            Expanded(flex: flex[i], child: children[i]),
          ],
        ],
      ),
    );
    Widget col(List<Widget> children) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(height: gap),
          children[i],
        ],
      ],
    );

    final kpis = _kpiRow(t, mid);
    final pareto = _paretoCard(t);
    final donut = _donutCard(t, items);
    final paired = _pairedCard(t);
    final top = _topStockCard(t, items);
    final scatter = _scatterCard(t, items);
    final status = _statusCard(t);
    final table = _tableCard(t);

    final body = wide
        ? col([
            row(
              [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    kpis,
                    const SizedBox(height: gap),
                    Expanded(child: pareto),
                  ],
                ),
                donut,
              ],
              [2, 1],
            ),
            row([paired, top, status], [1, 1, 1]),
            scatter,
            table,
          ])
        : mid
        ? col([
            kpis,
            pareto,
            row([donut, top], [1, 1]),
            row([paired, status], [1, 1]),
            scatter,
            table,
          ])
        : col([kpis, pareto, donut, paired, top, status, scatter, table]);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _header(context, t, width)),
        SliverPadding(
          padding: EdgeInsets.fromLTRB(pad, 20, pad, 40),
          sliver: SliverToBoxAdapter(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1360),
                child: body,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _header(BuildContext context, _T t, double width) {
    final compact = width < 640;
    final canPop = Navigator.of(context).canPop();
    return Container(
      decoration: BoxDecoration(
        color: t.card,
        border: Border(bottom: BorderSide(color: t.border)),
      ),
      padding: EdgeInsets.fromLTRB(compact ? 8 : 20, 14, compact ? 14 : 28, 14),
      child: Row(
        children: [
          if (canPop)
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: t.ink, size: 20),
              tooltip: 'Quay lại quản lý sản phẩm',
              onPressed: () => Navigator.of(context).pop(),
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dashboard',
                  style: TextStyle(
                    fontSize: compact ? 19 : 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.4,
                    color: t.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Phân tích tồn kho • tỷ trọng, tỷ suất & tương quan',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: t.muted),
                ),
              ],
            ),
          ),
          if (!compact) ...[
            Icon(Icons.check_circle_outline_rounded, size: 16, color: t.goodFg),
            const SizedBox(width: 6),
            Text(
              widget.previewData == null ? 'Đồng bộ trực tiếp' : 'Dữ liệu mẫu',
              style: TextStyle(fontSize: 12.5, color: t.goodFg),
            ),
            const SizedBox(width: 16),
          ],
          if (canPop) ...[
            compact
                ? IconButton.outlined(
                    style: IconButton.styleFrom(
                      side: BorderSide(color: t.border),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: Icon(
                      Icons.inventory_2_outlined,
                      size: 18,
                      color: t.ink,
                    ),
                    tooltip: 'Quản lý sản phẩm',
                    onPressed: () => Navigator.of(context).pop(),
                  )
                : OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: t.ink,
                      side: BorderSide(color: t.border),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      textStyle: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    icon: const Icon(Icons.inventory_2_outlined, size: 16),
                    label: const Text('Quản lý sản phẩm'),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
            const SizedBox(width: 8),
          ],
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: t.primary,
              foregroundColor: t.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            icon: const Icon(Icons.file_download_outlined, size: 16),
            label: const Text('Xuất báo cáo'),
            onPressed: () => showReportExport(context, _products),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // THÀNH PHẦN DÙNG CHUNG
  // =====================================================================
  Widget _card(_T t, {required Widget child, EdgeInsets? padding}) {
    return Container(
      padding: padding ?? const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: t.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: t.border),
        boxShadow: t.d
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 2,
                  offset: const Offset(0, 1),
                ),
              ],
      ),
      child: child,
    );
  }

  Widget _cardTitle(_T t, String title, {Widget? trailing, String? hint}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: t.ink,
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 3),
                Text(hint, style: TextStyle(fontSize: 12, color: t.muted)),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }

  Widget _badge(_T t, String text, {bool? good, IconData? icon}) {
    final bg = good == null ? t.chip : (good ? t.goodBg : t.badBg);
    final fg = good == null ? t.ink2 : (good ? t.goodFg : t.badFg);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 3),
          ],
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }

  /// Nút chuyển kiểu "1D 1W 1M" của shadcn
  Widget _segmented<V>(
    _T t,
    V value,
    Map<V, String> options,
    ValueChanged<V> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: t.chip,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final e in options.entries)
            GestureDetector(
              onTap: () => onChanged(e.key),
              child: MouseRegion(
                cursor: SystemMouseCursors.click,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: e.key == value ? t.card : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                    boxShadow: e.key == value && !t.d
                        ? [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.08),
                              blurRadius: 3,
                              offset: const Offset(0, 1),
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    e.value,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: e.key == value ? t.ink : t.muted,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dot(Color c, {double size = 8}) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: c, shape: BoxShape.circle),
  );

  Widget _bar(_T t, double fraction, Color color, {double height = 6}) {
    return Container(
      height: height,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: t.track,
        borderRadius: BorderRadius.circular(99),
      ),
      child: AnimatedFractionallySizedBox(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOutCubic,
        widthFactor: fraction.clamp(0.0, 1.0),
        heightFactor: 1,
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }

  LineTouchTooltipData _lineTooltip(
    _T t,
    List<LineTooltipItem?> Function(List<LineBarSpot>) items,
  ) {
    return LineTouchTooltipData(
      getTooltipColor: (_) => t.card,
      tooltipBorder: BorderSide(color: t.border),
      tooltipBorderRadius: BorderRadius.circular(8),
      tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      maxContentWidth: 220,
      fitInsideHorizontally: true,
      fitInsideVertically: true,
      getTooltipItems: items,
    );
  }

  TextStyle get _axis =>
      const TextStyle(fontSize: 11, color: Color(0xFF898781));

  // =====================================================================
  // 1. KPI
  // =====================================================================
  Widget _kpiRow(_T t, bool mid) {
    final n = _products.length;
    final low = _products.where((p) => p.soluong < 5).length;
    final out = _products.where((p) => p.soluong == 0).length;
    final r = _pearson;
    final qty = _totalQty;

    final cards = [
      _kpi(
        t,
        'Giá trị tồn kho',
        _short(_totalValue),
        _badge(t, '$n SP'),
        '${AppHelpers.formatNumber(qty)} đơn vị • TB ${_short(qty == 0 ? 0 : (_totalValue / qty).round())}/đv',
      ),
      _kpi(
        t,
        'Tỷ lệ sắp hết hàng',
        _pct(low, n),
        _badge(
          t,
          low == 0 ? 'Ổn định' : '$low SP < 5',
          good: low == 0,
          icon: low == 0 ? Icons.check_rounded : Icons.warning_amber_rounded,
        ),
        out == 0 ? 'Không có sản phẩm hết hàng' : '$out sản phẩm đã hết hàng',
      ),
      _kpi(
        t,
        'Tương quan giá – SL',
        r == null ? '—' : 'r = ${r.toStringAsFixed(2).replaceAll('.', ',')}',
        r == null
            ? _badge(t, 'Thiếu dữ liệu')
            : _badge(
                t,
                r < 0 ? 'Nghịch' : 'Thuận',
                icon: r < 0
                    ? Icons.south_east_rounded
                    : Icons.north_east_rounded,
              ),
        r == null
            ? 'Cần ít nhất 3 sản phẩm'
            : 'Tương quan ${_strength(r)}: giá cao thì tồn kho ${r < 0 ? 'ít' : 'nhiều'} hơn',
      ),
    ];

    if (!mid) {
      return Column(
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            cards[i],
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 16),
            Expanded(child: cards[i]),
          ],
        ],
      ),
    );
  }

  Widget _kpi(_T t, String label, String value, Widget badge, String note) {
    return _card(
      t,
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(fontSize: 13, color: t.muted),
                ),
              ),
              badge,
            ],
          ),
          const SizedBox(height: 10),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: _num(26, t.ink, w: FontWeight.w700)),
          ),
          const SizedBox(height: 6),
          Text(
            note,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12.5, color: t.muted),
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // 2. PARETO: tỷ trọng tích lũy (area chart)
  // =====================================================================
  Widget _paretoCard(_T t) {
    final m = _paretoMetric;
    final total = m == _Metric.value ? _totalValue : _totalQty;
    final sorted = List<ProductModel>.from(_products)
      ..sort((a, b) => _metricOf(b, m).compareTo(_metricOf(a, m)));

    final cum = <double>[0];
    var run = 0;
    for (final p in sorted) {
      run += _metricOf(p, m);
      cum.add(total == 0 ? 0 : run * 100 / total);
    }
    // Số SP ít nhất tạo ra ≥ 80%
    final k80 = cum.indexWhere((v) => v >= 80 - 1e-9);
    final share80 = k80 <= 0 ? 0.0 : cum[k80];
    final unit = m == _Metric.value ? 'giá trị kho' : 'số lượng kho';
    final color = t.teal;
    final n = sorted.length;

    final chart = SizedBox(
      height: 250,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: n.toDouble(),
          minY: 0,
          maxY: 100,
          gridData: FlGridData(
            drawVerticalLine: true,
            verticalInterval: 1,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.grid, strokeWidth: 1, dashArray: [4, 4]),
            getDrawingVerticalLine: (_) =>
                FlLine(color: t.grid, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: 80,
                color: t.muted.withValues(alpha: 0.7),
                strokeWidth: 1,
                dashArray: [2, 3],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 4, bottom: 2),
                  style: TextStyle(fontSize: 10.5, color: t.muted),
                  labelResolver: (_) => 'Ngưỡng 80%',
                ),
              ),
            ],
          ),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: 25,
                getTitlesWidget: (v, _) => Text('${v.round()}%', style: _axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (v, _) {
                  final i = v.round();
                  if (i == 0 || i > n || v != i) return const SizedBox();
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tooltip(
                      message: sorted[i - 1].name,
                      child: AppHelpers.buildProductImage(
                        imageUrl: sorted[i - 1].image,
                        size: 20,
                        radius: 5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchSpotThreshold: 40,
            getTouchedSpotIndicator: (bar, idx) => idx
                .map(
                  (_) => TouchedSpotIndicatorData(
                    FlLine(color: t.border, strokeWidth: 1, dashArray: [3, 3]),
                    FlDotData(
                      getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                        radius: 5,
                        color: color,
                        strokeWidth: 2,
                        strokeColor: t.card,
                      ),
                    ),
                  ),
                )
                .toList(),
            touchTooltipData: _lineTooltip(t, (spots) {
              return spots.map((s) {
                final i = s.x.round();
                if (i == 0) {
                  return LineTooltipItem(
                    'Điểm bắt đầu: 0%',
                    TextStyle(fontSize: 12, color: t.muted),
                  );
                }
                final p = sorted[i - 1];
                return LineTooltipItem(
                  '#$i  ${p.name}\n',
                  TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '● ',
                      style: TextStyle(color: color, fontSize: 11),
                    ),
                    TextSpan(
                      text:
                          'Lũy kế: ${cum[i].toStringAsFixed(1).replaceAll('.', ',')}%\n',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: t.ink2,
                      ),
                    ),
                    TextSpan(
                      text: 'Riêng SP: ${_pct(_metricOf(p, m), total)}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: t.muted,
                      ),
                    ),
                  ],
                );
              }).toList();
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < cum.length; i++)
                  FlSpot(i.toDouble(), cum[i]),
              ],
              isCurved: true,
              preventCurveOverShooting: true,
              curveSmoothness: 0.3,
              barWidth: 2,
              color: color,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, _, _, _) => FlDotCirclePainter(
                  radius: s.x == 0 ? 0 : 3,
                  color: t.card,
                  strokeWidth: 2,
                  strokeColor: color,
                ),
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    color.withValues(alpha: t.d ? 0.30 : 0.22),
                    color.withValues(alpha: 0.0),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            runSpacing: 10,
            spacing: 12,
            children: [
              Text(
                'Tỷ trọng tích lũy (Pareto)',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: t.ink,
                ),
              ),
              _segmented<_Metric>(t, _paretoMetric, const {
                _Metric.value: 'Giá trị',
                _Metric.qty: 'Số lượng',
              }, (v) => setState(() => _paretoMetric = v)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text('$k80 / $n SP', style: _num(24, t.ink, w: FontWeight.w700)),
              _badge(
                t,
                'tạo ${share80.toStringAsFixed(0)}% $unit',
                good: k80 * 2 <= n,
                icon: Icons.insights_rounded,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Sản phẩm xếp theo ${m == _Metric.value ? 'giá trị' : 'số lượng'} giảm dần; '
            'đường cong càng dốc ở đầu thì ${m == _Metric.value ? 'giá trị' : 'tồn kho'} càng tập trung.',
            style: TextStyle(fontSize: 12.5, color: t.muted),
          ),
          const SizedBox(height: 18),
          chart,
        ],
      ),
    );
  }

  // =====================================================================
  // 3. DONUT: cơ cấu (giá trị / số lượng) + bảng tỷ suất
  // =====================================================================
  Widget _donutCard(_T t, List<_Item> items) {
    final m = _donutMetric;
    int metric(_Item it) => m == _Metric.value ? it.value : it.qty;
    final total = m == _Metric.value ? _totalValue : _totalQty;
    final touched = _touchedPie >= 0 && _touchedPie < items.length
        ? items[_touchedPie]
        : null;

    final donut = SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          PieChart(
            PieChartData(
              startDegreeOffset: -90,
              sectionsSpace: 3,
              centerSpaceRadius: 62,
              pieTouchData: PieTouchData(
                touchCallback: (event, resp) {
                  final i =
                      (!event.isInterestedForInteractions ||
                          resp?.touchedSection == null)
                      ? -1
                      : resp!.touchedSection!.touchedSectionIndex;
                  if (i != _touchedPie) setState(() => _touchedPie = i);
                },
              ),
              sections: [
                for (var i = 0; i < items.length; i++)
                  PieChartSectionData(
                    value: math.max(metric(items[i]), 0).toDouble(),
                    color: _touchedPie == -1 || _touchedPie == i
                        ? items[i].color
                        : items[i].color.withValues(alpha: 0.35),
                    radius: i == _touchedPie ? 34 : 28,
                    showTitle: false,
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 44),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  touched == null
                      ? (m == _Metric.value
                            ? _short(total)
                            : AppHelpers.formatNumber(total))
                      : _pct(metric(touched), total),
                  style: _num(22, t.ink, w: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  touched?.name ??
                      (m == _Metric.value ? 'Tổng giá trị' : 'Tổng số lượng'),
                  maxLines: 2,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11.5, color: t.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final sortedIdx = List<int>.generate(items.length, (i) => i)
      ..sort((a, b) => metric(items[b]).compareTo(metric(items[a])));

    final legend = Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final i in sortedIdx)
          MouseRegion(
            onEnter: (_) => setState(() => _touchedPie = i),
            onExit: (_) => setState(() => _touchedPie = -1),
            child: Tooltip(
              message: '${items[i].name}: ${_pct(metric(items[i]), total)}',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _dot(items[i].color),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 130),
                    child: Text(
                      items[i].name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: _touchedPie == i ? t.ink : t.ink2,
                        fontWeight: _touchedPie == i
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    _pct(metric(items[i]), total, digits: 0),
                    style: _num(12, t.muted, w: FontWeight.w500),
                  ),
                ],
              ),
            ),
          ),
      ],
    );

    // Bảng tỷ suất
    final byPrice = List<ProductModel>.from(_products)
      ..sort((a, b) => b.price.compareTo(a.price));
    final half = byPrice.take((byPrice.length / 2).ceil()).toList();
    final halfValue = half.fold<int>(0, (s, p) => s + p.price * p.soluong);
    final halfQty = half.fold<int>(0, (s, p) => s + p.soluong);
    final maxMin = byPrice.length < 2 || byPrice.last.price == 0
        ? null
        : byPrice.first.price / byPrice.last.price;
    final qty = _totalQty;

    final th = TextStyle(fontSize: 12, color: t.muted);
    Widget tr(String a, String b, Widget c) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              a,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w500,
                color: t.ink,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              b,
              textAlign: TextAlign.center,
              style: _num(12.5, t.ink2, w: FontWeight.w400),
            ),
          ),
          Expanded(
            flex: 3,
            child: Align(alignment: Alignment.centerRight, child: c),
          ),
        ],
      ),
    );

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            t,
            'Cơ cấu tồn kho',
            trailing: _segmented<_Metric>(t, _donutMetric, const {
              _Metric.value: 'Giá trị',
              _Metric.qty: 'SL',
            }, (v) => setState(() => _donutMetric = v)),
          ),
          const SizedBox(height: 18),
          Center(child: donut),
          const SizedBox(height: 18),
          legend,
          const SizedBox(height: 18),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(flex: 5, child: Text('Tỷ suất', style: th)),
              Expanded(
                flex: 4,
                child: Text('Giá trị', textAlign: TextAlign.center, style: th),
              ),
              Expanded(
                flex: 3,
                child: Text('Tỷ lệ', textAlign: TextAlign.right, style: th),
              ),
            ],
          ),
          const SizedBox(height: 4),
          tr(
            'Giá BQ / đơn vị',
            _short(qty == 0 ? 0 : (_totalValue / qty).round()),
            Text(
              '${_products.length} SP',
              style: _num(12.5, t.muted, w: FontWeight.w500),
            ),
          ),
          tr(
            'Giá cao / thấp nhất',
            byPrice.isEmpty
                ? '—'
                : '${_short(byPrice.first.price)} / ${_short(byPrice.last.price)}',
            Text(
              maxMin == null
                  ? '—'
                  : '×${maxMin.toStringAsFixed(1).replaceAll('.', ',')}',
              style: _num(12.5, t.ink, w: FontWeight.w600),
            ),
          ),
          tr(
            '50% SP giá cao nhất',
            '${_pct(halfQty, qty, digits: 0)} số lượng',
            _badge(
              t,
              '${_pct(halfValue, _totalValue, digits: 0)} GT',
              good: true,
              icon: Icons.north_east_rounded,
            ),
          ),
          tr(
            'SL trung bình / SP',
            (_products.isEmpty ? 0 : qty / _products.length)
                .toStringAsFixed(1)
                .replaceAll('.', ','),
            Text('đơn vị', style: TextStyle(fontSize: 12, color: t.muted)),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                foregroundColor: t.ink,
                side: BorderSide(color: t.border),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
              onPressed: () {
                final ctx = _tableKey.currentContext;
                if (ctx != null) {
                  Scrollable.ensureVisible(
                    ctx,
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutCubic,
                  );
                }
              },
              child: const Text('Xem bảng số liệu'),
            ),
          ),
        ],
      ),
    );
  }

  /// Sản phẩm sắp theo giá trị tồn kho (giá × số lượng) giảm dần
  List<(ProductModel, int)> _valueRows() {
    final sorted = List<ProductModel>.from(_products)
      ..sort((a, b) => (b.price * b.soluong).compareTo(a.price * a.soluong));
    return [for (final p in sorted) (p, p.price * p.soluong)];
  }

  // =====================================================================
  // 5. % GIÁ TRỊ vs % SỐ LƯỢNG (cột đôi, cùng thang %)
  // =====================================================================
  Widget _pairedCard(_T t) {
    final sorted = List<ProductModel>.from(_products)
      ..sort((a, b) => (b.price * b.soluong).compareTo(a.price * a.soluong));
    final shown = sorted.take(6).toList();
    final tv = _totalValue, tq = _totalQty;
    double vs(ProductModel p) => tv == 0 ? 0 : p.price * p.soluong * 100 / tv;
    double qs(ProductModel p) => tq == 0 ? 0 : p.soluong * 100 / tq;
    final maxV = shown.fold<double>(
      0,
      (m, p) => math.max(m, math.max(vs(p), qs(p))),
    );
    final maxY = math.max(10.0, (maxV / 10).ceil() * 10.0);
    final cV = t.teal, cQ = t.blue;

    ProductModel? gapP;
    double gap = 0;
    for (final p in _products) {
      final g = vs(p) - qs(p);
      if (g.abs() > gap.abs()) {
        gap = g;
        gapP = p;
      }
    }

    final chart = SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxY,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            drawVerticalLine: false,
            horizontalInterval: maxY / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.grid, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                interval: maxY / 4,
                getTitlesWidget: (v, _) => Text('${v.round()}%', style: _axis),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                getTitlesWidget: (v, _) {
                  final p = shown[v.toInt()];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Tooltip(
                      message: p.name,
                      child: AppHelpers.buildProductImage(
                        imageUrl: p.image,
                        size: 20,
                        radius: 5,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => t.card,
              tooltipBorder: BorderSide(color: t.border),
              tooltipBorderRadius: BorderRadius.circular(8),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              maxContentWidth: 200,
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              getTooltipItem: (group, gi, rod, ri) {
                final p = shown[gi];
                return BarTooltipItem(
                  '${p.name}\n',
                  TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '● ',
                      style: TextStyle(color: cV, fontSize: 11),
                    ),
                    TextSpan(
                      text:
                          'Giá trị: ${vs(p).toStringAsFixed(1).replaceAll('.', ',')}%\n',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: t.ink2,
                      ),
                    ),
                    TextSpan(
                      text: '● ',
                      style: TextStyle(color: cQ, fontSize: 11),
                    ),
                    TextSpan(
                      text:
                          'Số lượng: ${qs(p).toStringAsFixed(1).replaceAll('.', ',')}%',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: t.ink2,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          barGroups: [
            for (var i = 0; i < shown.length; i++)
              BarChartGroupData(
                x: i,
                barsSpace: 3,
                barRods: [
                  BarChartRodData(
                    toY: vs(shown[i]),
                    color: cV,
                    width: 9,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                  BarChartRodData(
                    toY: qs(shown[i]),
                    color: cQ,
                    width: 9,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(4),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            t,
            'Giá trị vs số lượng',
            hint: sorted.length > 6
                ? '6 sản phẩm giá trị cao nhất • cùng thang %'
                : 'Tỷ trọng của từng sản phẩm, cùng thang %',
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _dot(cV),
              const SizedBox(width: 6),
              Text(
                '% giá trị',
                style: TextStyle(fontSize: 12.5, color: t.ink2),
              ),
              const SizedBox(width: 16),
              _dot(cQ),
              const SizedBox(width: 6),
              Text(
                '% số lượng',
                style: TextStyle(fontSize: 12.5, color: t.ink2),
              ),
            ],
          ),
          const SizedBox(height: 14),
          chart,
          const SizedBox(height: 14),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  gapP == null
                      ? 'Chênh lệch lớn nhất'
                      : 'Lệch nhiều nhất: ${gapP.name}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12.5, color: t.muted),
                ),
              ),
              const SizedBox(width: 8),
              _badge(
                t,
                '${gap >= 0 ? '+' : ''}${gap.toStringAsFixed(1).replaceAll('.', ',')} điểm',
                good: gap >= 0,
                icon: gap >= 0
                    ? Icons.north_east_rounded
                    : Icons.south_east_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // =====================================================================
  // 6. TỒN KHO NHIỀU NHẤT (ảnh sản phẩm + thanh tiến độ)
  // =====================================================================
  Widget _topStockCard(_T t, List<_Item> items) {
    final sorted = List<ProductModel>.from(_products)
      ..sort((a, b) => b.soluong.compareTo(a.soluong));
    final top = sorted.take(4).toList();
    final tq = _totalQty;

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(
            t,
            'Tồn kho nhiều nhất',
            hint:
                'Số lượng và tỷ trọng trên tổng ${AppHelpers.formatNumber(tq)} đơn vị',
          ),
          const SizedBox(height: 16),
          for (final p in top) ...[
            Row(
              children: [
                AppHelpers.buildProductImage(
                  imageUrl: p.image,
                  size: 26,
                  radius: 6,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: t.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  AppHelpers.formatNumber(p.soluong),
                  style: _num(13.5, t.ink),
                ),
                const SizedBox(width: 4),
                Text(
                  '(${_pct(p.soluong, tq, digits: 0)})',
                  style: _num(12.5, t.muted, w: FontWeight.w400),
                ),
              ],
            ),
            const SizedBox(height: 9),
            _bar(t, tq == 0 ? 0 : p.soluong / tq, _colorOf(p, items, t)),
            const SizedBox(height: 18),
          ],
        ],
      ),
    );
  }

  // =====================================================================
  // 7. TƯƠNG QUAN GIÁ – SỐ LƯỢNG (điểm + đường xu hướng)
  // =====================================================================
  double _niceCeil(double v) {
    if (v <= 0) return 1;
    final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
    for (final m in [1, 2, 2.5, 4, 5, 8, 10]) {
      if (m * exp >= v * 1.08) return m * exp;
    }
    return 10 * exp;
  }

  Widget _scatterCard(_T t, List<_Item> items) {
    final pts = _products
        .map((p) => (p, p.price / 1e6, p.soluong.toDouble()))
        .toList();
    final xMax = _niceCeil(pts.map((e) => e.$2).fold<double>(0, math.max));
    final yMax = _niceCeil(pts.map((e) => e.$3).fold<double>(0, math.max));

    List<FlSpot> trend = [];
    if (pts.length >= 3) {
      final n = pts.length;
      final mx = pts.map((e) => e.$2).reduce((a, b) => a + b) / n;
      final my = pts.map((e) => e.$3).reduce((a, b) => a + b) / n;
      double sxy = 0, sxx = 0;
      for (final e in pts) {
        sxy += (e.$2 - mx) * (e.$3 - my);
        sxx += (e.$2 - mx) * (e.$2 - mx);
      }
      if (sxx > 0) {
        final b = sxy / sxx;
        final a = my - b * mx;
        double y(double x) => (a + b * x).clamp(0, yMax).toDouble();
        trend = [FlSpot(0, y(0)), FlSpot(xMax, y(xMax))];
      }
    }
    final r = _pearson;

    final chart = SizedBox(
      height: 260,
      child: LineChart(
        LineChartData(
          minX: 0,
          maxX: xMax,
          minY: 0,
          maxY: yMax,
          clipData: const FlClipData.all(),
          gridData: FlGridData(
            horizontalInterval: yMax / 4,
            verticalInterval: xMax / 4,
            getDrawingHorizontalLine: (_) =>
                FlLine(color: t.grid, strokeWidth: 1, dashArray: [4, 4]),
            getDrawingVerticalLine: (_) =>
                FlLine(color: t.grid, strokeWidth: 1, dashArray: [4, 4]),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(),
            rightTitles: const AxisTitles(),
            leftTitles: AxisTitles(
              axisNameWidget: Text('Số lượng', style: _axis),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 32,
                interval: yMax / 4,
                getTitlesWidget: (v, _) =>
                    Text(v.round().toString(), style: _axis),
              ),
            ),
            bottomTitles: AxisTitles(
              axisNameWidget: Text('Giá (triệu ₫)', style: _axis),
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: xMax / 4,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    v == v.roundToDouble()
                        ? '${v.round()}'
                        : v.toStringAsFixed(1).replaceAll('.', ','),
                    style: _axis,
                  ),
                ),
              ),
            ),
          ),
          lineTouchData: LineTouchData(
            touchSpotThreshold: 18,
            getTouchedSpotIndicator: (bar, idx) => idx
                .map(
                  (i) => TouchedSpotIndicatorData(
                    const FlLine(color: Colors.transparent),
                    FlDotData(
                      getDotPainter: (s, _, b, _) => FlDotCirclePainter(
                        radius: b.dotData.show ? 10 : 0,
                        color: b.dotData.show && i < pts.length
                            ? _colorOf(pts[i].$1, items, t)
                            : Colors.transparent,
                        strokeWidth: b.dotData.show ? 3 : 0,
                        strokeColor: t.card,
                      ),
                    ),
                  ),
                )
                .toList(),
            touchTooltipData: _lineTooltip(t, (spots) {
              return spots.map((s) {
                if (s.barIndex != 0) return null;
                final p = pts[s.spotIndex].$1;
                return LineTooltipItem(
                  '${p.name}\n',
                  TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: t.ink,
                  ),
                  textAlign: TextAlign.left,
                  children: [
                    TextSpan(
                      text: '● ',
                      style: TextStyle(
                        color: _colorOf(p, items, t),
                        fontSize: 11,
                      ),
                    ),
                    TextSpan(
                      text:
                          'Giá: ${AppHelpers.formatPrice(p.price)}\nSố lượng: ${p.soluong}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w400,
                        color: t.ink2,
                      ),
                    ),
                  ],
                );
              }).toList();
            }),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (final e in pts) FlSpot(e.$2, e.$3)],
              barWidth: 0,
              color: Colors.transparent,
              dotData: FlDotData(
                show: true,
                getDotPainter: (s, _, _, i) => FlDotCirclePainter(
                  radius: 7,
                  color: _colorOf(pts[i].$1, items, t),
                  strokeWidth: 2,
                  strokeColor: t.card,
                ),
              ),
            ),
            if (trend.isNotEmpty)
              LineChartBarData(
                spots: trend,
                barWidth: 1.5,
                color: t.muted,
                dashArray: [6, 5],
                dotData: const FlDotData(show: false),
              ),
          ],
        ),
      ),
    );

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                'Tương quan giá – số lượng',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.2,
                  color: t.ink,
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var i = 0; i < 3; i++)
                    Container(
                      width: 5,
                      height: 1.5,
                      margin: const EdgeInsets.only(right: 2),
                      color: t.muted,
                    ),
                  const SizedBox(width: 6),
                  Text(
                    'Xu hướng tuyến tính',
                    style: TextStyle(fontSize: 12, color: t.muted),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 10,
            runSpacing: 6,
            children: [
              Text(
                r == null
                    ? 'r = —'
                    : 'r = ${r.toStringAsFixed(2).replaceAll('.', ',')}',
                style: _num(24, t.ink, w: FontWeight.w700),
              ),
              if (r != null)
                _badge(
                  t,
                  'R² = ${(r * r * 100).toStringAsFixed(0)}%',
                  icon: Icons.functions_rounded,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            r == null
                ? 'Cần ít nhất 3 sản phẩm để tính tương quan'
                : 'Tương quan ${r < 0 ? 'nghịch' : 'thuận'} ${_strength(r)}: giá giải thích khoảng '
                      '${(r * r * 100).toStringAsFixed(0)}% sự khác biệt về số lượng tồn kho. Mỗi điểm là một sản phẩm.',
            style: TextStyle(fontSize: 12.5, color: t.muted),
          ),
          const SizedBox(height: 18),
          chart,
        ],
      ),
    );
  }

  // =====================================================================
  // 8. TÌNH TRẠNG KHO + CẦN NHẬP THÊM
  // =====================================================================
  Widget _statusCard(_T t) {
    final n = _products.length;
    final out = _products.where((p) => p.soluong == 0).toList();
    final low = _products.where((p) => p.soluong > 0 && p.soluong < 5).toList();
    final ok = n - out.length - low.length;
    final groups = [
      ('Đủ hàng', '≥ 5', ok, _T.good, Icons.check_circle_rounded),
      ('Sắp hết', '1–4', low.length, _T.warning, Icons.error_rounded),
      ('Hết hàng', '0', out.length, _T.critical, Icons.cancel_rounded),
    ];
    final need = [...out, ...low]
      ..sort((a, b) => a.soluong.compareTo(b.soluong));
    final visible = groups.where((g) => g.$3 > 0).toList();

    return _card(
      t,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _cardTitle(t, 'Tình trạng kho', hint: 'Tỷ lệ sản phẩm theo mức tồn'),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              height: 12,
              child: Row(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) Container(width: 2, color: t.card),
                    Expanded(
                      flex: visible[i].$3,
                      child: Tooltip(
                        message:
                            '${visible[i].$1}: ${visible[i].$3} SP (${_pct(visible[i].$3, n)})',
                        child: Container(color: visible[i].$4),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          for (final g in groups)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Icon(g.$5, size: 16, color: g.$4),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${g.$1} (${g.$2})',
                      style: TextStyle(fontSize: 13, color: t.ink2),
                    ),
                  ),
                  Text('${g.$3} SP', style: _num(13, t.ink)),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 40,
                    child: Text(
                      _pct(g.$3, n, digits: 0),
                      textAlign: TextAlign.right,
                      style: _num(12.5, t.muted, w: FontWeight.w500),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 14),
          Divider(height: 1, color: t.border),
          const SizedBox(height: 14),
          Text(
            'Cần nhập thêm',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: t.ink,
            ),
          ),
          const SizedBox(height: 10),
          if (need.isEmpty)
            Row(
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: t.goodFg,
                ),
                const SizedBox(width: 6),
                Text(
                  'Tất cả sản phẩm đều đủ hàng',
                  style: TextStyle(fontSize: 12.5, color: t.muted),
                ),
              ],
            )
          else
            for (final p in need.take(4))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  children: [
                    AppHelpers.buildProductImage(
                      imageUrl: p.image,
                      size: 30,
                      radius: 7,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: t.ink),
                      ),
                    ),
                    _badge(
                      t,
                      p.soluong == 0 ? 'Hết' : 'Còn ${p.soluong}',
                      good: false,
                    ),
                  ],
                ),
              ),
        ],
      ),
    );
  }

  // =====================================================================
  // 9. BẢNG SỐ LIỆU
  // =====================================================================
  Widget _tableCard(_T t) {
    final rows = _valueRows();
    final tv = _totalValue, tq = _totalQty;
    final head = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: t.muted,
    );
    final cell = _num(13, t.ink, w: FontWeight.w400);

    return KeyedSubtree(
      key: _tableKey,
      child: _card(
        t,
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cardTitle(
              t,
              'Bảng số liệu',
              hint: 'Sắp theo giá trị tồn kho • 4 trường gốc và tỷ trọng',
              trailing: _badge(t, '${rows.length} dòng'),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, c) => SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: c.maxWidth),
                  child: DataTable(
                    headingRowHeight: 40,
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 56,
                    columnSpacing: 24,
                    horizontalMargin: 4,
                    dividerThickness: 1,
                    border: TableBorder(
                      horizontalInside: BorderSide(color: t.border),
                    ),
                    columns: [
                      DataColumn(label: Text('Sản phẩm', style: head)),
                      DataColumn(
                        label: Text('Giá', style: head),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text('Số lượng', style: head),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text('Giá trị', style: head),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text('% giá trị', style: head),
                        numeric: true,
                      ),
                      DataColumn(
                        label: Text('% số lượng', style: head),
                        numeric: true,
                      ),
                    ],
                    rows: [
                      for (final r in rows)
                        DataRow(
                          cells: [
                            DataCell(
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  AppHelpers.buildProductImage(
                                    imageUrl: r.$1.image,
                                    size: 32,
                                    radius: 7,
                                  ),
                                  const SizedBox(width: 10),
                                  ConstrainedBox(
                                    constraints: const BoxConstraints(
                                      maxWidth: 230,
                                    ),
                                    child: Text(
                                      r.$1.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: t.ink,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            DataCell(
                              Text(
                                AppHelpers.formatPrice(r.$1.price),
                                style: cell,
                              ),
                            ),
                            DataCell(Text('${r.$1.soluong}', style: cell)),
                            DataCell(
                              Text(AppHelpers.formatPrice(r.$2), style: cell),
                            ),
                            DataCell(Text(_pct(r.$2, tv), style: cell)),
                            DataCell(Text(_pct(r.$1.soluong, tq), style: cell)),
                          ],
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
