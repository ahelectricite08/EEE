/// Document PDF bénévole (`benevole_documents/{id}`).
class BenevoleDocument {
  final String id;
  final String title;
  final String category;
  final String fileUrl;
  final String storagePath;
  final bool published;
  final int order;
  final String? fileName;

  const BenevoleDocument({
    required this.id,
    required this.title,
    required this.category,
    required this.fileUrl,
    required this.storagePath,
    this.published = true,
    this.order = 0,
    this.fileName,
  });

  factory BenevoleDocument.fromFirestore(String id, Map<String, dynamic> data) {
    return BenevoleDocument(
      id: id,
      title: (data['title'] ?? '').toString().trim(),
      category: (data['category'] ?? 'Général').toString().trim(),
      fileUrl: (data['fileUrl'] ?? '').toString().trim(),
      storagePath: (data['storagePath'] ?? '').toString().trim(),
      published: data['published'] != false,
      order: (data['order'] as num?)?.toInt() ?? 0,
      fileName: data['fileName']?.toString(),
    );
  }
}
