// ignore_for_file: prefer_const_constructors, avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

class WebRTCService extends ChangeNotifier {
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  RTCPeerConnection? _peerConnection;
  bool isConnected = false;

  final String endpointBase = "https://demo.espitek.com";
  final String endpointRPC = "/api/rpc/twoway";
  final String endpointLogin = "/api/auth/login";
  final config = {
    'iceServers': [
      {
        'urls': 'stun:demo.espitek.com:3478',
      },
      {
        'urls': 'turn:demo.espitek.com:3478',
        'username': 'demo',
        'credential': 'demo4924',
      },
    ],
  };

  String? jwtToken;
  String clientId = _generateRandomId(10);

  bool enableAudio = true;
  MediaStream? mediaStream;

  WebRTCService() {
    remoteRenderer.initialize();
  }

  Future<void> initializeStream() async {
    mediaStream = remoteRenderer.srcObject; // Gán MediaStream từ remoteRenderer
    if (mediaStream == null) {
      print("MediaStream is not initialized.");
      return;
    }
  }

  static String _generateRandomId(int length) {
    const characters = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
    final random = Random();
    return List.generate(length, (index) {
      final randomIndex = random.nextInt(characters.length);
      return characters[randomIndex];
    }).join();
  }

  Future<void> connect({
    required String ipcUuid,
    required String username,
    required String password,
  }) async {
    print("id" + clientId);
    try {
      jwtToken = await AuthService.login(
        endpointLogin: endpointBase + endpointLogin,
        username: username,
        password: password,
      );

      await _sendRPC(
        method: "WEBRTC_REQUEST",
        uuid: ipcUuid,
        params: {"ClientId": clientId, "type": "request"},
      ).then((offer) => _handleOffer(ipcUuid, offer)).catchError((error) {
        print("Error: $error");
      });
      print("clientid: $clientId");
      print("ipcUuid: $ipcUuid");
      // print("offer: $offer");
      // print("jwtToken: $jwtToken");
      // await _handleOffer(ipcUuid, offer);
      isConnected = true;
      notifyListeners();
    } catch (error) {
      print("Connection error: $error");
      // disconnect();
    }
  }

  Future<void> disconnect() async {
    isConnected = false;
    _peerConnection?.close();
    _peerConnection = null;
    remoteRenderer.srcObject = null;
    notifyListeners();
  }

  Future<Map<String, dynamic>> _sendRPC({
    required String method,
    required String uuid,
    required Map<String, dynamic> params,
  }) async {
    try {
      final url = "$endpointBase$endpointRPC/$uuid";
      print("Sending RPC request to: $url");
      print("Headers: ${jsonEncode({
            "Content-Type": "application/json",
            "x-authorization": "Bearer $jwtToken"
          })}");
      print("Body: ${jsonEncode({
            "method": method,
            "params": params,
            "persistent": false,
            "timeout": 10000,
          })}");

      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Content-Type": "application/json",
          "x-authorization": "Bearer $jwtToken",
        },
        body: jsonEncode({
          "method": method,
          "params": params,
          "persistent": false,
          "timeout": 10000,
        }),
      );

      print("Response status: ${response.statusCode}");
      print("Response body: ${response.body}");

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception(
            "RPC failed with status ${response.statusCode}: ${response.body}");
      }
    } catch (error) {
      print("Failed to send RPC: $error");
      throw Exception("Failed to send RPC: $error");
    }
  }

  Future<void> _handleOffer(String uuid, Map<String, dynamic> offer) async {
    print("offer: $offer");
    _peerConnection = await _createPeerConnection();
    try {
      await _peerConnection!.setRemoteDescription(RTCSessionDescription(
        offer['sdp'],
        offer['type'],
      ));

      print("[DEBUG] Setting remote description...");
      print("[DEBUG] Remote description set successfully.");

      final answer = await _peerConnection!.createAnswer();

      await _peerConnection!.setLocalDescription(answer);
      await waitGatheringComplete();
      await _sendRPC(
        method: "WEBRTC_ANSWER",
        uuid: uuid,
        params: {
          "ClientId": clientId,
          "type": answer.type,
          "sdp": answer.sdp,
        },
      );
    } catch (e) {
      print("Error handler offer: " + e.toString());
    }
    // await _peerConnection!.setRemoteDescription(RTCSessionDescription(
    //   offer['sdp'],
    //   offer['type'],
    // ));

    // final answer = await _peerConnection!.createAnswer();

    // await _peerConnection!.setLocalDescription(answer);
    // await waitGatheringComplete();
    // print("answer: ${answer.toMap()}");
  }

  Future<void> waitGatheringComplete() async {
    if (_peerConnection!.iceGatheringState ==
        RTCIceGatheringState.RTCIceGatheringStateComplete) {
      return;
    }

    Completer<void> completer = Completer<void>();

    _peerConnection!.onIceGatheringState = (RTCIceGatheringState state) {
      if (state == RTCIceGatheringState.RTCIceGatheringStateComplete) {
        completer.complete();
      }
    };

    return completer.future;
  }

  Future<RTCPeerConnection> _createPeerConnection() async {
    final pc = await createPeerConnection(config);

    print("pc: $pc");

    pc.onTrack = (RTCTrackEvent event) async {
      remoteRenderer.srcObject = event.streams.first;
      // mediaStream = event.streams.first;
      // remoteRenderer.srcObject = mediaStream;
    };

    pc.onIceCandidate = (RTCIceCandidate candidate) {
      print(
          "[DEBUG] New ICE Candidate: type=${candidate.candidate}, sdpMLineIndex=${candidate.sdpMLineIndex}, sdpMid=${candidate.sdpMid}");
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      print("[DEBUG] ICE Connection State: $state");
      if (state == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        print("❌ ICE Connection failed! Kiểm tra STUN/TURN server.");
      }
    };

    pc.onIceConnectionState = (RTCIceConnectionState state) {
      print("[DEBUG] ICE Connection State Changed: ${state.toString()}");
    };

    pc.onConnectionState = (RTCPeerConnectionState state) {
      print("[DEBUG] Peer Connection State Changed: ${state.toString()}");
    };

    print("[DEBUG] Creating answer...");

    return pc;
  }

  void toggleMute() {
    if (mediaStream == null) {
      print("MediaStream is not initialized.");
      return;
    }
    enableAudio = !enableAudio;
    notifyListeners();

    mediaStream!.getAudioTracks().forEach((track) {
      track.enabled = enableAudio;
    });
  }

  void adjustVolume(double volume) {
    if (mediaStream == null) {
      print("MediaStream is not initialized.");
      return;
    }
    mediaStream!.getAudioTracks().forEach((track) {
      track.enabled = volume > 0;
    });
  }

  void pauseVideo() {
    // Dừng tất cả các video track
    remoteRenderer.srcObject?.getVideoTracks().forEach((track) {
      track.stop();
    });

    // Ngừng hiển thị video
    notifyListeners();
  }
}
