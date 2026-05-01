const WS_URL = "ws://localhost:19385";
let socket = null;
let reconnectTimer = null;

function connectWebSocket() {
  if (socket && (socket.readyState === WebSocket.OPEN || socket.readyState === WebSocket.CONNECTING)) {
    return;
  }

  socket = new WebSocket(WS_URL);

  socket.onopen = () => {
    console.log("Connected to boringNotch WebSocket");
    if (reconnectTimer) {
      clearTimeout(reconnectTimer);
      reconnectTimer = null;
    }
  };

  socket.onmessage = (event) => {
    try {
      const command = JSON.parse(event.data);
      // Forward command to the active tab's content script
      chrome.tabs.query({ active: true, currentWindow: true }, (tabs) => {
        if (tabs.length > 0) {
          chrome.tabs.sendMessage(tabs[0].id, { type: "MEDIA_COMMAND", payload: command });
        }
      });
    } catch (e) {
      console.error("Failed to parse incoming command", e);
    }
  };

  socket.onclose = () => {
    console.log("Disconnected from boringNotch WebSocket, retrying in 2 seconds...");
    scheduleReconnect();
  };

  socket.onerror = (error) => {
    console.error("WebSocket error:", error);
    socket.close();
  };
}

function scheduleReconnect() {
  if (!reconnectTimer) {
    reconnectTimer = setTimeout(() => {
         reconnectTimer = null;
         connectWebSocket();
    }, 2000);
  }
}

connectWebSocket();

// Listen for state updates from content scripts
chrome.runtime.onMessage.addListener((message, sender, sendResponse) => {
  if (message.type === "MEDIA_STATE") {
    if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify(message.payload));
    }
  }
});
