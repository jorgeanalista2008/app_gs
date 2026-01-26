class LoteModel {
  final String id;
  final String title;
  final String address;
  final String amount;
  final String status;

  LoteModel({
    required this.id,
    required this.title,
    required this.address,
    required this.amount,
    required this.status,
  });

  factory LoteModel.fromJson(Map<String, dynamic> json) {
    return LoteModel(
      id: json['id'],
      title: json['title'],
      address: json['address'],
      amount: json['amount'],
      status: json['status'],
    );
  }
}