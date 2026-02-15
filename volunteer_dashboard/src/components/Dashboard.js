import React, { useState, useEffect } from 'react';
import { joinChannel, leaveChannel } from '../services/agora';
import { db } from '../services/firebase';
import { ref, onValue } from "firebase/database";
import YOLOOverlay from './YOLOOverlay';

function Dashboard() {
    const [isJoined, setIsJoined] = useState(false);
    const [channelName, setChannelName] = useState("test1");
    const [token, setToken] = useState("");
    const [obstacles, setObstacles] = useState([]);
    const [location, setLocation] = useState(null);
    const [status, setStatus] = useState("Waiting...");
    const [activeCalls, setActiveCalls] = useState({});


    const [localTracks, setLocalTracks] = useState(null);


    useEffect(() => {
        const sessionsRef = ref(db, 'sessions');
        onValue(sessionsRef, (snapshot) => {
            const data = snapshot.val();
            if (!data) {
                setActiveCalls({});
                return;
            }

            const calls = {};
            Object.keys(data).forEach(key => {
                const session = data[key];


                if (session.status === 'in_call') {
                    calls[key] = session;
                }


                if (isJoined) {
                    if (session.yolo && session.yolo.obstacles) {

                        setObstacles(session.yolo.obstacles);
                    }
                    if (session.location) {
                        setLocation(session.location);
                    }
                }
            });
            setActiveCalls(calls);
        });
    }, [isJoined]);

    const handleJoin = async () => {
        if (!channelName) return;
        try {
            console.log("Joining with token:", token ? "YES" : "NO");
            const tracks = await joinChannel(channelName, token || null);
            setLocalTracks(tracks);
            setIsJoined(true);
            setStatus("Connected");
        } catch (e) {
            console.error("Failed to join", e);
            alert("Join failed: " + e.message);
        }
    };

    const handleLeave = async () => {
        await leaveChannel(localTracks);
        setIsJoined(false);
        setLocalTracks(null);
        setStatus("Call Ended");
    };

    return (
        <div className="min-h-screen bg-gray-900 text-white p-5">
            <header className="flex justify-between items-center mb-5">
                <h1 className="text-3xl font-bold text-blue-400">NaviBlind Volunteer</h1>
                <div className="bg-gray-800 px-4 py-2 rounded-lg">
                    Status: <span className={isJoined ? "text-green-400" : "text-yellow-400"}>{status}</span>
                </div>
            </header>

            <div className="grid grid-cols-1 lg:grid-cols-4 gap-5">

                <div className="lg:col-span-3 bg-black rounded-xl overflow-hidden relative shadow-2xl border border-gray-700 flex items-center justify-center"
                    style={{ minHeight: '400px', maxHeight: '85vh' }}>
                    <div
                        id="remote-player"
                        className="w-full h-full flex items-center justify-center"
                        style={{
                            maxWidth: 'min(100%, calc(85vh * 9 / 16))',
                            aspectRatio: '9/16',
                            margin: '0 auto'
                        }}
                    ></div>


                    {isJoined && <YOLOOverlay obstacles={obstacles} />}

                    {!isJoined && (
                        <div className="absolute inset-0 flex items-center justify-center flex-col z-10 bg-black/50">
                            <p className="text-gray-300 mb-4">Ready to connect</p>

                            <input
                                type="text"
                                value={channelName}
                                onChange={(e) => setChannelName(e.target.value)}
                                className="mb-4 px-4 py-2 rounded bg-gray-800 text-white border border-gray-600 w-64"
                                placeholder="Channel Name"
                            />

                            <input
                                type="text"
                                value={token}
                                onChange={(e) => setToken(e.target.value)}
                                className="mb-4 px-4 py-2 rounded bg-gray-800 text-white border border-gray-600 w-64"
                                placeholder="Token (optional)"
                            />

                            <button
                                onClick={handleJoin}
                                className="bg-green-600 hover:bg-green-700 px-8 py-3 rounded-full font-bold text-lg transition shadow-lg"
                            >
                                Join Call
                            </button>
                        </div>
                    )}
                </div>


                <div className="bg-gray-800 rounded-xl p-5 shadow-xl flex flex-col">
                    <h2 className="text-xl font-bold mb-4 border-b border-gray-700 pb-2">Live Telemetry</h2>

                    <div className="mb-6">
                        <h3 className="text-gray-400 text-sm mb-1">GPS Location</h3>
                        <div className="bg-gray-900 p-3 rounded font-mono text-sm break-all">
                            {location ? (
                                <>
                                    <p>Lat: {location.latitude.toFixed(6)}</p>
                                    <p>Lng: {location.longitude.toFixed(6)}</p>
                                    <p className="text-blue-400">Heading: {location.heading?.toFixed(1)}°</p>
                                    <a
                                        href={`https://maps.google.com/?q=${location.latitude},${location.longitude}`}
                                        target="_blank"
                                        rel="noreferrer"
                                        className="text-blue-500 underline mt-2 block"
                                    >
                                        Open in Maps ↗
                                    </a>
                                </>
                            ) : "Waiting for GPS..."}
                        </div>
                    </div>

                    <div className="mb-6 flex-1 flex flex-col">
                        <h3 className="text-gray-400 text-sm mb-1">Detected Objects ({obstacles.length})</h3>
                        <div className="bg-gray-900 p-3 rounded flex-1 overflow-y-auto" style={{ maxHeight: '300px' }}>
                            <ul className="space-y-2">
                                {obstacles.map((obs, idx) => (
                                    <li key={idx} className="flex justify-between items-center text-sm border-b border-gray-800 pb-1 last:border-0">
                                        <span className="capitalize">{obs.label}</span>
                                        <span className={obs.distance < 2 ? "text-red-400 font-bold" : "text-green-400"}>
                                            {obs.distance.toFixed(1)}m
                                        </span>
                                    </li>
                                ))}
                            </ul>
                        </div>
                    </div>

                    {isJoined && (
                        <button
                            onClick={handleLeave}
                            className="w-full bg-red-600 hover:bg-red-700 py-3 rounded-lg font-bold mt-auto"
                        >
                            End Call
                        </button>
                    )}
                </div>
            </div>
        </div>
    );
}

export default Dashboard;
