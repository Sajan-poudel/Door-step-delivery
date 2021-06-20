import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:flutter/services.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import './credentials/credentials.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fluttertoast/fluttertoast.dart';
import './firstpage.dart';

class GoogleMapScreen extends StatefulWidget {
  const GoogleMapScreen({Key? key}) : super(key: key);

  @override
  _GoogleMapScreenState createState() => _GoogleMapScreenState();
}

class _GoogleMapScreenState extends State<GoogleMapScreen> {
  late GoogleMapController _controller;
  Map<MarkerId, Marker> markers = <MarkerId, Marker>{};
  late LatLng _center = LatLng(12.972442, 77.580643);
  late LatLng _destination;
  bool loading = false;
  bool marked_destination = false;
  String _address = "";
  String secure_key = "";
  late PolylinePoints polylinePoints = PolylinePoints();
  List<LatLng> polylineCoordinates = [];
  Map<PolylineId, Polyline> polylines = {};

  final firestoreInstance = FirebaseFirestore.instance;

  static final Random _random = Random.secure();
  // late LatLng _center;
  void initState() {
    _getCurrentLocation().then((position) {
      LatLng _add = LatLng(position.latitude, position.longitude);
      _getAddress(_add).then((value) {
        setState(() {
          this._center = _add;
          this.loading = false;
          final MarkerId markerId = MarkerId("Home");
          Marker marker = Marker(
            markerId: markerId,
            draggable: true,
            position: this._center,
            infoWindow: InfoWindow(
              title: "Your current location",
              snippet: value,
            ),
            icon: BitmapDescriptor.defaultMarkerWithHue(120.0),
          );
          markers[markerId] = marker;
          _controller.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(target: this._center, zoom: 5.0),
            ),
          );
        });
      });

      print(position);
    });
    // print(_center);
    super.initState();
  }

  // Set<Marker> _createrMarker() {
  //   return {
  //     Marker(
  //       markerId: MarkerId("home"),
  //       positcenter,
  //       infoWindow: InfoWindow(title: "Home"),
  //     ),
  //     Marker(
  //       markerId: MarkerId("Destination"),
  //       position: LatLng(18.9979, 72.83797),
  //     ),
  //   };
  // }

  static String CreateCryptoRandomString([int length = 16]) {
    var values = List<int>.generate(length, (index) => _random.nextInt(256));
    return base64Url.encode(values);
  }

  Future _getAddress(LatLng latlng) async {
    String address = "";
    try {
      List<Placemark> p =
          await placemarkFromCoordinates(latlng.latitude, latlng.longitude);
      Placemark place = p[0];
      address =
          "${place.name}, ${place.locality}, ${place.postalCode}, ${place.country}";
    } catch (e) {
      print(e);
    }
    return address;
  }

  Future _addMarkerLongPressed(LatLng latlng) async {
    _getAddress(latlng).then((address) {
      _createPolylines(latlng, this._center).then((value) {
        setState(() {
          final MarkerId markerId = MarkerId("Destination");
          Marker marker = Marker(
            markerId: markerId,
            draggable: true,
            position: latlng,
            infoWindow: InfoWindow(
              title: "Destination Location",
              snippet: address,
            ),
            icon: BitmapDescriptor.defaultMarker,
          );
          markers[markerId] = marker;
          _destination = latlng;
          marked_destination = true;
          _address = address;
        });
      });
    });
  }

  // Future<void> onMapCreated(GoogleMapController controller) async {
  //   _controller.complete(controller);
  // }

  Future<Position> _getCurrentLocation() async {
    var currentLoaction;
    try {
      currentLoaction = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best);
    } catch (e) {
      print("error : ${e}");
    }
    return currentLoaction;
  }

  _createPolylines(LatLng latlng, LatLng center) async {
    polylinePoints = PolylinePoints();
    List<LatLng> polylineCoordinates = [];
    PolylineResult result = await polylinePoints.getRouteBetweenCoordinates(
      api_key,
      PointLatLng(center.latitude, center.longitude),
      PointLatLng(latlng.latitude, latlng.longitude),
      travelMode: TravelMode.transit,
    );

    if (result.points.isNotEmpty) {
      print(result);
      result.points.forEach((PointLatLng point) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      });
    }

    PolylineId id = PolylineId('Poly');

    Polyline polyline = Polyline(
      polylineId: id,
      color: Colors.red.shade600,
      visible: true,
      points: polylineCoordinates,
      width: 3,
    );
    polylines[id] = polyline;
    setState(() {});
  }

  void copytoClipboard() {
    Clipboard.setData(ClipboardData(text: "${this.secure_key}"));
    Fluttertoast.showToast(
      msg: "Key copied to ClipBoard",
      backgroundColor: Colors.green.shade600,
    );
  }

  void update_to_firestore(String secure_key) {
    firestoreInstance.collection("delivery").doc(secure_key).set({
      "home_address": GeoPoint(_center.latitude, _center.longitude),
      "destination_address":
          GeoPoint(_destination.latitude, _destination.longitude),
    }).then((_) {
      Fluttertoast.showToast(
        msg: "your delivery request have been sent",
        backgroundColor: Colors.green.shade600,
      );

      Navigator.pushReplacement<void, void>(
        context,
        MaterialPageRoute<void>(
          builder: (BuildContext context) => const FirstPage(),
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
      body: (loading == true)
          ? Align(
              child: Container(
                child: SizedBox(
                  height: 100.0,
                  width: 100.0,
                  child: CircularProgressIndicator(),
                ),
              ),
            )
          : Stack(
              children: [
                Container(
                  height: MediaQuery.of(context).size.height,
                  width: MediaQuery.of(context).size.width,
                  child: GoogleMap(
                    polylines: Set<Polyline>.of(polylines.values),
                    mapType: MapType.normal,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    initialCameraPosition: CameraPosition(
                      target: _center,
                      zoom: 11.0,
                    ),
                    onMapCreated: (GoogleMapController controller) {
                      _controller = controller;
                    },
                    compassEnabled: true,
                    tiltGesturesEnabled: false,
                    onLongPress: (latlang) {
                      _addMarkerLongPressed(latlang);
                    },
                    markers: Set<Marker>.of(markers.values),
                  ),
                ),
                (marked_destination)
                    ? Positioned(
                        top: MediaQuery.of(context).size.height - 100,
                        child: Card(
                          child: InkWell(
                            onTap: () {
                              setState(() {
                                secure_key = CreateCryptoRandomString();
                              });
                              showModalBottomSheet(
                                context: context,
                                builder: (context) {
                                  return StatefulBuilder(builder:
                                      (BuildContext context,
                                          StateSetter setState) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: <Widget>[
                                        SizedBox(
                                          height: 20,
                                        ),
                                        Text(
                                          "Destination : \n\n${this._address}",
                                          style: TextStyle(
                                            fontSize: 30.0,
                                            fontWeight: FontWeight.bold,
                                            color:
                                                Color.fromARGB(255, 0, 51, 0),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 25,
                                        ),
                                        Container(
                                          width: MediaQuery.of(context)
                                                  .size
                                                  .width -
                                              20,
                                          decoration: BoxDecoration(
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                  color: Colors.blueAccent)),
                                          child: Padding(
                                            padding: EdgeInsets.all(10),
                                            child: Text(
                                              "${secure_key}",
                                              style: TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        ),
                                        SizedBox(
                                          height: 20,
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceEvenly,
                                          children: [
                                            ElevatedButton(
                                              onPressed: () {
                                                print("pressed");
                                                setState(() {
                                                  secure_key =
                                                      CreateCryptoRandomString();
                                                });
                                              },
                                              child: Text(
                                                "Generate \nSecure_Key",
                                                style: TextStyle(fontSize: 20),
                                              ),
                                            ),
                                            SizedBox(
                                              width: 15,
                                            ),
                                            ElevatedButton(
                                              onPressed: () {
                                                copytoClipboard();
                                              },
                                              child: Text(
                                                "copy \nsecure_key",
                                                style: TextStyle(fontSize: 20),
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(
                                          height: 20,
                                        ),
                                        Padding(
                                          padding: EdgeInsets.symmetric(
                                              horizontal: 10, vertical: 5),
                                          child: ElevatedButton(
                                            onPressed: () {
                                              update_to_firestore(secure_key);
                                            },
                                            child: Text(
                                              "Send parcels",
                                              style: TextStyle(fontSize: 20),
                                            ),
                                          ),
                                        )
                                      ],
                                    );
                                  });
                                },
                              );
                            },
                            child: SizedBox(
                              width: MediaQuery.of(context).size.width,
                              height: 100,
                              child: Text(
                                "Destination : ${this._address}",
                                style: TextStyle(
                                  fontSize: 30.0,
                                  fontWeight: FontWeight.bold,
                                  color: Color.fromARGB(255, 0, 0, 0),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Container()
              ],
            ),
    );
  }
}
