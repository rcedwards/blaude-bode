#!/usr/bin/env node

const crypto = require("node:crypto");
const net = require("node:net");

const socketPath = `${process.env.HOME}/.codex/app-server-control/app-server-control.sock`;
const socket = net.createConnection(socketPath);

let buffer = Buffer.alloc(0);
let upgraded = false;
let nextId = 1;
let latestStatus = null;
let requestedPairing = false;
let finished = false;

function finish(exitCode = 0) {
  if (finished) return;
  finished = true;
  clearTimeout(timeout);
  process.exitCode = exitCode;
  socket.end();
}

function sendFrame(text) {
  const payload = Buffer.from(text);
  const headerLength = payload.length < 126 ? 2 : payload.length <= 65535 ? 4 : 10;
  const frame = Buffer.alloc(headerLength + 4 + payload.length);

  frame[0] = 0x81;
  if (payload.length < 126) {
    frame[1] = 0x80 | payload.length;
  } else if (payload.length <= 65535) {
    frame[1] = 0x80 | 126;
    frame.writeUInt16BE(payload.length, 2);
  } else {
    frame[1] = 0x80 | 127;
    frame.writeBigUInt64BE(BigInt(payload.length), 2);
  }

  const mask = crypto.randomBytes(4);
  mask.copy(frame, headerLength);
  for (let i = 0; i < payload.length; i += 1) {
    frame[headerLength + 4 + i] = payload[i] ^ mask[i % 4];
  }
  socket.write(frame);
}

function send(method, params = {}) {
  const id = nextId++;
  sendFrame(JSON.stringify({ id, method, params }));
  return id;
}

function maybeRequestPairing() {
  if (requestedPairing || latestStatus !== "connected") return;
  requestedPairing = true;
  send("remoteControl/pairing/start", { manualCode: true });
}

function handleMessage(message) {
  if (message.id === 1) {
    sendFrame(JSON.stringify({ method: "initialized", params: {} }));
    send("remoteControl/status/read");
    send("remoteControl/enable", { ephemeral: false });
    return;
  }

  if (message.method === "remoteControl/status/changed") {
    latestStatus = message.params.status;
    maybeRequestPairing();
    return;
  }

  if (message.result?.status) {
    latestStatus = message.result.status;
    maybeRequestPairing();
    return;
  }

  if (message.result?.manualPairingCode) {
    const expiresAt = new Date(message.result.expiresAt * 1000).toISOString();
    console.log(`Pairing code: ${message.result.manualPairingCode}`);
    console.log(`Host: ${message.result.environmentId}`);
    console.log(`Expires: ${expiresAt}`);
    finish();
    return;
  }

  if (message.error) {
    console.error(JSON.stringify(message.error, null, 2));
    finish(1);
  }
}

function parseFrames() {
  while (!finished && buffer.length >= 2) {
    const second = buffer[1];
    const opcode = buffer[0] & 0x0f;
    let length = second & 0x7f;
    let offset = 2;

    if (length === 126) {
      if (buffer.length < 4) return;
      length = buffer.readUInt16BE(2);
      offset = 4;
    } else if (length === 127) {
      if (buffer.length < 10) return;
      const longLength = buffer.readBigUInt64BE(2);
      if (longLength > BigInt(Number.MAX_SAFE_INTEGER)) {
        throw new Error("WebSocket frame is too large");
      }
      length = Number(longLength);
      offset = 10;
    }

    const masked = Boolean(second & 0x80);
    const maskOffset = offset;
    if (masked) offset += 4;
    if (buffer.length < offset + length) return;

    let payload = buffer.subarray(offset, offset + length);
    if (masked) {
      const mask = buffer.subarray(maskOffset, maskOffset + 4);
      payload = Buffer.from(payload.map((byte, i) => byte ^ mask[i % 4]));
    }
    buffer = buffer.subarray(offset + length);

    if (opcode === 0x1) handleMessage(JSON.parse(payload.toString("utf8")));
  }
}

socket.on("connect", () => {
  const key = crypto.randomBytes(16).toString("base64");
  socket.write([
    "GET / HTTP/1.1",
    "Host: localhost",
    "Connection: Upgrade",
    "Upgrade: websocket",
    "Sec-WebSocket-Version: 13",
    `Sec-WebSocket-Key: ${key}`,
    "",
    "",
  ].join("\r\n"));
});

socket.on("data", (chunk) => {
  buffer = Buffer.concat([buffer, chunk]);
  if (!upgraded) {
    const headerEnd = buffer.indexOf("\r\n\r\n");
    if (headerEnd === -1) return;

    const headers = buffer.subarray(0, headerEnd).toString("utf8");
    if (!headers.startsWith("HTTP/1.1 101")) {
      console.error(headers);
      finish(1);
      return;
    }

    upgraded = true;
    buffer = buffer.subarray(headerEnd + 4);
    send("initialize", {
      clientInfo: {
        name: "codex_remote_manual_pairing",
        title: "Codex Remote Manual Pairing",
        version: "0.0.0",
      },
      capabilities: { experimentalApi: true },
    });
  }
  parseFrames();
});

socket.on("error", (error) => {
  console.error(error.message);
  finish(1);
});

const timeout = setTimeout(() => {
  console.error("Timed out waiting for pairing code");
  finish(1);
}, 15000);
