import 'package:conferbot_flutter/src/core/customization/customizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('uses the web defaults when nothing is set', () {
    final c = Customizations.resolve({});
    expect(c.hideBrand, isFalse);
    expect(c.customBrand, isNull);
    expect(c.showOnline, isTrue);
    expect(c.logo, Customizations.defaultLogo);
    expect(c.avatar, Customizations.defaultLogo);
    expect(c.avatarSize, 32);
    expect(c.botBubble, const BubbleCorners(18, 18, 18, 6));
    expect(c.userBubble, const BubbleCorners(18, 18, 6, 18));
    expect(c.optionRadius, 10);
    expect(c.fontSize, 14.5);
    expect(c.userBubbleColor, '#f0f0f0');
    expect(c.userTextColor, '#000000');
    expect(c.optionBubbleColor, '#e7e4e4');
    expect(c.typingStyle, 'dots');
  });

  test('treats the server defaults as unset', () {
    final c = Customizations.resolve({'bubbleBorderRadius': 10, 'fontSize': 14, 'avatarSize': 40});
    expect(c.botBubble.bottomLeft, 6);
    expect(c.fontSize, 14.5);
    expect(c.avatarSize, 32);
  });

  test("applies the owner's values and colour fallbacks", () {
    final c = Customizations.resolve({
      'bubbleBorderRadius': 4, 'optionBubbleBorderRadius': '20', 'fontSize': 16, 'avatarSize': 44, 'avatarShape': 'square',
      'hideBrand': true, 'enableCustomBrand': true, 'customBrand': ' Acme ', 'enableTagline': true, 'tagline': 'Here 24/7',
      'hideAvatar': true, 'hideLogo': true, 'typingStyle': 'wave', 'botMsgColor': '#0F766E', 'botTextColor': '#ffffff', 'userMsgColor': '#123456',
    });
    expect(c.botBubble, const BubbleCorners.all(4));
    expect(c.optionRadius, 20);
    expect(c.fontSize, 16);
    expect(c.avatarRadius, 4);
    expect(c.customBrand, 'Acme');
    expect(c.tagline, 'Here 24/7');
    expect(c.showOnline, isFalse);
    expect(c.hideAvatar, isTrue);
    expect(c.hideLogo, isTrue);
    expect(c.typingStyle, 'wave');
    expect(c.optionBubbleColor, '#0F766E');
    expect(c.userTextColor, '#ffffff');
  });

  test('cuts the title and shapes avatars', () {
    expect(Customizations.headerTitle('Live chat test (temporary) quick'), 'Live chat test (te...');
    expect(Customizations.resolve({'logoText': 'Acme', 'botName': 'Bot'}).title, 'Acme');
    expect(Customizations.avatarRadiusFor('rounded', 32), 9);
    expect(Customizations.avatarRadiusFor('circle', 32), 16);
    expect(Customizations.resolve({'hideOnlineStatus': true}).showOnline, isFalse);
    expect(Customizations.resolve({'customBrand': 'Acme'}).customBrand, isNull);
  });
}
