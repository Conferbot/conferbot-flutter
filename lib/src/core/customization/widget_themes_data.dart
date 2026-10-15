/// The web widget's 27 themes, as data: surfaces and text per scheme, the
/// shape (radii, bubble outline), the theme font and its palette. Generated
/// from conferbot-widget src/css/themes/<id>.css and src/ts/theme/palettes.json
/// (registry.ts order). Colours are hex / rgb(a), or "mix:N:<colour>" (N% of
/// the bot's brand over that colour) and "accent:<alpha>" (the brand lifted
/// for dark surfaces). Do not edit by hand.
library;

class ThemeShapeData {
  final double? rBubble, rTail, rCtl, rField, rCard;
  final double bubbleBorderWidth;
  final String? bubbleBorderColor;
  final int displayWeight;

  const ThemeShapeData(this.rBubble, this.rTail, this.rCtl, this.rField, this.rCard, this.bubbleBorderWidth, this.bubbleBorderColor, this.displayWeight);
}

class WidgetThemeData {
  final String label;
  final String? font;
  final String? fontRole;
  final bool alwaysDark;
  final ThemeShapeData? shape;
  final Map<String, String>? light;
  final Map<String, String> dark;
  final Map<String, String>? paletteLight;
  final Map<String, String>? paletteDark;

  const WidgetThemeData(this.label, this.font, this.fontRole, this.alwaysDark, this.shape, this.light, this.dark, this.paletteLight, this.paletteDark);
}

