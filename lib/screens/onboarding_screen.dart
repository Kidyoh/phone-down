import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../main.dart';
import '../orders.dart';
import '../profile.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_screen.dart';

/// Name and usual order. First launch, and again from the profile chip.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({
    super.key,
    required this.profile,
    this.editing = false,
  });

  final Profile profile;
  final bool editing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  late final _name = TextEditingController(text: widget.profile.name);
  late Order _order = widget.profile.order;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      _focus.requestFocus();
      return;
    }
    HapticFeedback.mediumImpact();
    widget.profile.save(name: name, order: _order);
    if (widget.editing) {
      Navigator.of(context).pop();
    } else {
      Navigator.of(context)
          .pushReplacement(pageRoute(HomeScreen(profile: widget.profile)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    return Scaffold(
      body: Paper(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.fromLTRB(24, pad.top + 20, 24, 24),
                children: [
                  Row(
                    children: [
                      if (widget.editing) ...[
                        RoundIcon(
                          Icons.arrow_back_rounded,
                          label: 'Back',
                          onTap: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 16),
                      ],
                      Expanded(
                        child: Kicker(
                          widget.editing
                              ? 'Your seat'
                              : 'Phone Down · Est. at your table',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text.rich(
                    TextSpan(
                      children: [
                        const TextSpan(text: 'Pull up\na '),
                        TextSpan(
                          text: 'chair.',
                          style: serif(64, italic: true, color: Brew.crema),
                        ),
                      ],
                    ),
                    style: serif(64, height: 0.95),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Everyone puts their phone face down. The first one to pick theirs up buys the coffee.',
                    style: manrope(16, color: Brew.inkSoft, height: 1.45),
                  ),
                  const SizedBox(height: 36),
                  Text('WHAT DOES THE TABLE CALL YOU?', style: kicker()),
                  const SizedBox(height: 4),
                  TextField(
                    controller: _name,
                    focusNode: _focus,
                    autofocus: !widget.editing && widget.profile.name.isEmpty,
                    textCapitalization: TextCapitalization.words,
                    maxLength: 18,
                    style: serif(40),
                    cursorWidth: 2,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => FocusScope.of(context).unfocus(),
                    decoration: InputDecoration(
                      hintText: 'Your name',
                      hintStyle: serif(40, color: Brew.inkFaint, italic: true),
                      counterText: '',
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                      enabledBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Brew.line, width: 1.2),
                      ),
                      focusedBorder: const UnderlineInputBorder(
                        borderSide: BorderSide(color: Brew.ink, width: 1.6),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Text('YOUR USUAL?', style: kicker()),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'what the loser gets you',
                          textAlign: TextAlign.end,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: serif(16, italic: true, color: Brew.inkSoft),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  OrderGrid(
                    selected: _order,
                    onPick: (o) => setState(() => _order = o),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, 8, 24, pad.bottom + 16),
              child: BrewButton(
                widget.editing ? 'Save' : 'Take a seat',
                trailing: _name.text.trim().isEmpty
                    ? null
                    : _order.label.toLowerCase(),
                onTap: _name.text.trim().isEmpty ? null : _save,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ten cups on the counter. Pick one.
class OrderGrid extends StatelessWidget {
  const OrderGrid({super.key, required this.selected, required this.onPick});

  final Order selected;
  final ValueChanged<Order> onPick;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        const cols = 5;
        final w = (box.maxWidth - (cols - 1) * 8) / cols;
        return Wrap(
          spacing: 8,
          runSpacing: 12,
          children: [
            for (final o in Order.values)
              SizedBox(
                width: w,
                child: Pressable(
                  onTap: () => onPick(o),
                  semanticLabel: o.label,
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        padding: const EdgeInsets.all(5),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: o == selected
                                ? Brew.ink
                                : Colors.transparent,
                            width: 1.6,
                          ),
                        ),
                        child: AnimatedScale(
                          scale: o == selected ? 1.06 : 0.94,
                          duration: const Duration(milliseconds: 260),
                          curve: Curves.easeOutBack,
                          child: CupGlyph(o, size: w - 16),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        o.label,
                        maxLines: 1,
                        overflow: TextOverflow.visible,
                        softWrap: false,
                        style: manrope(
                          o.label.length > 9 ? 10 : 11.5,
                          weight: o == selected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          color: o == selected ? Brew.ink : Brew.inkSoft,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
