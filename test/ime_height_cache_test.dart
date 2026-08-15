import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/app_layout_constants.dart';
import 'package:mind_recall/core/ui/ime_height_cache.dart';

void main() {
  group('imeHeightCacheKey', () {
    test('横竖屏尺寸分成不同桶', () {
      expect(
        imeHeightCacheKey(viewWidthLogical: 360, viewHeightLogical: 800),
        '360x800',
      );
      expect(
        imeHeightCacheKey(viewWidthLogical: 800, viewHeightLogical: 360),
        '800x360',
      );
    });
  });

  group('ImeHeightCache', () {
    test('store lookup 忽略非正高度', () {
      final cache = ImeHeightCache();
      expect(cache.lookup('360x800'), isNull);
      cache.store('360x800', 348.1);
      expect(cache.lookup('360x800'), 348.1);
      cache.store('360x800', 0);
      expect(cache.lookup('360x800'), isNull);
    });

    test('同高度不通知；hydrate 不通知', () {
      var n = 0;
      final cache = ImeHeightCache(onChanged: () => n++);
      cache.hydrate({'360x800': 348.1});
      expect(n, 0);
      expect(cache.lookup('360x800'), 348.1);
      cache.store('360x800', 348.2);
      expect(n, 0);
      cache.store('360x800', 400);
      expect(n, 1);
    });
  });

  group('ime height cache json', () {
    test('编解码按视口分桶', () {
      final json = encodeImeHeightCacheJson({'360x800': 348.1, '800x360': 0});
      expect(json[kImeHeightCacheJsonHeightsKey], {'360x800': 348.1});
      expect(
        decodeImeHeightCacheJson(json),
        {'360x800': 348.1},
      );
    });

    test('损坏或空 JSON 视为无缓存', () {
      expect(decodeImeHeightCacheJson(null), isEmpty);
      expect(decodeImeHeightCacheJson('nope'), isEmpty);
      expect(decodeImeHeightCacheJson({'heights': 1}), isEmpty);
    });
  });

  group('shouldSyncImeToolbarInset', () {
    test('隐藏时用目标高度显栏', () {
      expect(
        shouldSyncImeToolbarInset(targetLogical: 348.1, toolbarLogical: 0),
        isTrue,
      );
    });

    test('已显示且高度相同则不动', () {
      expect(
        shouldSyncImeToolbarInset(targetLogical: 348.1, toolbarLogical: 348.1),
        isFalse,
      );
    });

    test('已显示且目标变化则跟随', () {
      expect(
        shouldSyncImeToolbarInset(targetLogical: 400, toolbarLogical: 348.1),
        isTrue,
      );
    });
  });

  group('resolveImeSettleDecision', () {
    test('无缓存时提交 pending 并防抖 nudge', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 296.9,
        committedLogical: 0,
        cachedLogical: null,
        appliedCacheThisOpen: false,
      );
      expect(d.commitLogical, 296.9);
      expect(d.reason, 'settle');
      expect(d.nudge, ImeSettleNudgeMode.debounce);
      expect(d.markCacheApplied, isFalse);
      expect(d.storeCacheLogical, isNull);
    });

    test('无缓存且 pending 与 committed 接近则不动', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 280.2,
        committedLogical: 280,
        cachedLogical: null,
        appliedCacheThisOpen: false,
      );
      expect(d.shouldCommit, isFalse);
      expect(d.nudge, ImeSettleNudgeMode.none);
    });

    test('有缓存首次 settle 用缓存高度并立即 nudge', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 296.9,
        committedLogical: 0,
        cachedLogical: 348.1,
        appliedCacheThisOpen: false,
      );
      expect(d.commitLogical, 348.1);
      expect(d.reason, 'applyCache');
      expect(d.nudge, ImeSettleNudgeMode.immediate);
      expect(d.markCacheApplied, isTrue);
      expect(d.storeCacheLogical, 348.1);
    });

    test('有缓存且 pending 已更高则取 pending', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 360,
        committedLogical: 0,
        cachedLogical: 348.1,
        appliedCacheThisOpen: false,
      );
      expect(d.commitLogical, 360);
    });

    test('已套用缓存后低于 committed 的假停不再收回', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 299.4,
        committedLogical: 348.1,
        cachedLogical: 348.1,
        appliedCacheThisOpen: true,
      );
      expect(d.shouldCommit, isFalse);
      expect(d.nudge, ImeSettleNudgeMode.none);
    });

    test('profile：无缓存连 settle 只防抖；有缓存首次即 348', () {
      var applied = false;
      double? cached;

      final first = resolveImeSettleDecision(
        pendingLogical: 296.9,
        committedLogical: 0,
        cachedLogical: cached,
        appliedCacheThisOpen: applied,
      );
      expect(first.nudge, ImeSettleNudgeMode.debounce);
      expect(first.commitLogical, 296.9);

      final second = resolveImeSettleDecision(
        pendingLogical: 348.1,
        committedLogical: 300.1,
        cachedLogical: cached,
        appliedCacheThisOpen: applied,
      );
      expect(second.nudge, ImeSettleNudgeMode.debounce);
      expect(second.commitLogical, 348.1);

      cached = 348.1;
      applied = false;
      final warm = resolveImeSettleDecision(
        pendingLogical: 296.9,
        committedLogical: 0,
        cachedLogical: cached,
        appliedCacheThisOpen: applied,
      );
      expect(warm.commitLogical, 348.1);
      expect(warm.nudge, ImeSettleNudgeMode.immediate);
    });

    test('已套用缓存后 pending 明显高于 committed 则抬升', () {
      final d = resolveImeSettleDecision(
        pendingLogical: 400,
        committedLogical: 348.1,
        cachedLogical: 348.1,
        appliedCacheThisOpen: true,
      );
      expect(d.commitLogical, 400);
      expect(d.reason, 'raiseCache');
      expect(d.nudge, ImeSettleNudgeMode.immediate);
      expect(d.storeCacheLogical, 400);
    });
  });

  group('shouldArmImeCacheDownCorrect', () {
    test('仅在已套用缓存且 pending 明显更矮时武装', () {
      expect(
        shouldArmImeCacheDownCorrect(
          appliedCacheThisOpen: true,
          pendingLogical: 300,
          committedLogical: 348,
        ),
        isTrue,
      );
      expect(
        shouldArmImeCacheDownCorrect(
          appliedCacheThisOpen: false,
          pendingLogical: 300,
          committedLogical: 348,
        ),
        isFalse,
      );
      expect(
        shouldArmImeCacheDownCorrect(
          appliedCacheThisOpen: true,
          pendingLogical: 348,
          committedLogical: 348,
        ),
        isFalse,
      );
    });
  });

  group('kImeNudgeDebounceDelay', () {
    test('与工具栏静止窗同为 120ms', () {
      expect(kImeNudgeDebounceDelay, kImeToolbarOpenSettleDelay);
      expect(kImeNudgeDebounceDelay.inMilliseconds, 120);
      expect(kImeHeightCachePersistDebounce.inMilliseconds, 300);
    });
  });
}
