/// A single "### Category" group (e.g. "Added", "Fixed") within one
/// version's changelog section, with its bullet items. [category] is empty
/// when the version section has bullets with no subheading.
class ChangelogSection {
  const ChangelogSection({required this.category, required this.items});

  final String category;
  final List<String> items;
}

/// Parses `CHANGELOG.md` and returns the sections for exactly one version
/// heading (a line matching `## <version>`), stopping at the next `## `
/// heading or end of file. Returns an empty list if the version isn't
/// present or has no bullet items.
///
/// Supported subset: `## x.y.z` version headings, optional `### Category`
/// subheadings, and `- ` bullet items. Anything else is ignored.
List<ChangelogSection> parseChangelogVersionSection(
  String changelog,
  String version,
) {
  final lines = changelog.split('\n');
  final versionHeading = RegExp(r'^##\s+' + RegExp.escape(version) + r'\s*$');

  var start = -1;
  for (var i = 0; i < lines.length; i++) {
    if (versionHeading.hasMatch(lines[i].trim())) {
      start = i + 1;
      break;
    }
  }
  if (start == -1) {
    return [];
  }

  final sections = <ChangelogSection>[];
  var currentCategory = '';
  var currentItems = <String>[];

  void flush() {
    if (currentItems.isNotEmpty) {
      sections.add(
        ChangelogSection(category: currentCategory, items: currentItems),
      );
      currentItems = [];
    }
  }

  for (var i = start; i < lines.length; i++) {
    final trimmed = lines[i].trim();
    if (trimmed.startsWith('## ')) {
      break;
    }
    if (trimmed.startsWith('### ')) {
      flush();
      currentCategory = trimmed.substring(4).trim();
      continue;
    }
    if (trimmed.startsWith('- ')) {
      currentItems.add(trimmed.substring(2).trim());
    }
  }
  flush();

  return sections;
}
