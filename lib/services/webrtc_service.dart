import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class WebRTCService {
  static String appId = dotenv.env['AGORA_APP_ID'] ?? "";

  RtcEngine? _engine;
  int? _remoteUid;
  bool _isJoined = false;
  bool _isCameraOn = true;
  bool _isMicOn = true;

  Function(int uid)? onRemoteUserJoined;
  Function(int uid)? onRemoteUserLeft;
  Function(String error)? onError;

  Future<void> initialize() async {
    await [Permission.camera, Permission.microphone].request();

    _engine = createAgoraRtcEngine();
    await _engine!.initialize(RtcEngineContext(
      appId: appId,
      channelProfile: ChannelProfileType.channelProfileCommunication,
    ));

    _engine!.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          debugPrint(
              "WebRTC: Local user joined channel: ${connection.channelId}");
          _isJoined = true;
        },
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          debugPrint("WebRTC: Remote user joined: $remoteUid");
          _remoteUid = remoteUid;
          onRemoteUserJoined?.call(remoteUid);
        },
        onUserOffline: (RtcConnection connection, int remoteUid,
            UserOfflineReasonType reason) {
          debugPrint("WebRTC: Remote user left: $remoteUid");
          _remoteUid = null;
          onRemoteUserLeft?.call(remoteUid);
        },
        onLocalVideoStateChanged: (VideoSourceType source,
            LocalVideoStreamState state, LocalVideoStreamReason error) {
          debugPrint(
              "WebRTC: Local Video State Changed: $state, Error: $error");
        },
        onError: (ErrorCodeType err, String msg) {
          debugPrint("WebRTC Error: $err - $msg");
          onError?.call(msg);
        },
      ),
    );
  }

  Future<void> startVideo() async {
    if (_engine == null) return;

    try {
      await _engine!.enableVideo();

      await _engine!.enableLocalVideo(true);

      await _engine!.muteLocalVideoStream(false);

      await _engine!.setVideoEncoderConfiguration(
        const VideoEncoderConfiguration(
          dimensions: VideoDimensions(width: 480, height: 640),
          frameRate: 15,
          bitrate: 500,
          orientationMode: OrientationMode.orientationModeFixedPortrait,
        ),
      );

      await _engine!.setCameraCapturerConfiguration(
        const CameraCapturerConfiguration(
          cameraDirection: CameraDirection.cameraRear,
        ),
      );

      await _engine!.startPreview();
      debugPrint(
          "WebRTC: Video enabled, unmuted, and preview started in PORTRAIT mode");
    } catch (e) {
      debugPrint("WebRTC: Error starting video: $e");
    }
  }

  Future<void> joinChannel(String channelName, int uid, {String? token}) async {
    if (_engine == null) {
      debugPrint("WebRTC: Engine not initialized");
      return;
    }

    await startVideo();

    await _engine!.joinChannel(
      token: token ?? "",
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(
        clientRoleType: ClientRoleType.clientRoleBroadcaster,
        channelProfile: ChannelProfileType.channelProfileCommunication,
        publishCameraTrack: true,
        publishMicrophoneTrack: true,
        autoSubscribeAudio: true,
        autoSubscribeVideo: true,
      ),
    );

    debugPrint("WebRTC: Joining channel: $channelName with uid: $uid");
  }

  Future<void> leaveChannel() async {
    await _engine?.leaveChannel();

    await _engine?.stopPreview();

    _isJoined = false;
    _remoteUid = null;
    debugPrint("WebRTC: Left channel");
  }

  Future<void> toggleCamera() async {
    _isCameraOn = !_isCameraOn;
    await _engine?.enableLocalVideo(_isCameraOn);
    debugPrint("WebRTC: Camera ${_isCameraOn ? 'enabled' : 'disabled'}");
  }

  Future<void> toggleMic() async {
    _isMicOn = !_isMicOn;
    await _engine?.enableLocalAudio(_isMicOn);
    debugPrint("WebRTC: Microphone ${_isMicOn ? 'enabled' : 'disabled'}");
  }

  Future<void> switchCamera() async {
    await _engine?.switchCamera();
    debugPrint("WebRTC: Camera switched");
  }

  RtcEngine? get engine => _engine;
  int? get remoteUid => _remoteUid;
  bool get isJoined => _isJoined;
  bool get isCameraOn => _isCameraOn;
  bool get isMicOn => _isMicOn;

  Future<void> dispose() async {
    await _engine?.leaveChannel();
    await _engine?.release();
    _engine = null;
  }
}
