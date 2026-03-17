import '../../core/constants.dart';

class CategoryModel {
  final String id;
  final String name;
  final GenderCategory gender;
  final String? parentId;
  final String? imageUrl;
  final bool isPopular;

  const CategoryModel({
    required this.id,
    required this.name,
    required this.gender,
    this.parentId,
    this.imageUrl,
    this.isPopular = false,
  });

  factory CategoryModel.fromMap(String id, Map<String, dynamic> map) {
    return CategoryModel(
      id: id,
      name: (map['name'] as String?) ?? '',
      gender: GenderCategory.fromString((map['gender'] as String?) ?? 'male'),
      parentId: map['parentId'] as String?,
      imageUrl: map['imageUrl'] as String?,
      isPopular: (map['isPopular'] as bool?) ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'gender': gender.asString,
        'parentId': parentId,
        'imageUrl': imageUrl,
        'isPopular': isPopular,
      };
}

