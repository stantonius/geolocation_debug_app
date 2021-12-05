// Create a [GeofenceService] instance and set options.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geofence_service/geofence_service.dart';
import 'package:test_app2/secret_vars.dart';

import '../main.dart';
// import 'ble_beacon.dart';

final _geofenceService = GeofenceService.instance.setup(
    interval: 10000,
    accuracy: 150,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: true,
    allowMockLocations: true,
    printDevLog: true,
    geofenceRadiusSortType: GeofenceRadiusSortType.DESC);

// Create a [Geofence] list.
final _geofenceList = <Geofence>[
  Geofence(
    id: 'Home',
    // latitude: secretVars["homeLatitude"],
    // longitude: secretVars["homeLongitude"],
    latitude: 51.5072,
    longitude: 0.1276,
    radius: [
      GeofenceRadius(id: 'radius_25m', length: 25),
    ],
  )
];

/// State setup
// 1. Geofence and activity streams
// These simply house the data provided in the "onChange" functions below
StreamController<GeofenceStatus> _geofenceStreamController =
    StreamController<GeofenceStatus>();
StreamController<Map<String, dynamic>> _activityStreamController =
    StreamController<Map<String, dynamic>>();
StreamController<Location> _locationStreamController =
    StreamController<Location>();

// 2. Create the provider that listens to these streams

final geofenceStreamProvider = AutoDisposeStreamProvider<GeofenceStatus>((ref) {
  ref.onDispose(() {
    _geofenceStreamController.close();
  });
  // here goes a vlue that changes over time
  // this stream provider then exposes this to be read. But what is important
  // is to get a value that changes in here. In this case we get the stream from
  // the stream controller
  return _geofenceStreamController.stream;
});

final activityStreamProvider = AutoDisposeStreamProvider((ref) {
  ref.onDispose(() {
    _activityStreamController.close();
  });
  return _activityStreamController.stream;
});

final locationStreamProvider = AutoDisposeStreamProvider((ref) {
  ref.onDispose(() {
    _locationStreamController.close();
  });
  return _locationStreamController.stream;
});

/// 3. Callback functions used when statuses change
/// Note that most functions add data to a streamcontroller
///
// This function is to be called when the geofence status is changed.
Future<void> _onGeofenceStatusChanged(
    Geofence geofence,
    GeofenceRadius geofenceRadius,
    GeofenceStatus geofenceStatus,
    Location location) async {
  print('geofence: $geofence');
  print('geofenceRadius: $geofenceRadius');
  print('geofenceStatus: ${geofenceStatus.toString()}');
  _geofenceStreamController.sink.add(geofenceStatus);
  if (geofenceStatus == GeofenceStatus.ENTER) {
    print("Do some action when entering the geofence");
  } else if (geofenceStatus == GeofenceStatus.EXIT) {
    print("Do some action when leaving the geofence");
  }
}

void _onActivityChanged(Activity prevActivity, Activity currActivity) {
  print('prevActivity: ${prevActivity.toJson()}');
  print('currActivity: ${currActivity.toJson()}');
  _activityStreamController.sink.add(currActivity.toJson());
}

void _onLocationChanged(Location location) {
  print('location: ${location.toJson()}');
  _locationStreamController.sink.add(location);
}

void _onLocationServicesStatusChanged(bool status) {
  print('isLocationServicesEnabled: $status');
}

void _onError(error) {
  final errorCode = getErrorCodesFromError(error);
  if (errorCode == null) {
    print('Undefined error: $error');
    return;
  }

  print('ErrorCode: $errorCode');
}

/// Widget binding

void geofenceCallbacks() {
  WidgetsBinding.instance?.addPostFrameCallback((_) {
    _geofenceService.addGeofenceStatusChangeListener(_onGeofenceStatusChanged);
    _geofenceService.addLocationChangeListener(_onLocationChanged);
    _geofenceService.addLocationServicesStatusChangeListener(
        _onLocationServicesStatusChanged);
    _geofenceService.addActivityChangeListener(_onActivityChanged);
    _geofenceService.addStreamErrorListener(_onError);
    _geofenceService.start(_geofenceList).catchError(_onError).whenComplete(
        () => _geofenceStreamController.sink.add(GeofenceStatus.EXIT));
  });
}

WillStartForegroundTask geofenceWidgetWrapper(Widget scaffoldWidget) {
  return WillStartForegroundTask(
      onWillStart: () async {
        // You can add a foreground task start condition.
        return await _geofenceService.isRunningService;
      },
      foregroundTaskOptions: ForegroundTaskOptions(autoRunOnBoot: true),
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'geofence_service_notification_channel',
        channelName: 'Geofence Service Notification',
        channelDescription:
            'This notification appears when the geofence service is running in the background.',
        channelImportance: NotificationChannelImportance.DEFAULT,
        priority: NotificationPriority.LOW,
        isSticky: false,
      ),
      iosNotificationOptions: IOSNotificationOptions(),
      notificationTitle: 'StantonSmartHome is running',
      notificationText: 'Tap to return to the app',
      child: scaffoldWidget);
}

class GeofenceDetails extends ConsumerWidget {
  const GeofenceDetails({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue geofenceState = ref.watch(geofenceStreamProvider);
    return Container(
        child: Center(
            child: Center(
      child: geofenceState.map(data: (data) {
        return Text(data.value.toString());
      }, loading: (_) {
        return Text("Loading");
      }, error: (_) {
        return Text("Error");
      }),
    )));
  }
}

class ActivityDetails extends ConsumerWidget {
  const ActivityDetails({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    AsyncValue activityState = ref.watch(activityStreamProvider);

    return Container(
        child: Center(
      child: activityState.map(data: (data) {
        final activityData = data.value["type"];
        return Text(activityData.toString());
      }, loading: (_) {
        return Text("Loading");
      }, error: (_) {
        return Text("Error");
      }),
    ));
  }
}
