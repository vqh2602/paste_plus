import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/ui/cupertino_components.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  var _page = 0;
  var _retentionDays = 30;

  static const _pages = [
    (
      CupertinoIcons.doc_on_clipboard,
      'Mọi thứ bạn sao chép, luôn ở đúng nơi',
      'ClipFlow lưu lịch sử clipboard để bạn tìm lại văn bản, liên kết, code và nhiều nội dung khác trong vài giây.',
    ),
    (
      CupertinoIcons.shield,
      'Riêng tư ngay từ thiết kế',
      'Dữ liệu chỉ được lưu trên thiết bị này. ClipFlow không tải nội dung clipboard lên máy chủ.',
    ),
    (
      CupertinoIcons.slider_horizontal_3,
      'Bạn luôn nắm quyền kiểm soát',
      'Tạm dừng theo dõi bất cứ lúc nào, bỏ qua ứng dụng nhạy cảm và xóa sạch dữ liệu chỉ với một thao tác.',
    ),
    (
      CupertinoIcons.clock,
      'Bạn muốn giữ lịch sử bao lâu?',
      'Có thể thay đổi lựa chọn này bất kỳ lúc nào trong phần Cài đặt.',
    ),
    (
      CupertinoIcons.keyboard,
      'Sẵn sàng để làm việc nhanh hơn',
      'Nhấn Control + V trên macOS hoặc Control + Shift + V trên Windows/Linux để mở ClipFlow.',
    ),
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_page < _pages.length - 1) {
      await _controller.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
      return;
    }
    await ref
        .read(settingsControllerProvider.notifier)
        .update(
          (settings) => settings.copyWith(
            hasCompletedOnboarding: true,
            retentionDays: _retentionDays,
          ),
        );
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const _OnboardingBackground(),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: CupertinoSurface(
                    borderRadius: BorderRadius.circular(24),
                    padding: const EdgeInsets.fromLTRB(42, 38, 42, 30),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 38,
                              height: 38,
                              decoration: BoxDecoration(
                                color: CupertinoTheme.of(context).primaryColor,
                                borderRadius: BorderRadius.circular(11),
                              ),
                              child: const Icon(
                                CupertinoIcons.doc_on_clipboard_fill,
                                color: CupertinoColors.white,
                                size: 21,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'ClipFlow',
                              style: TextStyle(
                                fontSize: 21,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const Spacer(),
                            Text(
                              '${_page + 1} / ${_pages.length}',
                              style: const TextStyle(
                                color: ClipFlowColors.secondaryText,
                              ),
                            ),
                          ],
                        ),
                        Expanded(
                          child: PageView.builder(
                            controller: _controller,
                            onPageChanged: (value) =>
                                setState(() => _page = value),
                            itemCount: _pages.length,
                            itemBuilder: (context, index) {
                              final page = _pages[index];
                              return _OnboardingPage(
                                icon: page.$1,
                                title: page.$2,
                                description: page.$3,
                                retentionPicker: index == 3
                                    ? Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        alignment: WrapAlignment.center,
                                        children: [7, 30, 90, -1].map((days) {
                                          return CupertinoChoicePill(
                                            label: days == -1
                                                ? 'Không giới hạn'
                                                : '$days ngày',
                                            selected: _retentionDays == days,
                                            onPressed: () => setState(
                                              () => _retentionDays = days,
                                            ),
                                          );
                                        }).toList(),
                                      )
                                    : null,
                              );
                            },
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(99),
                                child: SizedBox(
                                  height: 5,
                                  child: Stack(
                                    fit: StackFit.expand,
                                    children: [
                                      const ColoredBox(
                                        color: ClipFlowColors.elevatedSurface,
                                      ),
                                      FractionallySizedBox(
                                        alignment: Alignment.centerLeft,
                                        widthFactor:
                                            (_page + 1) / _pages.length,
                                        child: ColoredBox(
                                          color: CupertinoTheme.of(
                                            context,
                                          ).primaryColor,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 24),
                            CupertinoButton.filled(
                              onPressed: _next,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    _page == _pages.length - 1
                                        ? 'Bắt đầu'
                                        : 'Tiếp tục',
                                  ),
                                  const SizedBox(width: 7),
                                  Icon(
                                    _page == _pages.length - 1
                                        ? CupertinoIcons.check_mark
                                        : CupertinoIcons.arrow_right,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({
    required this.icon,
    required this.title,
    required this.description,
    this.retentionPicker,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? retentionPicker;

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 92,
            height: 92,
            decoration: BoxDecoration(
              color: primary.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Icon(icon, size: 42, color: primary),
          ),
          const SizedBox(height: 28),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.7,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540),
            child: Text(
              description,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                color: ClipFlowColors.secondaryText,
                height: 1.5,
              ),
            ),
          ),
          if (retentionPicker != null) ...[
            const SizedBox(height: 26),
            retentionPicker!,
          ],
        ],
      ),
    );
  }
}

class _OnboardingBackground extends StatelessWidget {
  const _OnboardingBackground();

  @override
  Widget build(BuildContext context) {
    final primary = CupertinoTheme.of(context).primaryColor;
    return Positioned.fill(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              primary.withValues(alpha: 0.16),
              CupertinoTheme.of(context).scaffoldBackgroundColor,
              const Color(0xFF30B0C7).withValues(alpha: 0.1),
            ],
          ),
        ),
      ),
    );
  }
}
