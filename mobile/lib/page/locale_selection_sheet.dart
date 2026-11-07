import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:vocal/i18n/app_strings.dart';
import 'package:vocal/page/vocal_home_controller.dart';

class LocaleSelectionSheet extends StatefulWidget {
  final VocalHomeController controller;

  const LocaleSelectionSheet({super.key, required this.controller});

  static Future<void> show(BuildContext context, VocalHomeController controller) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => LocaleSelectionSheet(controller: controller),
    );
  }

  @override
  State<LocaleSelectionSheet> createState() => _LocaleSelectionSheetState();
}

class _LocaleSelectionSheetState extends State<LocaleSelectionSheet> {
  final TextEditingController _searchController = TextEditingController();
  String _filterQuery = '';

  VocalHomeController get _ctrl => widget.controller;

  // Preset priority languages with flags
  static const List<Map<String, String>> _commonPresets = [
    {'zhLabel': '普通话 (中国)', 'enLabel': 'Mandarin (China)', 'prefix': 'zh_cn', 'flag': '🇨🇳'},
    {'zhLabel': '粤语 (香港)', 'enLabel': 'Cantonese (HK)', 'prefix': 'zh_hk', 'flag': '🇭🇰'},
    {'zhLabel': '英语 (美国)', 'enLabel': 'English (US)', 'prefix': 'en_us', 'flag': '🇺🇸'},
    {'zhLabel': '英语 (英国)', 'enLabel': 'English (UK)', 'prefix': 'en_gb', 'flag': '🇬🇧'},
    {'zhLabel': '日语 (日本)', 'enLabel': 'Japanese (Japan)', 'prefix': 'ja_jp', 'flag': '🇯🇵'},
    {'zhLabel': '韩语 (韩国)', 'enLabel': 'Korean (Korea)', 'prefix': 'ko_kr', 'flag': '🇰🇷'},
    {'zhLabel': '法语 (法国)', 'enLabel': 'French (France)', 'prefix': 'fr_fr', 'flag': '🇫🇷'},
    {'zhLabel': '德语 (德国)', 'enLabel': 'German (Germany)', 'prefix': 'de_de', 'flag': '🇩🇪'},
    {'zhLabel': '西班牙语', 'enLabel': 'Spanish (Spain)', 'prefix': 'es_es', 'flag': '🇪🇸'},
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _getFlagForLocale(String localeId) {
    final lower = localeId.toLowerCase().replaceAll('-', '_');
    for (final p in _commonPresets) {
      if (lower.contains(p['prefix']!)) {
        return p['flag']!;
      }
    }
    if (lower.startsWith('zh')) return '🇨🇳';
    if (lower.startsWith('en')) return '🇺🇸';
    if (lower.startsWith('ja')) return '🇯🇵';
    if (lower.startsWith('ko')) return '🇰🇷';
    if (lower.startsWith('fr')) return '🇫🇷';
    if (lower.startsWith('de')) return '🇩🇪';
    if (lower.startsWith('es')) return '🇪🇸';
    return '🌐';
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.current;
    final allLocales = _ctrl.availableLocales;
    final filteredLocales = allLocales.where((l) {
      if (_filterQuery.isEmpty) return true;
      final q = _filterQuery.toLowerCase();
      return l.name.toLowerCase().contains(q) ||
          l.localeId.toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: Color(0xFF0F172A),
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: Color(0x2222D3EE), width: 1),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            const SizedBox(height: 12),
            // Drag handle
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        strings.selectSpeechLanguage,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        strings.supportedLanguagesCount(allLocales.length),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close_rounded,
                      color: Colors.white.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Search Box
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF0A0F1C),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.08),
                  ),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.search,
                      size: 18,
                      color: Colors.white.withValues(alpha: 0.3),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white, fontSize: 14),
                        cursorColor: const Color(0xFF22D3EE),
                        onChanged: (val) {
                          setState(() {
                            _filterQuery = val.trim();
                          });
                        },
                        decoration: InputDecoration(
                          hintText: strings.searchLanguageHint,
                          hintStyle: TextStyle(
                            color: Colors.white.withValues(alpha: 0.25),
                            fontSize: 13,
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                      ),
                    ),
                    if (_filterQuery.isNotEmpty)
                      GestureDetector(
                        onTap: () {
                          _searchController.clear();
                          setState(() {
                            _filterQuery = '';
                          });
                        },
                        child: Icon(
                          Icons.clear,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.4),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Quick Preset Chips
            SizedBox(
              height: 34,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                itemCount: _commonPresets.length,
                separatorBuilder: (context, index) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final preset = _commonPresets[index];
                  final matchingLocale = _findLocaleByPrefix(allLocales, preset['prefix']!);
                  final isCurrentSelected = matchingLocale != null &&
                      matchingLocale.localeId == _ctrl.selectedLocaleId;
                  final label = strings.isChinese ? preset['zhLabel']! : preset['enLabel']!;

                  return GestureDetector(
                    onTap: () {
                      if (matchingLocale != null) {
                        HapticFeedback.selectionClick();
                        _ctrl.setLocale(matchingLocale.localeId);
                        Navigator.pop(context);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isCurrentSelected
                            ? const Color(0xFF22D3EE).withValues(alpha: 0.2)
                            : Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isCurrentSelected
                              ? const Color(0xFF22D3EE)
                              : Colors.white.withValues(alpha: 0.08),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(preset['flag']!, style: const TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            label,
                            style: TextStyle(
                              color: isCurrentSelected
                                  ? const Color(0xFF22D3EE)
                                  : Colors.white.withValues(alpha: 0.7),
                              fontSize: 11,
                              fontWeight: isCurrentSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            const Divider(color: Color(0x1AFFFFFF), height: 1),

            // Locales List
            Expanded(
              child: filteredLocales.isEmpty
                  ? Center(
                      child: Text(
                        '未找到匹配的语言',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.3),
                          fontSize: 13,
                        ),
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filteredLocales.length,
                      itemBuilder: (context, index) {
                        final locale = filteredLocales[index];
                        final isSelected = locale.localeId == _ctrl.selectedLocaleId;
                        final flag = _getFlagForLocale(locale.localeId);

                        return Container(
                          margin: const EdgeInsets.only(bottom: 6),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF22D3EE).withValues(alpha: 0.08)
                                : Colors.transparent,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? const Color(0xFF22D3EE).withValues(alpha: 0.3)
                                  : Colors.transparent,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _ctrl.setLocale(locale.localeId);
                              Navigator.pop(context);
                            },
                            dense: true,
                            leading: Container(
                              width: 36,
                              height: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.05),
                                shape: BoxShape.circle,
                              ),
                              child: Text(flag, style: const TextStyle(fontSize: 18)),
                            ),
                            title: Text(
                              locale.name,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.85),
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w400,
                                fontSize: 14,
                              ),
                            ),
                            subtitle: Text(
                              locale.localeId,
                              style: TextStyle(
                                color: isSelected
                                    ? const Color(0xFF22D3EE).withValues(alpha: 0.7)
                                    : Colors.white.withValues(alpha: 0.35),
                                fontSize: 11,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle_rounded,
                                    color: Color(0xFF22D3EE),
                                    size: 20,
                                  )
                                : null,
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

  LocaleName? _findLocaleByPrefix(List<LocaleName> locales, String prefix) {
    final target = prefix.toLowerCase().replaceAll('-', '_');
    for (final l in locales) {
      final id = l.localeId.toLowerCase().replaceAll('-', '_');
      if (id.contains(target)) return l;
    }
    return null;
  }
}
