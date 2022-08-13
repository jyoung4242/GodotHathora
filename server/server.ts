import { register } from "@hathora/server-sdk";
import dotenv from "dotenv";

type RoomId = bigint;
type UserId = string;

/**
 * Setting up both the Server side state
 * and the clientstates
 */
type GameState = {
  players: Player[];
};

type ServerState = {
  players: Player[];
};

/**
 * Player type that is used in STATE
 */
type Player = {
  id: string;
};

/**
 * Setting up messaging types
 * Server Messages first
 */

type ServerMessage = StateUpdate | ServerAcknowledge;
enum ServerMessageType {
  StateUpdate,
  ServerAcknowledge,
}
type StateUpdate = {
  type: ServerMessageType.StateUpdate;
  state: GameState;
  ts: number;
};

type ServerAcknowledge = {
  type: ServerMessageType.ServerAcknowledge;
  msg: any;
};

/**
 * Setting up messaging types
 * Clients next
 */

type ClientMessage = ClientUpdate;
enum ClientMessageType {
  ClientUpdate,
}
type ClientUpdate = {
  type: ClientMessageType.ClientUpdate;
  msg: any;
};

/**
 * Setting up different rooms that the server can run
 */
const states: Map<RoomId, { subscribers: Set<UserId>; game: ServerState }> = new Map();

/**
 * Hathora requires a .env with an AppSecret field
 * this gets converted to an App_ID that
 * the clients need
 */
dotenv.config({ path: "./.env" });
if (process.env.APP_SECRET === undefined) {
  throw new Error("APP_SECRET must be set");
}

/**
 * Creating instance of the server
 * This implementation utilizes anonymouse login
 */

const coordinator = await register({
  appSecret: process.env.APP_SECRET,
  authInfo: { anonymous: { separator: "-" } },
  store: {
    /**
     * newState is ran when a new game or room
     * is created, and it estalbishes initial
     * state for that game
     */
    newState(roomId, userId, data) {
      states.set(roomId, {
        subscribers: new Set(),
        game: {
          players: [],
        },
      });
      console.log("CREATE ROOM: ", states);
    },

    /**
     * subscribeUser is ran when a client connects
     *  to a room, and is added to the players list
     *  for that room, if the id doesn't already exist
     */
    subscribeUser(roomId, userId) {
      console.log("new user joined: ", roomId, userId);
      const { subscribers, game } = states.get(roomId)!;
      subscribers.add(userId);
      if (!game.players.some(player => player.id === userId)) {
        game.players.push({ id: userId });
      }
    },
    /**
     * unsubscribeUser runs when a client disconnects
     * and removes user from players list for that room
     */
    unsubscribeUser(roomId, userId) {
      const { subscribers, game } = states.get(roomId)!;
      subscribers.delete(userId);
      let playerIdx = game.players.findIndex(p => p.id === userId);
      game.players.splice(playerIdx, 1);
    },
    /**
     * resets server
     */
    unsubscribeAll() {
      states.clear();
    },
    /**
     * event that's ran when client message is sent to server
     */
    onMessage(roomId, userId, data) {
      const dataStr = Buffer.from(data.buffer, data.byteOffset, data.byteLength).toString("utf8");
      const { game, subscribers } = states.get(roomId)!;
      if (!subscribers.has(userId)) {
        console.log("cant find user");
        return;
      }

      const message: ClientMessage = JSON.parse(dataStr);
      if (message.type === ClientMessageType.ClientUpdate) {
        acknowledgment(roomId, userId, message.msg);
      }
    },
  },
});

/**
 * broadcastUpdates packages up a server message to all clients
 * and sends state updates to the client
 */
const broadcastUpdates = (roomId: RoomId) => {
  const { subscribers, game } = states.get(roomId)!;
  const now = Date.now();
  const gameState: GameState = {
    players: game.players.map(player => ({ id: player.id })),
  };

  subscribers.forEach(userId => {
    const msg: ServerMessage = {
      type: ServerMessageType.StateUpdate,
      state: gameState,
      ts: now,
    };
    coordinator.stateUpdate(roomId, userId, Buffer.from(JSON.stringify(msg), "utf8"));
  });
};

/**
 * This packages up a server message to a specific client in response to
 * receiving a message.
 * this is for testing purposes, the acknowledgement is just an echo
 * message
 */
const acknowledgment = (roomId: RoomId, userId: string, echo: string) => {
  const { subscribers, game } = states.get(roomId)!;

  const msg: ServerMessage = {
    type: ServerMessageType.ServerAcknowledge,
    msg: `Message Recevied: ${echo}`,
  };
  coordinator.stateUpdate(roomId, userId, Buffer.from(JSON.stringify(msg), "utf8"));
};

/**
 * This setups the periodic broadcast of stateupdates to each client
 */
setInterval(() => {
  states.forEach(({ game }, roomId) => {
    broadcastUpdates(roomId);
  });
}, 1000);
