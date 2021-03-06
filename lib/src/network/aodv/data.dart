import 'package:json_annotation/json_annotation.dart';

part 'data.g.dart';

/// Class representing a DATA message for the AODV protocol.
@JsonSerializable()
class Data {
  String? dstAddr;
  Object? payload;

  /// Creates a [Data] object.
  ///
  /// The destination address is specified by [dstAddr] and its payload is
  /// given by [payload].
  Data(this.dstAddr, this.payload);

  /// Creates a [Data] object from a JSON representation.
  ///
  /// Factory constructor that creates a [Data] based on the information given
  /// by [json].
  factory Data.fromJson(Map<String, dynamic> json) => _$DataFromJson(json);

/*-------------------------------Public methods-------------------------------*/

  /// Returns the JSON representation as a [Map] of this [Data] instance.
  Map<String, dynamic> toJson() => _$DataToJson(this);

/*------------------------------Override methods------------------------------*/

  @override
  String toString() {
    return 'Data{' +
        'dstAddr=$dstAddr' +
        ', payload=${payload.toString()}' +
        '}';
  }
}
