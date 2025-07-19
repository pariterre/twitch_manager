///
/// This is a trivial example of a state model for the extension backend service.
/// It contains a single field `sharedMessage` is passed around between the
/// frontend (what th viewer can interact with) and the client app (what the broadcaster
/// is using).
class State {
  final String sharedMessage;

  State({required this.sharedMessage});

  State copyWith({String? sharedMessage}) {
    return State(sharedMessage: sharedMessage ?? this.sharedMessage);
  }

  Map<String, dynamic> serialize() {
    return {'sharedMessage': sharedMessage};
  }

  factory State.deserialize(Map<String, dynamic> data) {
    return State(sharedMessage: data['sharedMessage'] as String);
  }
}
