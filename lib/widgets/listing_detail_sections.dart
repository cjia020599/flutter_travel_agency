import 'package:flutter/material.dart';
import 'package:flutter_travel_agency/utils/listing_data_helpers.dart';
import 'package:flutter_travel_agency/widgets/listing_rich_text_view.dart';

const _primaryBlue = Color(0xFF2563EB);

/// Hero, gallery, rich description, itinerary, surroundings, SEO, include/exclude.
class ListingDetailSections extends StatelessWidget {
  const ListingDetailSections({
    super.key,
    required this.entity,
    required this.isTour,
    required this.heroImageUrl,
    required this.placeholderIcon,
    this.specRows = const [],
  });

  final Map<String, dynamic> entity;
  final bool isTour;
  final String heroImageUrl;
  final IconData placeholderIcon;
  final List<Widget> specRows;

  @override
  Widget build(BuildContext context) {
    final desc = ListingDataHelpers.descriptionRaw(entity);
    final gallery = ListingDataHelpers.parseGalleryUrls(entity);
    final itinerary = ListingDataHelpers.parseTitleContentPairs(entity['itinerary']);
    final faqs = ListingDataHelpers.parseTitleContentPairs(entity['faqs']);
    final education = ListingDataHelpers.parseSurroundingsGroup(
      entity,
      directKey: 'surroundingsEducation',
      nestedKey: 'education',
    );
    final health = ListingDataHelpers.parseSurroundingsGroup(
      entity,
      directKey: 'surroundingsHealth',
      nestedKey: 'health',
    );
    final transport = ListingDataHelpers.parseSurroundingsGroup(
      entity,
      directKey: 'surroundingsTransportation',
      nestedKey: 'transportation',
    );
    final metaTitle =
        (entity['metaTitle'] ?? entity['seoTitle'])?.toString().trim() ?? '';
    final metaDesc =
        (entity['metaDescription'] ?? entity['seoDescription'])?.toString().trim() ??
        '';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HeroImage(url: heroImageUrl, icon: placeholderIcon),
        if (gallery.isNotEmpty) ...[
          const SizedBox(height: 12),
          _GalleryStrip(urls: gallery),
        ],
        if (specRows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: specRows,
              ),
            ),
          ),
        ],
        if (desc != null) ...[
          const SizedBox(height: 12),
          _SectionTitle('About this ${isTour ? 'tour' : 'vehicle'}'),
          const SizedBox(height: 8),
          ListingRichTextView(raw: desc, maxHeight: 280),
        ],
        if (itinerary.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Itinerary'),
          const SizedBox(height: 8),
          _TimelinePairs(items: itinerary, accent: _primaryBlue),
        ],
        if (education.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Nearby — Education'),
          const SizedBox(height: 8),
          _BulletPairs(items: education, icon: Icons.school_outlined),
        ],
        if (health.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Nearby — Health'),
          const SizedBox(height: 8),
          _BulletPairs(items: health, icon: Icons.local_hospital_outlined),
        ],
        if (transport.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Nearby — Transportation'),
          const SizedBox(height: 8),
          _BulletPairs(items: transport, icon: Icons.directions_bus_outlined),
        ],
        if (faqs.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('FAQs'),
          const SizedBox(height: 8),
          ...faqs.map(_FaqTile.new),
        ],
        if (metaTitle.isNotEmpty || metaDesc.isNotEmpty) ...[
          const SizedBox(height: 16),
          _SectionTitle('Listing summary'),
          const SizedBox(height: 8),
          Card(
            margin: EdgeInsets.zero,
            color: Colors.grey.shade50,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.grey.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (metaTitle.isNotEmpty)
                    Text(
                      metaTitle,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 15,
                      ),
                    ),
                  if (metaDesc.isNotEmpty) ...[
                    if (metaTitle.isNotEmpty) const SizedBox(height: 6),
                    Text(
                      metaDesc,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                        height: 1.45,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: 12),
        _IncludeExcludeBlock(entity: entity),
      ],
    );
  }
}

