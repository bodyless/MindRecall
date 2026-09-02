import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mind_recall/features/memo/editor/widgets/import_backup_dialog.dart';
import 'package:mind_recall/l10n/app_localizations.dart';
import 'package:mind_recall/services/data_backup_service.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('zh'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: child,
    );
  }

  testWidgets('默认选中合并数据，确认返回 merge', (tester) async {
    DataBackupImportMode? picked;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await showDialog<DataBackupImportMode>(
                    context: context,
                    builder: (_) => const ImportBackupDialog(),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('合并数据'), findsOneWidget);
    expect(find.text('覆盖数据'), findsOneWidget);
    expect(
      tester
          .widget<RadioGroup<DataBackupImportMode>>(
            find.byType(RadioGroup<DataBackupImportMode>),
          )
          .groupValue,
      DataBackupImportMode.merge,
    );

    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(picked, DataBackupImportMode.merge);
  });

  testWidgets('选择覆盖后确认返回 overwrite', (tester) async {
    DataBackupImportMode? picked;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            return Scaffold(
              body: TextButton(
                onPressed: () async {
                  picked = await showDialog<DataBackupImportMode>(
                    context: context,
                    builder: (_) => const ImportBackupDialog(),
                  );
                },
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('覆盖数据'));
    await tester.pump();
    await tester.tap(find.text('确定'));
    await tester.pumpAndSettle();
    expect(picked, DataBackupImportMode.overwrite);
  });
}
