
class Device {
  Device({
    this.id,
    this.modelName
  });

  final String id;
  final String modelName;

  @override
  String toString() => '<id: $id, model-name: $modelName>';
}
