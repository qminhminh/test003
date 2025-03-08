import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride;
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'webrtc_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  if (WebRTC.platformIsDesktop) {
    debugDefaultTargetPlatformOverride = TargetPlatform.fuchsia;
  }
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => WebRTCService(),
      child: MaterialApp(
        home: WebRTCPage(),
      ),
    );
  }
}

class WebRTCPage extends StatefulWidget {
  @override
  State<WebRTCPage> createState() => _WebRTCPageState();
}

class _WebRTCPageState extends State<WebRTCPage> {
  double _volume = 1.0;
  bool isPaused = false;
  @override
  void initState() {
    super.initState();
    requestPermissions(); // Yêu cầu quyền khi ứng dụng khởi chạy
  }

  Future<void> requestPermissions() async {
    await [
      Permission.camera,
      Permission.microphone,
      Permission.storage,
    ].request();
  }

  @override
  Widget build(BuildContext context) {
    final webrtcService = Provider.of<WebRTCService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("WebRTC Example"),
        centerTitle: true,
      ),
      body: Column(
        children: [
          AspectRatio(
            aspectRatio: 16 / 9,
            child: webrtcService.isConnected
                ? InkWell(
                    onDoubleTap: webrtcService.disconnect,
                    child: RTCVideoView(
                      webrtcService.remoteRenderer,
                      mirror: false,
                      objectFit:
                          RTCVideoViewObjectFit.RTCVideoViewObjectFitContain,
                    ),
                  )
                : Container(
                    color: Colors.black,
                    child: Center(
                      child: InkWell(
                        onTap: webrtcService.isConnected
                            ? webrtcService.disconnect
                            : () {
                                webrtcService.connect(
                                  ipcUuid:
                                      "41cf0f00-936a-11ef-a41f-ffffca4e13b8",
                                  username: "demo2@epcb.vn",
                                  password: "demo2@123",
                                );
                              },
                        child: webrtcService.isConnected
                            ? Container()
                            : const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 70,
                              ),
                      ),
                    ),
                  ),
          ),
          const SizedBox(height: 16),

          // Điều chỉnh âm lượng
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                InkWell(
                    onTap: () {
                      setState(() async {
                        // webrtcService.toggleMute();
                        await webrtcService
                            .initializeStream(); // Lấy MediaStream
                        webrtcService.toggleMute(); // Toggle âm thanh
                      });
                    },
                    child: Icon(webrtcService.enableAudio
                        ? Icons.volume_up_outlined
                        : Icons.volume_off)),
                Expanded(
                  child: Slider(
                    value: _volume,
                    min: 0.0,
                    max: 1.0,
                    divisions: 10,
                    label: "${(_volume * 100).toStringAsFixed(0)}%",
                    onChanged: (double value) async {
                      setState(() {
                        _volume = value;
                      });
                      await webrtcService.initializeStream();
                      webrtcService.adjustVolume(_volume);
                    },
                  ),
                ),
              ],
            ),
          ),

          // Nút kết nối hoặc ngắt kết nối
          ElevatedButton(
            onPressed: webrtcService.isConnected
                ? webrtcService.disconnect
                : () {
                    webrtcService.connect(
                      ipcUuid: "41cf0f00-936a-11ef-a41f-ffffca4e13b8",
                      username: "demo2@epcb.vn",
                      password: "demo2@123",
                    );
                  },
            child: Text(webrtcService.isConnected ? "Disconnect" : "Connect"),
          ),
        ],
      ),
    );
  }
}
