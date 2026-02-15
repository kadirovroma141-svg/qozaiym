import React, { useEffect, useRef } from 'react';

const YOLOOverlay = ({ obstacles }) => {
    const canvasRef = useRef(null);

    useEffect(() => {
        const canvas = canvasRef.current;
        if (!canvas) return;

        const ctx = canvas.getContext('2d');
        ctx.clearRect(0, 0, canvas.width, canvas.height);

        if (!obstacles) return;

        obstacles.forEach(obs => {

            const { left, top, width, height } = obs.box;

            const x = left * canvas.width;
            const y = top * canvas.height;
            const w = width * canvas.width;
            const h = height * canvas.height;

            ctx.strokeStyle = obs.distance < 2 ? 'red' : '#00ff00';
            ctx.lineWidth = 3;
            ctx.strokeRect(x, y, w, h);


            ctx.fillStyle = obs.distance < 2 ? 'red' : '#00ff00';
            const text = `${obs.label} (${obs.distance.toFixed(1)}m)`;
            const textWidth = ctx.measureText(text).width;
            ctx.fillRect(x, y - 25, textWidth + 10, 25);


            ctx.fillStyle = 'black';
            ctx.font = '16px Arial';
            ctx.fillText(text, x + 5, y - 7);
        });
    }, [obstacles]);

    return (
        <canvas
            ref={canvasRef}
            className="absolute top-0 left-0 w-full h-full pointer-events-none"
            width={480}
            height={640}
        />
    );
};

export default YOLOOverlay;
