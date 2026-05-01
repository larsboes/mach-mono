let activeVideo = null;
let lastState = {};
let pollInterval = null;

function findActiveVideo() {
    const videos = Array.from(document.querySelectorAll('video'));
    if (videos.length === 0) return null;
    // Naive approach: Find the first playing video or the longest one
    const playingVideo = videos.find(v => !v.paused && v.duration > 0);
    if (playingVideo) return playingVideo;

    return videos.sort((a, b) => b.duration - a.duration)[0];
}

function getMediaMetadata() {
    let title = document.title;
    let artist = new URL(window.location.href).hostname;

    // YouTube Specific Extraction
    if (window.location.hostname.includes("youtube.com")) {
        const ytTitle = document.querySelector('h1.ytd-watch-metadata yt-formatted-string');
        if (ytTitle) title = ytTitle.innerText;

        const ytArtist = document.querySelector('.ytd-channel-name yt-formatted-string');
        if (ytArtist) artist = ytArtist.innerText;
    }

    // YouTube Music Specific
    if (window.location.hostname.includes("music.youtube.com")) {
        const titleEl = document.querySelector('yt-formatted-string.title.ytmusic-player-bar');
        if (titleEl) title = titleEl.innerText;

        const artistEl = document.querySelector('span.subtitle.ytmusic-player-bar');
        if (artistEl) artist = artistEl.innerText;
    }

    return { title, artist, album: "" };
}

function pollAndBroadcast() {
    activeVideo = findActiveVideo();
    if (!activeVideo) return;

    const metadata = getMediaMetadata();
    const currentState = {
        title: metadata.title,
        artist: metadata.artist,
        album: metadata.album,
        isPaused: activeVideo.paused,
        currentTime: activeVideo.currentTime,
        duration: isNaN(activeVideo.duration) ? 0 : activeVideo.duration,
        playbackRate: activeVideo.playbackRate,
        bundleIdentifier: navigator.userAgent.includes("Chrome") ? "com.google.Chrome" : "com.apple.Safari"
    };

    // Only broadcast if playing or if state changed significantly
    if (currentState.currentTime !== lastState.currentTime ||
        currentState.isPaused !== lastState.isPaused ||
        currentState.title !== lastState.title) {

        chrome.runtime.sendMessage({
            type: "MEDIA_STATE",
            payload: currentState
        });

        lastState = currentState;
    }
}

// Start polling
pollInterval = setInterval(pollAndBroadcast, 500);

// Listen for incoming commands from Swift (via Background Worker)
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
    if (message.type === "MEDIA_COMMAND") {
        const cmd = message.payload;
        if (!activeVideo) activeVideo = findActiveVideo();
        if (!activeVideo) return;

        if (cmd.command === "play") {
            activeVideo.play().catch(e => console.error("Play blocked", e));
        } else if (cmd.command === "pause") {
            activeVideo.pause();
        } else if (cmd.command === "seek" && typeof cmd.value === "number") {
            activeVideo.currentTime = cmd.value;
        } else if (cmd.command === "next") {
            const nextButton = document.querySelector('.ytp-next-button') || document.querySelector('.next-button');
            if (nextButton) nextButton.click();
        } else if (cmd.command === "previous") {
            const prevButton = document.querySelector('.ytp-prev-button') || document.querySelector('.previous-button');
            if (prevButton) prevButton.click();
            else activeVideo.currentTime = 0;
        }
    }
});
