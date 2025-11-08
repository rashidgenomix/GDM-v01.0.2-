class GermplasmEntry {
  final String id;
  final String crop;
  final String accessionNumber;
  final String name;
  final String genus;
  final String species;
  final String origin;
  final String donorInstitute;
  final String collectionDate;

  GermplasmEntry({
    required this.id,
    required this.crop,
    required this.accessionNumber,
    required this.name,
    required this.genus,
    required this.species,
    required this.origin,
    required this.donorInstitute,
    required this.collectionDate,
  });

  factory GermplasmEntry.fromMap(String id, Map<String, dynamic> data) {
    return GermplasmEntry(
      id: id,
      crop: data['crop'] ?? '',
      accessionNumber: data['accessionNumber'] ?? '',
      name: data['name'] ?? '',
      genus: data['genus'] ?? '',
      species: data['species'] ?? '',
      origin: data['origin'] ?? '',
      donorInstitute: data['donorInstitute'] ?? '',
      collectionDate: data['collectionDate'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'crop': crop,
      'accessionNumber': accessionNumber,
      'name': name,
      'genus': genus,
      'species': species,
      'origin': origin,
      'donorInstitute': donorInstitute,
      'collectionDate': collectionDate,
    };
  }
}
