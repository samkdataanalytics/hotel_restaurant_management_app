/// Synthetic email domain for staff accounts created via the admin panel.
///
/// Staff sign in with a username, but Supabase auth is email-based, so
/// `create-staff-account` provisions them as `{username}@staff.internal`.
/// `AppAuthState.isStaffAccount` detects them by this same suffix.
const kStaffEmailDomain = '@staff.internal';

/// Maps a login field value to the email Supabase auth expects.
///
/// Input without an '@' is a staff username, so the synthetic email is built
/// directly rather than via an RPC lookup — a wrong username simply comes back
/// from Supabase as invalid-credentials, which is the same outcome and one
/// round trip cheaper. Input containing '@' is already an email and passes
/// through untouched.
///
/// Shared by the web login screen and the staff mobile app so the two can never
/// disagree about how a username becomes an identity.
String resolveSignInEmail(String input) =>
    input.contains('@') ? input : '$input$kStaffEmailDomain';
