// Constant indicating the discovery process time
const POOLING_DISCOVERY = 1000;

// Constant indicating the number of wrappers used
const NB_WRAPPERS = 2;

// Constants for processing message received from peers
const CONNECT_SERVER = 201; // Control message (server)
const CONNECT_CLIENT = 202; // Control message (client)
const CONNECT_BROADCAST = 203; // Broadcast a connection event
const DISCONNECT_BROADCAST = 204; // Broadcast a disconnection event
const BROADCAST = 205; // Broadcast message

// Constants for upper layer notifications
const DATA_RECEIVED = 209; // Data received
const FORWARD_DATA = 210; // Data to be forwarded to next hop
const MESSAGE_EVENT = 211; // Message received
const BROKEN_LINK = 212; // Broken link detected