const Map<String, WidgetThemeData> widgetThemesData = {
  'classic': WidgetThemeData(
    'Classic', null, null, false,
    null,
    null,
    {'bg': '#14161c', 'bg2': '#0e1014', 'card': '#1b1e26', 'card2': '#252a34', 'field': 'rgba(255, 255, 255, 0.06)', 'menu': '#20242d', 'ink': '#f1f3f7', 'text': '#cfd4dd', 'muted': '#98a1b1', 'faint': '#6b7385', 'line': 'rgba(255, 255, 255, 0.08)', 'line2': 'rgba(255, 255, 255, 0.14)'},
    null,
    null,
  ),
  'minimal': WidgetThemeData(
    'Minimal', 'Inter', 'body', false,
    ThemeShapeData(14.0, 14.0, 10.0, 12.0, 12.0, 0.0, null, 600),
    {'bg': '#ffffff', 'bg2': '#fafafa', 'card': '#ffffff', 'card2': '#f4f4f5', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#09090b', 'text': '#3f3f46', 'muted': '#71717a', 'faint': '#a1a1aa', 'line': '#ececef', 'line2': '#e4e4e7'},
    {'bg': '#0a0a0b', 'bg2': '#0a0a0b', 'card': '#111113', 'card2': '#18181b', 'field': '#0a0a0b', 'menu': '#111113', 'ink': '#fafafa', 'text': '#d4d4d8', 'muted': '#a1a1aa', 'faint': '#71717a', 'line': '#1f1f23', 'line2': '#27272a'},
    {'brand': '#2563eb', 'headerBg': '#09090b', 'headerText': '#fafafa', 'botBg': '#f4f4f5', 'botText': '#18181b', 'userBg': '#2563eb', 'userText': '#ffffff', 'optionBg': '#ffffff', 'optionText': '#1d4ed8', 'launcher': '#09090b', 'accent': '#2563eb', 'onAccent': '#ffffff'},
    {'brand': '#3b82f6', 'headerBg': '#18181b', 'headerText': '#fafafa', 'botBg': '#1f1f23', 'botText': '#f4f4f5', 'userBg': '#2563eb', 'userText': '#ffffff', 'optionBg': '#111113', 'optionText': '#93b4fd', 'launcher': '#2563eb', 'accent': '#60a5fa', 'onAccent': '#09090b'},
  ),
  'glass': WidgetThemeData(
    'Glass', 'Manrope', 'body', false,
    ThemeShapeData(20.0, 8.0, 14.0, 18.0, 20.0, 0.0, null, 700),
    {'bg': '#fafbfd', 'bg2': '#fafbfd', 'card': 'rgba(255, 255, 255, 0.66)', 'card2': 'rgba(255, 255, 255, 0.55)', 'field': 'rgba(255, 255, 255, 0.6)', 'menu': 'rgba(255, 255, 255, 0.82)', 'ink': '#111827', 'text': '#2b3445', 'muted': '#566175', 'faint': '#8791a3', 'line': 'rgba(255, 255, 255, 0.55)', 'line2': 'rgba(15, 23, 42, 0.1)'},
    {'bg': '#14171f', 'bg2': '#14171f', 'card': 'rgba(255, 255, 255, 0.07)', 'card2': 'rgba(255, 255, 255, 0.08)', 'field': 'rgba(255, 255, 255, 0.07)', 'menu': 'rgba(30, 34, 46, 0.86)', 'ink': '#f3f5fa', 'text': '#d3d8e2', 'muted': '#a0a8b8', 'faint': '#737c8e', 'line': 'rgba(255, 255, 255, 0.1)', 'line2': 'rgba(255, 255, 255, 0.14)'},
    {'brand': '#64748b', 'headerBg': '#e9edf2', 'headerText': '#111827', 'botBg': '#ffffff', 'botText': '#111827', 'userBg': '#334155', 'userText': '#f8fafc', 'optionBg': '#f1f5f9', 'optionText': '#1e293b', 'launcher': '#334155', 'accent': '#334155', 'onAccent': '#ffffff'},
    {'brand': '#94a3b8', 'headerBg': '#1e2530', 'headerText': '#f1f5f9', 'botBg': '#2a3240', 'botText': '#f1f5f9', 'userBg': '#e2e8f0', 'userText': '#0f172a', 'optionBg': '#1e2530', 'optionText': '#e2e8f0', 'launcher': '#475569', 'accent': '#e2e8f0', 'onAccent': '#0f172a'},
  ),
  'cartoon': WidgetThemeData(
    'Cartoon', 'Fredoka', 'body', false,
    ThemeShapeData(20.0, 18.0, 14.0, 16.0, 18.0, 2.5, '#1b1b1f', 600),
    {'bg': '#fffaf0', 'bg2': '#fff3dc', 'card': '#ffffff', 'card2': '#fff0d1', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#1b1b1f', 'text': '#2c2c33', 'muted': '#5d5d69', 'faint': '#8f8f9b', 'line': 'rgba(27, 27, 31, 0.16)', 'line2': '#1b1b1f'},
    {'bg': '#211e2e', 'bg2': '#1a1725', 'card': '#302b44', 'card2': '#3b3553', 'field': '#302b44', 'menu': '#302b44', 'ink': '#fff8ec', 'text': '#efe6d6', 'muted': '#bdb3cf', 'faint': '#8d84a3', 'line': 'rgba(255, 248, 236, 0.12)', 'line2': '#07060b'},
    {'brand': '#2350e6', 'headerBg': '#2350e6', 'headerText': '#ffffff', 'botBg': '#ffd23f', 'botText': '#1b1b1f', 'userBg': '#d42a20', 'userText': '#ffffff', 'optionBg': '#ffffff', 'optionText': '#1f47d1', 'launcher': '#d42a20', 'accent': '#2350e6', 'onAccent': '#ffffff'},
    {'brand': '#4f74ff', 'headerBg': '#2350e6', 'headerText': '#ffffff', 'botBg': '#ffd23f', 'botText': '#1b1b1f', 'userBg': '#ff6b61', 'userText': '#1b1b1f', 'optionBg': '#302b44', 'optionText': '#ffd23f', 'launcher': '#d42a20', 'accent': '#ffd23f', 'onAccent': '#1b1b1f'},
  ),
  'retro': WidgetThemeData(
    'Retro', 'VT323', 'display', false,
    ThemeShapeData(4.0, 0.0, 2.0, 2.0, 2.0, 0.0, null, 400),
    {'bg': 'mix:4:#f5eedb', 'bg2': 'mix:7:#ede3c7', 'card': '#fbf7ea', 'card2': '#ebe1c5', 'field': '#fffdf6', 'menu': '#fbf7ea', 'ink': '#2a1f14', 'text': '#3e3122', 'muted': '#7a6a55', 'faint': '#a4937a', 'line': 'rgba(42, 31, 20, 0.18)', 'line2': 'rgba(42, 31, 20, 0.45)'},
    {'bg': 'mix:5:#1d150d', 'bg2': 'mix:5:#160f09', 'card': '#2a1e12', 'card2': '#382817', 'field': '#140e08', 'menu': '#2a1e12', 'ink': '#ffcf87', 'text': '#f2c47e', 'muted': '#bf9660', 'faint': '#8c6d45', 'line': 'rgba(255, 207, 135, 0.16)', 'line2': 'rgba(255, 207, 135, 0.4)'},
    {'brand': '#0f7c80', 'headerBg': '#0f5e63', 'headerText': '#ffe7b0', 'botBg': '#d7ecea', 'botText': '#10383b', 'userBg': '#f2b33d', 'userText': '#2a1f14', 'optionBg': '#fff4d6', 'optionText': '#7a4a00', 'launcher': '#0f5e63', 'accent': '#0f5e63', 'onAccent': '#ffffff'},
    {'brand': '#0f7c80', 'headerBg': '#0b2a2c', 'headerText': '#ffb84d', 'botBg': '#13393b', 'botText': '#ffd68a', 'userBg': '#ffb84d', 'userText': '#1d150d', 'optionBg': '#2a1e12', 'optionText': '#ffc766', 'launcher': '#0f5e63', 'accent': '#ffb84d', 'onAccent': '#1d150d'},
  ),
  'soft3d': WidgetThemeData(
    'Soft 3D', 'Nunito', 'body', false,
    ThemeShapeData(20.0, 8.0, 16.0, 20.0, 22.0, 0.0, null, 800),
    {'bg': 'mix:3:#eceff5', 'bg2': 'mix:3:#eceff5', 'card': 'mix:2:#f1f3f8', 'card2': 'mix:3:#e5e9f0', 'field': 'mix:3:#eceff5', 'menu': '#f1f3f8', 'ink': '#1f2635', 'text': '#3a4356', 'muted': '#677186', 'faint': '#98a1b3', 'line': 'rgba(31, 38, 53, 0.06)', 'line2': 'rgba(31, 38, 53, 0.1)'},
    {'bg': '#262a33', 'bg2': '#262a33', 'card': '#2a2e38', 'card2': '#22262e', 'field': '#262a33', 'menu': '#2d313b', 'ink': '#eef1f6', 'text': '#c9cfda', 'muted': '#98a0b0', 'faint': '#6c7486', 'line': 'rgba(255, 255, 255, 0.05)', 'line2': 'rgba(255, 255, 255, 0.09)'},
    {'brand': '#4a6cf7', 'headerBg': '#e3e8f2', 'headerText': '#1f2635', 'botBg': '#f4f6fa', 'botText': '#1f2635', 'userBg': '#3f5fe0', 'userText': '#ffffff', 'optionBg': '#eceff5', 'optionText': '#3350c7', 'launcher': '#3f5fe0', 'accent': '#3f5fe0', 'onAccent': '#ffffff'},
    {'brand': '#5b7cfa', 'headerBg': '#2d323d', 'headerText': '#e6e9f0', 'botBg': '#313744', 'botText': '#e6e9f0', 'userBg': '#3f5fe0', 'userText': '#ffffff', 'optionBg': '#2a2f3a', 'optionText': '#a9bbff', 'launcher': '#3f5fe0', 'accent': '#8aa2ff', 'onAccent': '#0b1020'},
  ),
  'midnight': WidgetThemeData(
    'Midnight', 'Inter', 'body', true,
    ThemeShapeData(16.0, 5.0, 10.0, 14.0, 14.0, 0.0, null, 600),
    {'bg': '#0b0d12', 'bg2': '#08090d', 'card': '#12151c', 'card2': '#1a1e27', 'field': '#12151c', 'menu': '#151922', 'ink': '#eef1f6', 'text': '#c3c9d4', 'muted': '#8b94a4', 'faint': '#5d6576', 'line': 'rgba(255, 255, 255, 0.07)', 'line2': 'rgba(255, 255, 255, 0.12)'},
    {'bg': '#0b0d12', 'bg2': '#08090d', 'card': '#12151c', 'card2': '#1a1e27', 'field': '#12151c', 'menu': '#151922', 'ink': '#eef1f6', 'text': '#c3c9d4', 'muted': '#8b94a4', 'faint': '#5d6576', 'line': 'rgba(255, 255, 255, 0.07)', 'line2': 'rgba(255, 255, 255, 0.12)'},
    {'brand': '#2f6bff', 'headerBg': '#0f1a3a', 'headerText': '#e8eeff', 'botBg': '#141d38', 'botText': '#e6ecff', 'userBg': '#2563eb', 'userText': '#ffffff', 'optionBg': '#10172c', 'optionText': '#7aa7ff', 'launcher': '#2563eb', 'accent': '#4d8dff', 'onAccent': '#050814'},
    {'brand': '#2f6bff', 'headerBg': '#0f1a3a', 'headerText': '#e8eeff', 'botBg': '#141d38', 'botText': '#e6ecff', 'userBg': '#2563eb', 'userText': '#ffffff', 'optionBg': '#10172c', 'optionText': '#7aa7ff', 'launcher': '#2563eb', 'accent': '#4d8dff', 'onAccent': '#050814'},
  ),
  'editorial': WidgetThemeData(
    'Editorial', 'Fraunces', 'display', false,
    ThemeShapeData(4.0, 4.0, 3.0, 4.0, 4.0, 0.0, null, 600),
    {'bg': '#fbf9f4', 'bg2': '#f6f2e9', 'card': '#fffdf8', 'card2': '#f0ebdf', 'field': '#fffdf8', 'menu': '#fffdf8', 'ink': '#1b1814', 'text': '#3b352e', 'muted': '#7a7064', 'faint': '#a79d8f', 'line': 'rgba(27, 24, 20, 0.1)', 'line2': 'rgba(27, 24, 20, 0.2)'},
    {'bg': '#16140f', 'bg2': '#121009', 'card': '#1d1a14', 'card2': '#28241c', 'field': '#1d1a14', 'menu': '#1d1a14', 'ink': '#f4eee3', 'text': '#d9d1c3', 'muted': '#a3998b', 'faint': '#736a5e', 'line': 'rgba(244, 238, 227, 0.1)', 'line2': 'rgba(244, 238, 227, 0.18)'},
    {'brand': '#9b1c1c', 'headerBg': '#1b1814', 'headerText': '#fbf9f4', 'botBg': '#f1ece1', 'botText': '#1b1814', 'userBg': '#9b1c1c', 'userText': '#ffffff', 'optionBg': '#fffdf8', 'optionText': '#9b1c1c', 'launcher': '#9b1c1c', 'accent': '#9b1c1c', 'onAccent': '#ffffff'},
    {'brand': '#c43a3a', 'headerBg': '#1d1a14', 'headerText': '#f3ede0', 'botBg': '#24201a', 'botText': '#ece5d6', 'userBg': '#b32d2d', 'userText': '#ffffff', 'optionBg': '#1d1a14', 'optionText': '#f08a7e', 'launcher': '#9b1c1c', 'accent': '#e0625a', 'onAccent': '#16140f'},
  ),
  'terminal': WidgetThemeData(
    'Terminal', 'JetBrains Mono', 'body', false,
    ThemeShapeData(0.0, 0.0, 3.0, 4.0, 4.0, 0.0, null, 700),
    {'bg': '#f3f1e9', 'bg2': '#eaece2', 'card': '#ecede4', 'card2': '#e1e7db', 'field': '#f3f1e9', 'menu': '#f3f1e9', 'ink': 'rgb(21, 110, 52)', 'text': 'rgba(21, 110, 52, 0.92)', 'muted': 'rgba(21, 110, 52, 0.68)', 'faint': 'rgba(21, 110, 52, 0.45)', 'line': 'rgba(21, 110, 52, 0.18)', 'line2': 'rgba(21, 110, 52, 0.35)'},
    {'bg': '#060907', 'bg2': '#0a130d', 'card': '#09100b', 'card2': '#0e1d12', 'field': '#060907', 'menu': '#060907', 'ink': 'rgb(110, 255, 150)', 'text': 'rgba(110, 255, 150, 0.92)', 'muted': 'rgba(110, 255, 150, 0.68)', 'faint': 'rgba(110, 255, 150, 0.45)', 'line': 'rgba(110, 255, 150, 0.18)', 'line2': 'rgba(110, 255, 150, 0.35)'},
    {'brand': '#156e34', 'headerBg': '#10231a', 'headerText': '#7dffa8', 'botBg': '#eaf1e6', 'botText': '#156e34', 'userBg': '#f3f1e9', 'userText': '#161a16', 'optionBg': '#f3f1e9', 'optionText': '#156e34', 'launcher': '#10231a', 'accent': '#156e34', 'onAccent': '#ffffff'},
    {'brand': '#22c55e', 'headerBg': '#07120a', 'headerText': '#6eff96', 'botBg': '#0b160e', 'botText': '#6eff96', 'userBg': '#060907', 'userText': '#eafff0', 'optionBg': '#0b160e', 'optionText': '#6eff96', 'launcher': '#0c2a15', 'accent': '#6eff96', 'onAccent': '#060907'},
  ),
  'aurora': WidgetThemeData(
    'Aurora', 'Plus Jakarta Sans', 'body', false,
    ThemeShapeData(20.0, 7.0, 14.0, 18.0, 20.0, 0.0, null, 800),
    {'bg': '#f7f7fc', 'bg2': '#f7f7fc', 'card': 'rgba(255, 255, 255, 0.78)', 'card2': 'rgba(255, 255, 255, 0.7)', 'field': 'rgba(255, 255, 255, 0.72)', 'menu': 'rgba(255, 255, 255, 0.92)', 'ink': '#141526', 'text': '#34364d', 'muted': '#666a86', 'faint': '#9a9db5', 'line': 'rgba(20, 21, 38, 0.07)', 'line2': 'rgba(20, 21, 38, 0.11)'},
    {'bg': '#0c0d18', 'bg2': '#0c0d18', 'card': 'rgba(255, 255, 255, 0.06)', 'card2': 'rgba(255, 255, 255, 0.07)', 'field': 'rgba(255, 255, 255, 0.06)', 'menu': 'rgba(24, 25, 44, 0.95)', 'ink': '#f2f2fb', 'text': '#cfd0e3', 'muted': '#9c9eb9', 'faint': '#6c6e8a', 'line': 'rgba(255, 255, 255, 0.08)', 'line2': 'rgba(255, 255, 255, 0.13)'},
    {'brand': '#7c3aed', 'headerBg': '#6d28d9', 'headerText': '#ffffff', 'botBg': '#f3efff', 'botText': '#3b1a7a', 'userBg': '#6d28d9', 'userText': '#ffffff', 'optionBg': '#e6fbf8', 'optionText': '#0f5f58', 'launcher': '#7c3aed', 'launcher2': '#0d9488', 'accent': '#6d28d9', 'onAccent': '#ffffff'},
    {'brand': '#8b5cf6', 'headerBg': '#4c1d95', 'headerText': '#f5f3ff', 'botBg': '#1e1a3a', 'botText': '#ede9fe', 'userBg': '#6d28d9', 'userText': '#ffffff', 'optionBg': '#0f2a2e', 'optionText': '#5eead4', 'launcher': '#7c3aed', 'launcher2': '#0d9488', 'accent': '#a78bfa', 'onAccent': '#0c0d18'},
  ),
  'neobrutal': WidgetThemeData(
    'Neo-brutal', 'Space Grotesk', 'body', false,
    ThemeShapeData(6.0, 0.0, 6.0, 6.0, 6.0, 2.0, '#000000', 700),
    {'bg': '#fffdf5', 'bg2': '#fff6d9', 'card': '#ffffff', 'card2': '#fff1c2', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#000000', 'text': '#1a1a1a', 'muted': '#4a4a4a', 'faint': '#7a7a7a', 'line': '#000000', 'line2': '#000000'},
    {'bg': '#121212', 'bg2': '#0b0b0b', 'card': '#1c1c1c', 'card2': '#2a2a2a', 'field': '#1c1c1c', 'menu': '#1c1c1c', 'ink': '#f4f1e8', 'text': '#e6e2d6', 'muted': '#b5b1a6', 'faint': '#8a877e', 'line': '#f4f1e8', 'line2': '#f4f1e8'},
    {'brand': '#ffd400', 'headerBg': '#ffd400', 'headerText': '#000000', 'botBg': '#ffffff', 'botText': '#000000', 'userBg': '#000000', 'userText': '#ffd400', 'optionBg': '#ffd400', 'optionText': '#000000', 'launcher': '#000000', 'accent': '#000000', 'onAccent': '#ffd400'},
    {'brand': '#ffd400', 'headerBg': '#ffd400', 'headerText': '#000000', 'botBg': '#1e1e1e', 'botText': '#f5f5f5', 'userBg': '#ffd400', 'userText': '#000000', 'optionBg': '#121212', 'optionText': '#ffd400', 'launcher': '#000000', 'accent': '#ffd400', 'onAccent': '#000000'},
  ),
  'pastel': WidgetThemeData(
    'Pastel', 'Quicksand', 'body', false,
    ThemeShapeData(22.0, 10.0, 999.0, 999.0, 24.0, 0.0, null, 700),
    {'bg': 'mix:5:#fffbfd', 'bg2': 'mix:8:#fff7fb', 'card': '#ffffff', 'card2': 'mix:10:#fdf8ff', 'field': 'mix:7:#ffffff', 'menu': '#ffffff', 'ink': 'mix:22:#2c2638', 'text': 'mix:18:#4a4458', 'muted': 'mix:20:#817a91', 'faint': 'mix:20:#b3adc2', 'line': 'mix:14:rgba(44, 38, 56, 0.06)', 'line2': 'mix:22:rgba(44, 38, 56, 0.1)'},
    {'bg': 'mix:10:#1d1a24', 'bg2': 'mix:8:#18151f', 'card': 'mix:10:#25212e', 'card2': 'mix:16:#2c2737', 'field': 'mix:12:#25212e', 'menu': 'mix:12:#292433', 'ink': '#f6f0fb', 'text': '#ddd5e6', 'muted': '#a99fb8', 'faint': '#776e87', 'line': 'rgba(255, 240, 255, 0.07)', 'line2': 'rgba(255, 240, 255, 0.12)'},
    {'brand': '#f472b6', 'headerBg': '#f9a8d4', 'headerText': '#500724', 'botBg': '#e0f2fe', 'botText': '#1e3a5f', 'userBg': '#fbcfe8', 'userText': '#5b1a44', 'optionBg': '#ede9fe', 'optionText': '#4c2a85', 'launcher': '#a855f7', 'accent': '#9d2a8a', 'onAccent': '#ffffff'},
    {'brand': '#f472b6', 'headerBg': '#6b2d57', 'headerText': '#fde7f3', 'botBg': '#1f3244', 'botText': '#dbeafe', 'userBg': '#f9a8d4', 'userText': '#3b0a2a', 'optionBg': '#2e2440', 'optionText': '#d8c7ff', 'launcher': '#a855f7', 'accent': '#f9a8d4', 'onAccent': '#3b0a2a'},
  ),
  'neon': WidgetThemeData(
    'Neon', 'Orbitron', 'display', true,
    ThemeShapeData(14.0, 3.0, 8.0, 10.0, 12.0, 0.0, null, 700),
    {'bg': '#07070c', 'bg2': '#050509', 'card': '#0e0e16', 'card2': '#15151f', 'field': '#0b0b12', 'menu': '#0e0e16', 'ink': '#eef0ff', 'text': '#c7cae6', 'muted': '#8b8fb1', 'faint': '#5c5f7c', 'line': 'accent:0.16', 'line2': 'accent:0.3'},
    {'bg': '#07070c', 'bg2': '#050509', 'card': '#0e0e16', 'card2': '#15151f', 'field': '#0b0b12', 'menu': '#0e0e16', 'ink': '#eef0ff', 'text': '#c7cae6', 'muted': '#8b8fb1', 'faint': '#5c5f7c', 'line': 'accent:0.16', 'line2': 'accent:0.3'},
    {'brand': '#22e5ff', 'headerBg': '#0b0b14', 'headerText': '#22e5ff', 'botBg': '#12121f', 'botText': '#e9ecff', 'userBg': '#ff2bd6', 'userText': '#07070c', 'optionBg': '#07070c', 'optionText': '#22e5ff', 'launcher': '#c026d3', 'launcher2': '#0891b2', 'accent': '#22e5ff', 'onAccent': '#07070c'},
    {'brand': '#22e5ff', 'headerBg': '#0b0b14', 'headerText': '#22e5ff', 'botBg': '#12121f', 'botText': '#e9ecff', 'userBg': '#ff2bd6', 'userText': '#07070c', 'optionBg': '#07070c', 'optionText': '#22e5ff', 'launcher': '#c026d3', 'launcher2': '#0891b2', 'accent': '#22e5ff', 'onAccent': '#07070c'},
  ),
  'sketch': WidgetThemeData(
    'Sketch', 'Patrick Hand', 'display', false,
    ThemeShapeData(16.0, 4.0, 10.0, 12.0, 12.0, 2.0, '#26262b', 400),
    {'bg': '#fdfbf5', 'bg2': '#f8f4e9', 'card': '#fffef9', 'card2': '#f3eedf', 'field': '#fffef9', 'menu': '#fffef9', 'ink': '#26262b', 'text': '#3a3a40', 'muted': '#6b6a70', 'faint': '#9c9aa0', 'line': 'rgba(38, 38, 43, 0.25)', 'line2': 'rgba(38, 38, 43, 0.75)'},
    {'bg': '#1f2421', 'bg2': '#1a1f1c', 'card': '#252b27', 'card2': '#2d342f', 'field': '#252b27', 'menu': '#252b27', 'ink': '#ecebe4', 'text': '#d8d7cf', 'muted': '#a6a59c', 'faint': '#75756d', 'line': 'rgba(236, 235, 228, 0.22)', 'line2': 'rgba(236, 235, 228, 0.7)'},
    {'brand': '#26262b', 'headerBg': '#26262b', 'headerText': '#fdfbf5', 'botBg': '#fffef9', 'botText': '#26262b', 'userBg': '#2b4c9b', 'userText': '#ffffff', 'optionBg': '#fdfbf5', 'optionText': '#26262b', 'launcher': '#26262b', 'accent': '#2b4c9b', 'onAccent': '#ffffff'},
    {'brand': '#e8e4d8', 'headerBg': '#1f2a24', 'headerText': '#f4f1e8', 'botBg': '#26332c', 'botText': '#f4f1e8', 'userBg': '#f4f1e8', 'userText': '#1f2a24', 'optionBg': '#1f2a24', 'optionText': '#f4f1e8', 'launcher': '#2f3d35', 'accent': '#f4f1e8', 'onAccent': '#1f2a24'},
  ),
  'luxe': WidgetThemeData(
    'Luxe', 'Cormorant Garamond', 'display', false,
    ThemeShapeData(3.0, 3.0, 2.0, 2.0, 2.0, 0.0, null, 600),
    {'bg': '#fbf8f1', 'bg2': '#f6f1e5', 'card': '#fffdf8', 'card2': '#f2ecdd', 'field': '#fffdf8', 'menu': '#fffdf8', 'ink': '#1a1712', 'text': '#3e382e', 'muted': '#7c7262', 'faint': '#ab9f8b', 'line': 'rgba(168, 132, 80, 0.22)', 'line2': 'rgba(168, 132, 80, 0.45)'},
    {'bg': '#0c0b09', 'bg2': '#080706', 'card': '#13110d', 'card2': '#1c1914', 'field': '#13110d', 'menu': '#13110d', 'ink': '#f3ecdc', 'text': '#d9d0bd', 'muted': '#a39781', 'faint': '#6f6555', 'line': 'rgba(201, 168, 106, 0.22)', 'line2': 'rgba(201, 168, 106, 0.5)'},
    {'brand': '#a88450', 'headerBg': '#14110c', 'headerText': '#e9d5a8', 'botBg': '#fffdf8', 'botText': '#14110c', 'userBg': '#14110c', 'userText': '#f2ead8', 'optionBg': '#fbf8f1', 'optionText': '#7a5c2e', 'launcher': '#14110c', 'accent': '#8a6a35', 'onAccent': '#ffffff'},
    {'brand': '#c9a86a', 'headerBg': '#0c0b09', 'headerText': '#d8b87a', 'botBg': '#16140f', 'botText': '#f2ead8', 'userBg': '#c9a86a', 'userText': '#0c0b09', 'optionBg': '#0c0b09', 'optionText': '#d8b87a', 'launcher': '#14110c', 'accent': '#d8b87a', 'onAccent': '#0c0b09'},
  ),
  'clay': WidgetThemeData(
    'Clay', 'Baloo 2', 'body', false,
    ThemeShapeData(24.0, 10.0, 20.0, 24.0, 28.0, 0.0, null, 800),
    {'bg': 'mix:12:#f4f0ff', 'bg2': 'mix:14:#efeaff', 'card': 'mix:5:#fcfbff', 'card2': 'mix:18:#f2eeff', 'field': 'mix:5:#fcfbff', 'menu': 'mix:5:#fcfbff', 'ink': 'mix:25:#221c33', 'text': 'mix:20:#413a52', 'muted': 'mix:22:#776f88', 'faint': 'mix:22:#aaa3bb', 'line': 'mix:18:rgba(34, 28, 51, 0.05)', 'line2': 'mix:25:rgba(34, 28, 51, 0.09)'},
    {'bg': 'mix:14:#221d30', 'bg2': 'mix:12:#1d1929', 'card': 'mix:12:#2e2842', 'card2': 'mix:20:#362f4d', 'field': 'mix:10:#2a2440', 'menu': 'mix:12:#2e2842', 'ink': '#f5f1ff', 'text': '#dcd5ec', 'muted': '#a79fbb', 'faint': '#776f8c', 'line': 'rgba(255, 245, 255, 0.07)', 'line2': 'rgba(255, 245, 255, 0.12)'},
    {'brand': '#8b6cff', 'headerBg': '#6246ea', 'headerText': '#ffffff', 'botBg': '#ffe08a', 'botText': '#3d2a00', 'userBg': '#ff8fab', 'userText': '#3a0a17', 'optionBg': '#a5f3d0', 'optionText': '#064e3b', 'launcher': '#6246ea', 'accent': '#6246ea', 'onAccent': '#ffffff'},
    {'brand': '#8b6cff', 'headerBg': '#5b3fd9', 'headerText': '#ffffff', 'botBg': '#3a2f5c', 'botText': '#f1ecff', 'userBg': '#ff8fab', 'userText': '#3a0a17', 'optionBg': '#1f4a3d', 'optionText': '#a5f3d0', 'launcher': '#6246ea', 'accent': '#b9a6ff', 'onAccent': '#221d30'},
  ),
  'nature': WidgetThemeData(
    'Nature', 'Lora', 'display', false,
    ThemeShapeData(20.0, 8.0, 16.0, 20.0, 22.0, 0.0, null, 600),
    {'bg': '#f6f2e8', 'bg2': '#f1ecdf', 'card': '#fbf8f1', 'card2': 'mix:10:#dfe7d2', 'field': '#fbf8f1', 'menu': '#fbf8f1', 'ink': '#2b2a22', 'text': '#4a473b', 'muted': '#7a7563', 'faint': '#a8a290', 'line': 'rgba(74, 71, 59, 0.12)', 'line2': 'rgba(74, 71, 59, 0.2)'},
    {'bg': '#1a1f18', 'bg2': '#161a14', 'card': '#222820', 'card2': 'mix:8:#2c3527', 'field': '#222820', 'menu': '#222820', 'ink': '#ece8dc', 'text': '#d2cdbd', 'muted': '#a09a88', 'faint': '#716c5d', 'line': 'rgba(236, 232, 220, 0.08)', 'line2': 'rgba(236, 232, 220, 0.14)'},
    {'brand': '#5b7a55', 'headerBg': '#2f4a36', 'headerText': '#f6f2e8', 'botBg': '#e3eadb', 'botText': '#24331f', 'userBg': '#4f6b45', 'userText': '#ffffff', 'optionBg': '#fbf8f1', 'optionText': '#2f4a36', 'launcher': '#2f4a36', 'accent': '#3d5c3a', 'onAccent': '#ffffff'},
    {'brand': '#7d9a6f', 'headerBg': '#22301f', 'headerText': '#e9efd9', 'botBg': '#263322', 'botText': '#e6ecd8', 'userBg': '#a3b98f', 'userText': '#1a1f18', 'optionBg': '#1f271c', 'optionText': '#b8cfa2', 'launcher': '#3d5c3a', 'accent': '#a3c18a', 'onAccent': '#1a1f18'},
  ),
  'comic': WidgetThemeData(
    'Comic', 'Bangers', 'display', false,
    ThemeShapeData(22.0, 22.0, 4.0, 12.0, 12.0, 2.5, '#111111', 400),
    {'bg': '#fff8e1', 'bg2': '#fff1c7', 'card': '#ffffff', 'card2': '#fff1c7', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#111111', 'text': '#26221a', 'muted': '#5c5445', 'faint': '#8f8574', 'line': 'rgba(17, 17, 17, 0.16)', 'line2': '#111111'},
    {'bg': '#16163a', 'bg2': '#111130', 'card': '#23234a', 'card2': '#2d2d5c', 'field': '#23234a', 'menu': '#23234a', 'ink': '#fffbea', 'text': '#f1ecd8', 'muted': '#c4bfdc', 'faint': '#8e89ad', 'line': 'rgba(255, 251, 234, 0.14)', 'line2': '#05050c'},
    {'brand': '#e3122b', 'headerBg': '#d7141e', 'headerText': '#ffffff', 'botBg': '#ffffff', 'botText': '#111111', 'userBg': '#ffd400', 'userText': '#111111', 'optionBg': '#ffffff', 'optionText': '#c01018', 'launcher': '#d7141e', 'accent': '#111111', 'onAccent': '#ffd400'},
    {'brand': '#ff4757', 'headerBg': '#d7141e', 'headerText': '#ffffff', 'botBg': '#23234a', 'botText': '#ffffff', 'userBg': '#ffd400', 'userText': '#111111', 'optionBg': '#15152e', 'optionText': '#ffd400', 'launcher': '#d7141e', 'accent': '#ffd400', 'onAccent': '#111111'},
  ),
  'arcade': WidgetThemeData(
    'Arcade', 'Press Start 2P', 'display', false,
    ThemeShapeData(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, null, 400),
    {'bg': '#c4cfa1', 'bg2': '#b9c592', 'card': '#d6dfb4', 'card2': '#b3bf8a', 'field': '#d6dfb4', 'menu': '#d6dfb4', 'ink': '#0f2a0f', 'text': '#1c3a1c', 'muted': '#2f4a26', 'faint': '#5d7250', 'line': 'rgba(15, 42, 15, 0.22)', 'line2': 'rgba(15, 42, 15, 0.55)'},
    {'bg': '#0b0b16', 'bg2': '#080812', 'card': '#16142b', 'card2': '#1f1c3a', 'field': '#100f22', 'menu': '#16142b', 'ink': '#f1f0ff', 'text': '#d9d7f5', 'muted': '#a9a6d2', 'faint': '#6e6b99', 'line': 'rgba(123, 108, 246, 0.22)', 'line2': 'rgba(123, 108, 246, 0.55)'},
    {'brand': '#306230', 'headerBg': '#0f380f', 'headerText': '#cadc9f', 'botBg': '#b4c77f', 'botText': '#0f380f', 'userBg': '#306230', 'userText': '#e0f0c0', 'optionBg': '#e0ebc0', 'optionText': '#1e4d1e', 'launcher': '#306230', 'accent': '#0f380f', 'onAccent': '#cadc9f'},
    {'brand': '#3dffb5', 'headerBg': '#1a1033', 'headerText': '#ffe14d', 'botBg': '#1f1a3d', 'botText': '#f1f0ff', 'userBg': '#ff3d7f', 'userText': '#0b0b16', 'optionBg': '#0b0b16', 'optionText': '#3dffb5', 'launcher': '#c2185b', 'accent': '#3dffb5', 'onAccent': '#0b0b16'},
  ),
  'vaporwave': WidgetThemeData(
    'Vaporwave', 'Righteous', 'display', false,
    ThemeShapeData(16.0, 4.0, 999.0, 999.0, 14.0, 0.0, null, 400),
    {'bg': '#fdf0ff', 'bg2': '#f6e6ff', 'card': '#ffffff', 'card2': '#f1e2ff', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#2b0f54', 'text': '#3d1d63', 'muted': '#684888', 'faint': '#a58bc0', 'line': 'rgba(107, 40, 170, 0.14)', 'line2': 'rgba(107, 40, 170, 0.28)'},
    {'bg': '#14022e', 'bg2': '#0f0124', 'card': '#22093f', 'card2': '#2e0f52', 'field': '#1b0536', 'menu': '#22093f', 'ink': '#fde7ff', 'text': '#efd6ff', 'muted': '#c7a6e6', 'faint': '#8c6bb0', 'line': 'rgba(255, 79, 176, 0.18)', 'line2': 'rgba(255, 79, 176, 0.34)'},
    {'brand': '#c2187a', 'headerBg': '#2b0f54', 'headerText': '#ffe3f9', 'botBg': '#ffffff', 'botText': '#3b0a57', 'userBg': '#c2187a', 'userText': '#ffffff', 'optionBg': '#e6fbff', 'optionText': '#006a7a', 'launcher': '#d6246e', 'launcher2': '#6d28d9', 'accent': '#c2187a', 'onAccent': '#ffffff'},
    {'brand': '#ff5fb0', 'headerBg': '#14022e', 'headerText': '#7cf7ff', 'botBg': '#2a1150', 'botText': '#fde7ff', 'userBg': '#ff5fb0', 'userText': '#1a0026', 'optionBg': '#16062e', 'optionText': '#7cf7ff', 'launcher': '#d6246e', 'launcher2': '#6d28d9', 'accent': '#7cf7ff', 'onAccent': '#14022e'},
  ),
  'y2k': WidgetThemeData(
    'Y2K', 'Unbounded', 'display', false,
    ThemeShapeData(22.0, 8.0, 999.0, 999.0, 22.0, 0.0, null, 600),
    {'bg': '#f6f4ff', 'bg2': '#efeaff', 'card': '#ffffff', 'card2': '#efeaff', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#221c47', 'text': '#3a3366', 'muted': '#5d5690', 'faint': '#9a94c4', 'line': 'rgba(90, 70, 190, 0.12)', 'line2': 'rgba(90, 70, 190, 0.24)'},
    {'bg': '#0e0b22', 'bg2': '#0a081a', 'card': '#1b1636', 'card2': '#262048', 'field': '#161230', 'menu': '#1b1636', 'ink': '#f3f0ff', 'text': '#ddd7fb', 'muted': '#aea6dc', 'faint': '#726a9f', 'line': 'rgba(184, 166, 255, 0.14)', 'line2': 'rgba(184, 166, 255, 0.26)'},
    {'brand': '#6d4aff', 'headerBg': '#5b3fe0', 'headerText': '#ffffff', 'botBg': '#ffffff', 'botText': '#2a2350', 'userBg': '#3a5bd9', 'userText': '#ffffff', 'optionBg': '#f3e8ff', 'optionText': '#6b21a8', 'launcher': '#7b3fe4', 'launcher2': '#c0267e', 'accent': '#5b3fe0', 'onAccent': '#ffffff'},
    {'brand': '#9d86ff', 'headerBg': '#1b1636', 'headerText': '#e9e3ff', 'botBg': '#262048', 'botText': '#f3f0ff', 'userBg': '#8f7bff', 'userText': '#0e0b22', 'optionBg': '#120f26', 'optionText': '#c4b5fd', 'launcher': '#7b3fe4', 'launcher2': '#c0267e', 'accent': '#b8a6ff', 'onAccent': '#0e0b22'},
  ),
  'memphis': WidgetThemeData(
    'Memphis', 'Bungee', 'display', false,
    ThemeShapeData(18.0, 3.0, 999.0, 14.0, 14.0, 2.5, '#1d1d1b', 400),
    {'bg': '#fffaf0', 'bg2': '#fff3d6', 'card': '#ffffff', 'card2': '#ffeec2', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#1d1d1b', 'text': '#2e2e2b', 'muted': '#57554e', 'faint': '#8d8a80', 'line': 'rgba(29, 29, 27, 0.14)', 'line2': '#1d1d1b'},
    {'bg': '#16161f', 'bg2': '#111118', 'card': '#262636', 'card2': '#30304a', 'field': '#1d1d29', 'menu': '#262636', 'ink': '#fff6d8', 'text': '#f1e8cc', 'muted': '#c9c2ab', 'faint': '#8b8676', 'line': 'rgba(255, 246, 216, 0.14)', 'line2': '#fff6d8'},
    {'brand': '#2b2bd6', 'headerBg': '#2b2bd6', 'headerText': '#ffffff', 'botBg': '#fff3c4', 'botText': '#1d1d1b', 'userBg': '#e11d74', 'userText': '#ffffff', 'optionBg': '#ffffff', 'optionText': '#2b2bd6', 'launcher': '#e11d74', 'accent': '#2b2bd6', 'onAccent': '#ffffff'},
    {'brand': '#7ee3ff', 'headerBg': '#2b2bd6', 'headerText': '#ffffff', 'botBg': '#262636', 'botText': '#fff6d8', 'userBg': '#ffd400', 'userText': '#1d1d1b', 'optionBg': '#16161f', 'optionText': '#7ee3ff', 'launcher': '#e11d74', 'accent': '#ffd400', 'onAccent': '#16161f'},
  ),
  'sticky': WidgetThemeData(
    'Sticky Notes', 'Permanent Marker', 'display', false,
    ThemeShapeData(3.0, 3.0, 3.0, 4.0, 3.0, 0.0, null, 400),
    {'bg': '#d8b98e', 'bg2': '#d3b387', 'card': '#fffdf6', 'card2': '#f4ecd8', 'field': '#fffdf6', 'menu': '#fffdf6', 'ink': '#2b2111', 'text': '#3a2c17', 'muted': '#4f3c22', 'faint': '#7a6546', 'line': 'rgba(60, 40, 15, 0.16)', 'line2': 'rgba(60, 40, 15, 0.3)'},
    {'bg': '#4a3826', 'bg2': '#433220', 'card': '#5a4631', 'card2': '#66513a', 'field': '#5a4631', 'menu': '#5a4631', 'ink': '#fff4e0', 'text': '#f5e7cd', 'muted': '#e3cfad', 'faint': '#b39c79', 'line': 'rgba(255, 244, 224, 0.14)', 'line2': 'rgba(255, 244, 224, 0.26)'},
    {'brand': '#d97706', 'headerBg': '#ffe45c', 'headerText': '#2b2111', 'botBg': '#fff7a8', 'botText': '#2b2111', 'userBg': '#ffc2da', 'userText': '#4a0d2a', 'optionBg': '#c6ecff', 'optionText': '#0b3a5c', 'launcher': '#c2410c', 'accent': '#2b2111', 'onAccent': '#fff27a'},
    {'brand': '#f59e0b', 'headerBg': '#ffe45c', 'headerText': '#2b2111', 'botBg': '#fff7a8', 'botText': '#2b2111', 'userBg': '#ffc2da', 'userText': '#4a0d2a', 'optionBg': '#c6ecff', 'optionText': '#0b3a5c', 'launcher': '#b45309', 'accent': '#ffe45c', 'onAccent': '#2b2111'},
  ),
  'chalkboard': WidgetThemeData(
    'Chalkboard', 'Cabin Sketch', 'display', true,
    ThemeShapeData(16.0, 5.0, 10.0, 10.0, 12.0, 2.0, 'rgba(244, 241, 228, 0.82)', 700),
    {'bg': '#23392f', 'bg2': '#1f332a', 'card': '#2c4a3d', 'card2': '#345646', 'field': '#1d3128', 'menu': '#2c4a3d', 'ink': '#f4f1e4', 'text': '#e6e2d0', 'muted': '#bfc9b7', 'faint': '#8fa293', 'line': 'rgba(244, 241, 228, 0.16)', 'line2': 'rgba(244, 241, 228, 0.34)'},
    {'bg': '#23392f', 'bg2': '#1f332a', 'card': '#2c4a3d', 'card2': '#345646', 'field': '#1d3128', 'menu': '#2c4a3d', 'ink': '#f4f1e4', 'text': '#e6e2d0', 'muted': '#bfc9b7', 'faint': '#8fa293', 'line': 'rgba(244, 241, 228, 0.16)', 'line2': 'rgba(244, 241, 228, 0.34)'},
    {'brand': '#3f7a5a', 'headerBg': '#1e3a2f', 'headerText': '#f4f1e4', 'botBg': '#2c4a3d', 'botText': '#f4f1e4', 'userBg': '#f3e39a', 'userText': '#1f2d27', 'optionBg': '#1b3128', 'optionText': '#f7e27a', 'launcher': '#2f6b4f', 'accent': '#f3e39a', 'onAccent': '#1b3128'},
    {'brand': '#3f7a5a', 'headerBg': '#1e3a2f', 'headerText': '#f4f1e4', 'botBg': '#2c4a3d', 'botText': '#f4f1e4', 'userBg': '#f3e39a', 'userText': '#1f2d27', 'optionBg': '#1b3128', 'optionText': '#f7e27a', 'launcher': '#2f6b4f', 'accent': '#f3e39a', 'onAccent': '#1b3128'},
  ),
  'bubblegum': WidgetThemeData(
    'Bubblegum', 'Chewy', 'display', false,
    ThemeShapeData(24.0, 8.0, 999.0, 999.0, 24.0, 0.0, null, 400),
    {'bg': '#fff0f7', 'bg2': '#ffe4f1', 'card': '#ffffff', 'card2': '#ffe0ef', 'field': '#ffffff', 'menu': '#ffffff', 'ink': '#5a0d31', 'text': '#6e1a43', 'muted': '#8f3862', 'faint': '#c47ea0', 'line': 'rgba(208, 38, 111, 0.12)', 'line2': 'rgba(208, 38, 111, 0.24)'},
    {'bg': '#2a0f1f', 'bg2': '#230b19', 'card': '#3d1631', 'card2': '#4a1c3c', 'field': '#33122a', 'menu': '#3d1631', 'ink': '#ffe6f3', 'text': '#fbd3e8', 'muted': '#e2a3c4', 'faint': '#a86a8b', 'line': 'rgba(255, 140, 198, 0.16)', 'line2': 'rgba(255, 140, 198, 0.3)'},
    {'brand': '#ff4fa3', 'headerBg': '#d0266f', 'headerText': '#ffffff', 'botBg': '#ffffff', 'botText': '#6b0f3a', 'userBg': '#ff8cc6', 'userText': '#4a0426', 'optionBg': '#ffe0f0', 'optionText': '#a3134f', 'launcher': '#e0287a', 'launcher2': '#a21caf', 'accent': '#d0266f', 'onAccent': '#ffffff'},
    {'brand': '#ff8cc6', 'headerBg': '#3a1230', 'headerText': '#ffc2e2', 'botBg': '#3d1631', 'botText': '#ffe6f3', 'userBg': '#ff7ab8', 'userText': '#2a0019', 'optionBg': '#2a0f1f', 'optionText': '#ff9fcf', 'launcher': '#e0287a', 'launcher2': '#a21caf', 'accent': '#ff8cc6', 'onAccent': '#2a0019'},
  ),
  'cyberpunk': WidgetThemeData(
    'Cyberpunk', 'Chakra Petch', 'body', true,
    ThemeShapeData(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, null, 700),
    {'bg': '#0a0a0f', 'bg2': '#07070b', 'card': '#12121a', 'card2': '#1a1a26', 'field': '#0d0d14', 'menu': '#12121a', 'ink': '#e6f7ff', 'text': '#c9dbe6', 'muted': '#8fa3b3', 'faint': '#5a6b78', 'line': 'rgba(0, 240, 255, 0.14)', 'line2': 'rgba(0, 240, 255, 0.3)'},
    {'bg': '#0a0a0f', 'bg2': '#07070b', 'card': '#12121a', 'card2': '#1a1a26', 'field': '#0d0d14', 'menu': '#12121a', 'ink': '#e6f7ff', 'text': '#c9dbe6', 'muted': '#8fa3b3', 'faint': '#5a6b78', 'line': 'rgba(0, 240, 255, 0.14)', 'line2': 'rgba(0, 240, 255, 0.3)'},
    {'brand': '#fcee0a', 'headerBg': '#0d0d12', 'headerText': '#fcee0a', 'botBg': '#15151e', 'botText': '#e6f7ff', 'userBg': '#fcee0a', 'userText': '#0d0d12', 'optionBg': '#0d0d12', 'optionText': '#00f0ff', 'launcher': '#c2185b', 'accent': '#fcee0a', 'onAccent': '#0d0d12'},
    {'brand': '#fcee0a', 'headerBg': '#0d0d12', 'headerText': '#fcee0a', 'botBg': '#15151e', 'botText': '#e6f7ff', 'userBg': '#fcee0a', 'userText': '#0d0d12', 'optionBg': '#0d0d12', 'optionText': '#00f0ff', 'launcher': '#c2185b', 'accent': '#fcee0a', 'onAccent': '#0d0d12'},
  ),
  'space': WidgetThemeData(
    'Space', 'Exo 2', 'body', true,
    ThemeShapeData(18.0, 4.0, 999.0, 999.0, 18.0, 0.0, null, 700),
    {'bg': '#070b22', 'bg2': '#050818', 'card': '#111638', 'card2': '#1a2150', 'field': '#0c1130', 'menu': '#111638', 'ink': '#e8ebff', 'text': '#cdd3f5', 'muted': '#9aa3d6', 'faint': '#626ba3', 'line': 'rgba(160, 170, 255, 0.14)', 'line2': 'rgba(160, 170, 255, 0.28)'},
    {'bg': '#070b22', 'bg2': '#050818', 'card': '#111638', 'card2': '#1a2150', 'field': '#0c1130', 'menu': '#111638', 'ink': '#e8ebff', 'text': '#cdd3f5', 'muted': '#9aa3d6', 'faint': '#626ba3', 'line': 'rgba(160, 170, 255, 0.14)', 'line2': 'rgba(160, 170, 255, 0.28)'},
    {'brand': '#7c5cff', 'headerBg': '#0b1030', 'headerText': '#e8ebff', 'botBg': '#161c44', 'botText': '#e8ebff', 'userBg': '#6246ea', 'userText': '#ffffff', 'optionBg': '#0b1030', 'optionText': '#a9b8ff', 'launcher': '#5b3fd6', 'launcher2': '#2563eb', 'accent': '#a78bfa', 'onAccent': '#0b1030'},
    {'brand': '#7c5cff', 'headerBg': '#0b1030', 'headerText': '#e8ebff', 'botBg': '#161c44', 'botText': '#e8ebff', 'userBg': '#6246ea', 'userText': '#ffffff', 'optionBg': '#0b1030', 'optionText': '#a9b8ff', 'launcher': '#5b3fd6', 'launcher2': '#2563eb', 'accent': '#a78bfa', 'onAccent': '#0b1030'},
  ),
};
