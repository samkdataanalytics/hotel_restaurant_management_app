import 'package:web/web.dart' as web;

String? lastPageTitle;

void setPageMeta({required String title, String? description}) {
  lastPageTitle = title;
  web.document.title = title;
  if (description == null) return;

  var tag = web.document.querySelector('meta[name="description"]');
  if (tag == null) {
    tag = web.document.createElement('meta');
    tag.setAttribute('name', 'description');
    web.document.head?.appendChild(tag);
  }
  tag.setAttribute('content', description);
}
