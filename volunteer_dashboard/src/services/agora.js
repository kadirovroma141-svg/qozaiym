import AgoraRTC from "agora-rtc-sdk-ng";
import { AGORA_APP_ID } from "../config";

let agoraEngine = null;

export const initializeAgora = async () => {
    agoraEngine = AgoraRTC.createClient({ mode: "rtc", codec: "vp8" });

    agoraEngine.on("user-published", async (user, mediaType) => {
        console.log("🔥 Agora: User published!", user.uid, mediaType);
        await agoraEngine.subscribe(user, mediaType);
        console.log("✅ Agora: Subscribed to", user.uid, mediaType);

        if (mediaType === "video") {
            const remotePlayerContainer = document.getElementById("remote-player");
            if (remotePlayerContainer) {
                user.videoTrack.play(remotePlayerContainer);
                console.log("📹 Agora: Playing video from user", user.uid);
            } else {
                console.error("❌ Agora: remote-player container not found!");
            }
        }
        if (mediaType === "audio") {
            user.audioTrack.play();
            console.log("🔊 Agora: Playing audio from user", user.uid);
        }
    });

    return agoraEngine;
};

export const joinChannel = async (channelName, token = null) => {
    if (!agoraEngine) await initializeAgora();

    
    await agoraEngine.join(AGORA_APP_ID, channelName, token, null);

    
    const [microphoneTrack, cameraTrack] = await AgoraRTC.createMicrophoneAndCameraTracks();

    
    await agoraEngine.publish([microphoneTrack, cameraTrack]);

    return { microphoneTrack, cameraTrack };
};

export const leaveChannel = async (localTracks) => {
    if (localTracks) {
        localTracks.cameraTrack.close();
        localTracks.microphoneTrack.close();
    }
    await agoraEngine.leave();
};
