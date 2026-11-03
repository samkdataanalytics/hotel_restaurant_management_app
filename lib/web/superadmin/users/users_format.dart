import '../../../services/user_tracking_service.dart';

/// "just now", "5 min ago", "3 days ago", "12 Mar 2026". Absolute dates past a
/// month, because "190 days ago" makes the reader do arithmetic.
String relativeTime(DateTime? t, {DateTime? now}) {
  if (t == null) return 'never';
  final n = now ?? DateTime.now();
  final d = n.difference(t);
  if (d.isNegative) return 'just now';
  if (d.inSeconds < 60) return 'just now';
  if (d.inMinutes < 60) return '${d.inMinutes} min ago';
  if (d.inHours < 24) return '${d.inHours} h ago';
  if (d.inDays < 30) return d.inDays == 1 ? 'yesterday' : '${d.inDays} days ago';
  return shortDate(t);
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String shortDate(DateTime? t) => t == null ? '—' : '${t.day} ${_months[t.month - 1]} ${t.year}';

String fullTime(DateTime? t) {
  if (t == null) return '—';
  String two(int n) => n.toString().padLeft(2, '0');
  return '${shortDate(t)}, ${two(t.hour)}:${two(t.minute)}';
}

/// Cells that a spreadsheet would treat as a formula are prefixed so they stay
/// text ("=HYPERLINK(...)" typed as a name must not run when an admin opens the
/// export), then quoted per RFC 4180.
String csvCell(Object? v) {
  var s = v == null ? '' : '$v';
  if (s.isNotEmpty && '=+-@\t\r'.contains(s[0])) s = "'$s";
  if (s.contains(RegExp(r'[",\n\r]'))) s = '"${s.replaceAll('"', '""')}"';
  return s;
}

String usersCsv(List<UserSummary> users) {
  const head = [
    'Name', 'Email', 'Username', 'Phone', 'Job title', 'Companies', 'Joined', 'Last sign-in',
    'Email confirmed', 'Superadmin', 'Deleted', 'Actions (30 days)',
  ];
  final rows = <String>[head.map(csvCell).join(',')];
  for (final u in users) {
    rows.add([
      u.fullName,
      u.hasRealEmail ? u.email : '',
      u.username,
      u.phone,
      u.jobTitle,
      u.orgs.map((o) => '${o.name} (${o.role})').join('; '),
      u.createdAt?.toIso8601String() ?? '',
      u.lastSignInAt?.toIso8601String() ?? '',
      u.emailConfirmed ? 'yes' : 'no',
      u.isSuperadmin ? 'yes' : 'no',
      u.isDeleted ? 'yes' : 'no',
      u.activity30d,
    ].map(csvCell).join(','));
  }
  return '${rows.join('\r\n')}\r\n';
}
