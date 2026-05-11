let activeVideo = null;
let lastState = {};
let pollInterval = null;

function findActiveMedia() {
    const media = Array.from(document.querySelectorAll('video, audio'));
    if (media.length === 0) return null;
    const playingMedia = media.find(v => !v.paused && v.duration > 0);
    if (playingMedia) return playingMedia;

    return media.sort((a, b) => b.duration - a.duration)[0];
}

function getMediaMetadata() {
    let title = document.title;
    let artist = new URL(window.location.href).hostname;
    let artworkURL = null;

    if (navigator.mediaSession && navigator.mediaSession.metadata) {
        const metadata = navigator.mediaSession.metadata;
        if (metadata.title) title = metadata.title;
        if (metadata.artist) artist = metadata.artist;
        if (metadata.artwork && metadata.artwork.length > 0) {
            // Get the largest artwork
            const artwork = metadata.artwork[metadata.artwork.length - 1];
            artworkURL = artwork.src;
        }
    }

    // YouTube Specific Extraction
    if (window.location.hostname.includes("youtube.com") && !window.location.hostname.includes("music.")) {
        const ytTitle = document.querySelector('h1.ytd-watch-metadata yt-formatted-string');
        if (ytTitle) title = ytTitle.innerText;

        const ytArtist = document.querySelector('.ytd-channel-name yt-formatted-string');
        if (ytArtist) artist = ytArtist.innerText;
        
        if (!artworkURL) {
            const urlParams = new URLSearchParams(window.location.search);
            const videoId = urlParams.get('v');
            if (videoId) {
                artworkURL = `https://i.ytimg.com/vi/${videoId}/hqdefault.jpg`;
            }
        }
    }

    // YouTube Music Specific
    if (window.location.hostname.includes("music.youtube.com")) {
        const titleEl = document.querySelector('yt-formatted-string.title.ytmusic-player-bar');
        if (titleEl) title = titleEl.innerText;

        const artistEl = document.querySelector('span.subtitle.ytmusic-player-bar');
        if (artistEl) artist = artistEl.innerText;
    }
    
    // SoundCloud Specific
    if (window.location.hostname.includes("soundcloud.com")) {
        const titleEl = document.querySelector('.playbackSoundBadge__titleLink');
        const artistEl = document.querySelector('.playbackSoundBadge__titleContextContainer');
        if (titleEl) title = titleEl.innerText;
        if (artistEl) artist = artistEl.innerText;
    }

    return { title, artist, album: "", artworkURL };
}

function pollAndBroadcast() {
    activeVideo = findActiveMedia();
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
        bundleIdentifier: navigator.userAgent.includes("Chrome") ? "com.google.Chrome" : "com.apple.Safari",
        artworkURL: metadata.artworkURL
    };

    console.log("Media State Broadcast:", currentState);

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
        if (!activeVideo) activeVideo = findActiveMedia();
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