class _HeroImage extends StatelessWidget {
  const _HeroImage({required this.url, required this.icon});

  final String url;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.network(
          url,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => Container(
            color: Colors.grey.shade300,
            child: Icon(icon, size: 64, color: Colors.grey.shade600),
          ),
        ),
      ),
    );
  }
}

class _GalleryStrip extends StatelessWidget {
  const _GalleryStrip({required this.urls});

  final List<String> urls;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionTitle('Gallery'),
        const SizedBox(height: 8),
        SizedBox(
          height: 88,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: urls.length,
            separatorBuilder: (_, _) => const SizedBox(width: 8),
            itemBuilder: (context, i) => ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.network(
                  urls[i],
                  fit: BoxFit.cover,
                  width: 120,
                  errorBuilder: (_, _, _) => Container(
                    width: 120,
                    color: Colors.grey.shade300,
                    child: const Icon(Icons.broken_image, size: 28),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: Color(0xFF1E3A5F),
      ),
    );
  }
}

class _TimelinePairs extends StatelessWidget {
  const _TimelinePairs({required this.items, required this.accent});

  final List<Map<String, String>> items;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < items.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Container(
                      width: 28,
                      height: 28,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: accent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                    if (i < items.length - 1)
                      Container(width: 2, height: 24, color: Colors.grey.shade300),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(child: _PairCard(row: items[i])),
              ],
            ),
          ),
      ],
    );
  }
}

class _BulletPairs extends StatelessWidget {
  const _BulletPairs({required this.items, required this.icon});

  final List<Map<String, String>> items;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: items
          .map(
            (row) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 20, color: Colors.grey.shade600),
                  const SizedBox(width: 10),
                  Expanded(child: _PairCard(row: row)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}

class _PairCard extends StatelessWidget {
  const _PairCard({required this.row});

  final Map<String, String> row;

  @override
  Widget build(BuildContext context) {
    final title = (row['title'] ?? '').trim();
    final content = (row['content'] ?? '').toString().trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title.isNotEmpty)
            Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
          if (content.isNotEmpty) ...[
            if (title.isNotEmpty) const SizedBox(height: 4),
            Text(
              content,
              style: TextStyle(fontSize: 13, color: Colors.grey.shade800, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}

class _FaqTile extends StatelessWidget {
  const _FaqTile(this.row);

  final Map<String, String> row;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      child: ExpansionTile(
        title: Text(
          (row['title'] ?? 'Question').trim(),
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                (row['content'] ?? '').toString().trim(),
                style: TextStyle(color: Colors.grey.shade800, height: 1.45),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _IncludeExcludeBlock extends StatelessWidget {
  const _IncludeExcludeBlock({required this.entity});

  final Map<String, dynamic> entity;

  @override
  Widget build(BuildContext context) {
    final inc = ListingDataHelpers.parseTitleContentPairs(entity['include']);
    final exc = ListingDataHelpers.parseTitleContentPairs(entity['exclude']);
    if (inc.isEmpty && exc.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inc.isNotEmpty) ...[
          Text(
            'Inclusions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.green.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...inc.map((row) => _CheckRow(row: row, included: true)),
        ],
        if (exc.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            'Exclusions',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Colors.red.shade800,
            ),
          ),
          const SizedBox(height: 8),
          ...exc.map((row) => _CheckRow(row: row, included: false)),
        ],
      ],
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.row, required this.included});

  final Map<String, String> row;
  final bool included;

  @override
  Widget build(BuildContext context) {
    final title = (row['title'] ?? '').trim();
    final content = (row['content'] ?? '').toString().trim();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            included ? Icons.check_circle_outline : Icons.remove_circle_outline,
            size: 20,
            color: included ? Colors.green.shade700 : Colors.red.shade700,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title.isEmpty
                      ? (included ? 'Included' : 'Not included')
                      : title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (content.isNotEmpty)
                  Text(
                    content,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade800),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
