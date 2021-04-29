import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:stream_chat_flutter/stream_chat_flutter.dart';

void main() async {
  const STREAM_KEY = String.fromEnvironment('api');
  const USER_TOKEN = String.fromEnvironment('token');

  final client = StreamChatClient(
    STREAM_KEY,
    logLevel: Level.OFF,
  );

  await client.connectUser(
    User(
      id: 'neevash',
      extraData: {
        'image':
            'https://local.getstream.io:9000/random_png/?id=eyJ0eXAiOiJKV1QiLCJhbGciOiJIUzI1NiJ9.eyJ1c2VyX2lkIjoiZGVsaWNhdGUtZmlyZS02In0.Yfdnsfkt48g1xv3I77mBjlVISnLwMyVUFobBynTf6Jc&amp;name=delicate-fire-6',
      },
    ),
    USER_TOKEN,
  );

  final channel = client.channel('messaging', id: 'sample-app-channel-1');
  channel.watch();

  runApp(MyApp(client: client));
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key, required this.client}) : super(key: key);
  final StreamChatClient client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      builder: (context, widget) {
        return StreamChat(
          child: widget!,
          client: client,
        );
      },
      home: ChannelListPage(),
    );
  }
}

class ChannelListPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Stream Playground'),
      ),
      body: ChannelsBloc(
        child: ChannelListView(
          filter: {
            'members': {
              '\$in': [StreamChat.of(context).user.id],
            }
          },
          sort: [SortOption('last_message_at')],
          pagination: PaginationParams(
            limit: 30,
          ),
          channelWidget: ChannelPage(),
        ),
      ),
    );
  }
}

class ChannelPage extends StatefulWidget {
  const ChannelPage({
    Key? key,
  }) : super(key: key);

  @override
  _ChannelPageState createState() => _ChannelPageState();
}

class _ChannelPageState extends State<ChannelPage> {
  Location? location;

  Future<bool> setupLocation() async {
    if (location == null) {
      location = Location();
    }
    var _serviceEnabled = await location!.serviceEnabled();
    if (!_serviceEnabled) {
      _serviceEnabled = await location!.requestService();
      if (!_serviceEnabled) {
        return false;
      }
    }

    var _permissionGranted = await location!.hasPermission();
    if (_permissionGranted == PermissionStatus.denied) {
      _permissionGranted = await location!.requestPermission();
      if (_permissionGranted != PermissionStatus.granted) {
        return false;
      }
    }
    return true;
  }

  Future<void> onLocationRequestPressed() async {
    final canSendLocation = await setupLocation();
    if (canSendLocation != true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
              "We can't access your location at this time. Did you allow location access?"),
        ),
      );
    }

    final locationData = await location!.getLocation();
    await StreamChannel.of(context).channel.sendMessage(
          Message(
            text: 'This is a location message',
            attachments: [
              Attachment(
                type: 'location',
                uploadState: UploadState.success(),
                extraData: {
                  'lat': locationData.latitude,
                  'long': locationData.longitude,
                },
              )
            ],
          ),
        );

    print('Location Sent!');
    return;
  }

  Widget _buildLocationMessage(
    BuildContext context,
    Message details,
    List<Attachment> attachments,
  ) {
    return MapImageThumbnail(
      lat: details.attachments.first.extraData['lat'],
      long: details.attachments.first.extraData['long'],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: ChannelHeader(),
      body: Column(
        children: <Widget>[
          Expanded(
            child: MessageListView(
              customAttachmentBuilders: {'location': _buildLocationMessage},
            ),
          ),
          MessageInput(
            actions: [
              IconButton(
                icon: Icon(Icons.location_history),
                onPressed: onLocationRequestPressed,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class MapImageThumbnail extends StatelessWidget {
  const MapImageThumbnail({
    Key? key,
    required this.lat,
    required this.long,
  }) : super(key: key);

  final double lat;
  final double long;

  String get _constructUrl => Uri(
        scheme: 'https',
        host: 'maps.googleapis.com',
        port: 443,
        path: '/maps/api/staticmap',
        queryParameters: {
          'center': '$lat,$long',
          'zoom': '18',
          'size': '600x500',
          'maptype': 'roadmap',
          'key': 'MAP_KEY',
          'markers': 'color:red|$lat,$long'
        },
      ).toString();

  @override
  Widget build(BuildContext context) {
    return Image.network(
      _constructUrl,
      height: 300.0,
      width: 600.0,
      fit: BoxFit.fill,
    );
  }
}
