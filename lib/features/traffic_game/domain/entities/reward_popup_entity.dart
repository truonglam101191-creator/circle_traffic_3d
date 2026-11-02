/// Domain entity representing a floating reward popup triggered by a clean merge
/// or police conversion.
class RewardPopupData {
  final int carId;
  final String? customLabel;
  final String? customBadge;
  double age;

  RewardPopupData({
    required this.carId,
    this.customLabel,
    this.customBadge,
    this.age = 0.0,
  });
}
