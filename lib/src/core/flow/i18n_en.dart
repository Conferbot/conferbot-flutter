/// The English texts the rich steps say (conferbot-widget/src/ts/i18n/en.ts),
/// via the React Native SDK (src/core/flow/i18nEn.ts).
library;

import 'js.dart';

const Map<String, String> enText = {
  'address.busy': "Address search is busy right now. Try again in a moment, or enter it manually.",
  'address.denied': "We couldn't get your location - location access is turned off. Type your address instead.",
  'address.failed': "Address search isn't working right now. You can enter it manually.",
  'address.noResults': "No matches. Try adding the city, or enter it manually.",
  'address.unavailable': "We couldn't find your location. Type your address instead.",
  'common.and': "and",
  'common.cancel': "Cancel",
  'common.continue': "Continue",
  'common.opensNewTab': "(opens in a new tab)",
  'common.send': "Send",
  'common.skip': "Skip",
  'common.somethingWrong': "Something went wrong. Please try again.",
  'common.submit': "Submit",
  'consent.agreed': "Agreed",
  'consent.agreedTo': "Agreed to {docs}",
  'consent.declined': "Didn't agree",
  'consent.tickBox': "Please tick the box to continue.",
  'dates.closedOn': "Closed on {days}",
  'dates.dayUnavailable': "{day} aren't available. Please pick another day.",
  'dates.onOrAfter': "Please pick a date on or after {date}.",
  'dates.onOrBefore': "Please pick a date on or before {date}.",
  'dates.pickDate': "Please pick a date.",
  'dates.pickTime': "Please pick a time.",
  'dates.timeFrom': "Please pick a time from {time}.",
  'dates.timeUntil': "Please pick a time until {time}.",
  'kb.askPrompt': "What would you like to know?",
  'kb.helpArticle': "Help article",
  'kb.notFound': "I couldn't find that in our help articles.",
  'matrix.everyRow': "Answer every row - {n} left",
  'matrix.oneRow': "Answer at least one row",
  'matrix.progress': "{n} of {total} answered",
  'otp.allDigits': "Enter all {n} digits.",
  'otp.expired': "That code has expired. Send a new one.",
  'otp.invalidEmail': "Please enter a valid email address.",
  'otp.locked': "Too many wrong codes.",
  'otp.noCode': "Send a code first.",
  'otp.notVerified': "Not verified",
  'otp.reason.expired': "The code expired",
  'otp.reason.locked': "Too many wrong codes",
  'otp.reason.sendFailed': "The code couldn't be sent",
  'otp.reason.sms': "Text-message codes aren't available",
  'otp.resend': "Resend code",
  'otp.resendIn': "Resend in {time}",
  'otp.resendWait': "Please wait {n} seconds before asking for a new code.",
  'otp.smsUnavailable': "Codes by text message aren't available yet.",
  'otp.tooMany': "Too many codes were asked for. Please try again later.",
  'otp.verifiedAs': "Verified: {email}",
  'otp.wrong': "That code isn't right.",
  'otp.wrongLeft.one': "That code isn't right. {n} try left.",
  'otp.wrongLeft.other': "That code isn't right. {n} tries left.",
  'pay.cancelled': "Payment cancelled",
  'pay.failed': "Payment couldn't be started. Please try again.",
  'pay.invalidAmount': "The amount to pay isn't valid.",
  'pay.ivePaid': "I've paid",
  'pay.network': "We couldn't reach the payment service. Check your connection and try again.",
  'pay.notConfigured': "Payments aren't set up for this chat yet.",
  'pay.notYet': "We haven't received the payment yet. Finish it in the Stripe tab, then check again.",
  'pay.paid': "Paid",
  'pay.paidAmount': "Paid {amount}",
  'pay.payNow': "Pay now",
  'pay.rateLimited': "Too many tries. Please wait a moment.",
  'pay.timedOut': "Payment timed out",
  'ranking.moved': "{item}, moved to position {n} of {total}",
  'rich.nothingToChoose': "There's nothing to choose from right now.",
  'signature.sign': "Sign",
  'signature.typeToSign': "Type your full name to sign",
  'signature.uploadFailed': "Upload failed. Your signature is still here - press Sign to try again.",
};

/// A text by key, {name} placeholders filled (web i18n t).
String t(String key, [Map<String, dynamic>? vars]) {
  final text = enText[key] ?? key;
  if (vars == null) return text;
  return text.replaceAllMapped(RegExp(r'\{(\w+)\}'), (m) {
    final v = vars[m.group(1)];
    return v == null ? m.group(0)! : jsString(v);
  });
}
