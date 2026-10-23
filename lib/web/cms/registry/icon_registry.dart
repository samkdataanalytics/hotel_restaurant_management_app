import 'package:flutter/widgets.dart';
import 'package:flutter/material.dart' show Icons;

/// Icons an admin can choose for a section item, by stable name.
///
/// Stored in content as the name (`"apartment_rounded"`), never as a code point:
/// a code point is meaningless without the font and breaks silently if Material
/// renumbers it. Every entry is a const reference, so release builds still
/// tree-shake the icon font down to the glyphs listed here.
///
/// 71 icons: every one the landing page uses today, plus a curated set
/// for new perks, features and steps. Add to this map to expand the picker.
class IconRegistry {
  IconRegistry._();

  static const Map<String, IconData> icons = {
  'add_rounded': Icons.add_rounded,
  'analytics_rounded': Icons.analytics_rounded,
  'apartment_rounded': Icons.apartment_rounded,
  'arrow_back_rounded': Icons.arrow_back_rounded,
  'arrow_forward_rounded': Icons.arrow_forward_rounded,
  'auto_awesome_rounded': Icons.auto_awesome_rounded,
  'bed_rounded': Icons.bed_rounded,
  'bolt_rounded': Icons.bolt_rounded,
  'calendar_month_rounded': Icons.calendar_month_rounded,
  'campaign_rounded': Icons.campaign_rounded,
  'cancel_rounded': Icons.cancel_rounded,
  'card_giftcard_rounded': Icons.card_giftcard_rounded,
  'chat_rounded': Icons.chat_rounded,
  'check_circle_rounded': Icons.check_circle_rounded,
  'check_rounded': Icons.check_rounded,
  'close_rounded': Icons.close_rounded,
  'cloud_done_rounded': Icons.cloud_done_rounded,
  'construction_rounded': Icons.construction_rounded,
  'credit_card_rounded': Icons.credit_card_rounded,
  'dashboard_rounded': Icons.dashboard_rounded,
  'devices_rounded': Icons.devices_rounded,
  'emoji_events_rounded': Icons.emoji_events_rounded,
  'favorite_rounded': Icons.favorite_rounded,
  'groups_rounded': Icons.groups_rounded,
  'handshake_rounded': Icons.handshake_rounded,
  'hotel_rounded': Icons.hotel_rounded,
  'how_to_reg_rounded': Icons.how_to_reg_rounded,
  'info_outline_rounded': Icons.info_outline_rounded,
  'insights_rounded': Icons.insights_rounded,
  'inventory_2_rounded': Icons.inventory_2_rounded,
  'king_bed_rounded': Icons.king_bed_rounded,
  'kitchen_rounded': Icons.kitchen_rounded,
  'language_rounded': Icons.language_rounded,
  'lightbulb_outline_rounded': Icons.lightbulb_outline_rounded,
  'local_dining_rounded': Icons.local_dining_rounded,
  'location_on_rounded': Icons.location_on_rounded,
  'lock_clock_rounded': Icons.lock_clock_rounded,
  'lock_outline_rounded': Icons.lock_outline_rounded,
  'mail_outline_rounded': Icons.mail_outline_rounded,
  'meeting_room_rounded': Icons.meeting_room_rounded,
  'no_accounts_rounded': Icons.no_accounts_rounded,
  'palette_rounded': Icons.palette_rounded,
  'payments_rounded': Icons.payments_rounded,
  'people_alt_rounded': Icons.people_alt_rounded,
  'phone_in_talk_rounded': Icons.phone_in_talk_rounded,
  'play_circle_outline_rounded': Icons.play_circle_outline_rounded,
  'point_of_sale_rounded': Icons.point_of_sale_rounded,
  'qr_code_2_rounded': Icons.qr_code_2_rounded,
  'receipt_long_rounded': Icons.receipt_long_rounded,
  'remove_rounded': Icons.remove_rounded,
  'restaurant_menu_rounded': Icons.restaurant_menu_rounded,
  'restaurant_rounded': Icons.restaurant_rounded,
  'rocket_launch_rounded': Icons.rocket_launch_rounded,
  'room_service_rounded': Icons.room_service_rounded,
  'schedule_rounded': Icons.schedule_rounded,
  'security_rounded': Icons.security_rounded,
  'sentiment_dissatisfied_rounded': Icons.sentiment_dissatisfied_rounded,
  'shield_outlined': Icons.shield_outlined,
  'shield_rounded': Icons.shield_rounded,
  'speed_rounded': Icons.speed_rounded,
  'splitscreen_rounded': Icons.splitscreen_rounded,
  'star_rounded': Icons.star_rounded,
  'support_agent_rounded': Icons.support_agent_rounded,
  'sync_rounded': Icons.sync_rounded,
  'task_alt_rounded': Icons.task_alt_rounded,
  'thumb_up_alt_rounded': Icons.thumb_up_alt_rounded,
  'translate_rounded': Icons.translate_rounded,
  'trending_up_rounded': Icons.trending_up_rounded,
  'tune_rounded': Icons.tune_rounded,
  'verified_rounded': Icons.verified_rounded,
  'workspace_premium_rounded': Icons.workspace_premium_rounded,
  };

  /// The icon for [name], or [fallback] when the name is unknown. Unknown names
  /// are expected (a renamed icon, a typo in hand-edited JSON); the page shows a
  /// neutral glyph rather than failing.
  static IconData resolve(String? name, {IconData fallback = Icons.circle_outlined}) =>
      icons[name] ?? fallback;

  static bool isKnown(String? name) => icons.containsKey(name);

  static List<String> get names => icons.keys.toList(growable: false);
}
