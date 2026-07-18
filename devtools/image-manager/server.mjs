import fs from "node:fs";
import fsp from "node:fs/promises";
import http from "node:http";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { scanProject } from "./lib/scanner.mjs";

const currentDirectory = path.dirname(fileURLToPath(import.meta.url));
const projectRoot = path.resolve(currentDirectory, "../..");
const publicRoot = path.join(currentDirectory, "public");
const assetsRoot = path.join(projectRoot, "assets");
const host = process.env.IMAGE_MANAGER_HOST || "127.0.0.1";
const port = Number(process.env.IMAGE_MANAGER_PORT || 4317);

let indexCache = null;
let scanPromise = null;

function isInside(parent, candidate) {
  const relative = path.relative(parent, candidate);
  return relative !== "" && !relative.startsWith("..") && !path.isAbsolute(relative);
}

function sendJson(response, statusCode, payload) {
  const body = JSON.stringify(payload);
  response.writeHead(statusCode, {
    "Content-Type": "application/json; charset=utf-8",
    "Content-Length": Buffer.byteLength(body),
    "Cache-Control": "no-store",
  });
  response.end(body);
}

function sendText(response, statusCode, message) {
  response.writeHead(statusCode, {
    "Content-Type": "text/plain; charset=utf-8",
    "Content-Length": Buffer.byteLength(message),
  });
  response.end(message);
}

async function rescan() {
  if (scanPromise) return scanPromise;
  scanPromise = scanProject(projectRoot)
    .then((index) => {
      indexCache = index;
      return index;
    })
    .finally(() => {
      scanPromise = null;
    });
  return scanPromise;
}

async function sendFile(response, absolutePath, contentType, cacheControl = "no-cache") {
  try {
    const stat = await fsp.stat(absolutePath);
    response.writeHead(200, {
      "Content-Type": contentType,
      "Content-Length": stat.size,
      "Cache-Control": cacheControl,
    });
    fs.createReadStream(absolutePath).pipe(response);
  } catch (error) {
    if (error.code === "ENOENT") sendText(response, 404, "Not found");
    else sendText(response, 500, "Unable to read file");
  }
}

const contentTypes = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".png": "image/png",
};

const server = http.createServer(async (request, response) => {
  const url = new URL(request.url, `http://${request.headers.host || `${host}:${port}`}`);

  if (url.pathname === "/api/health") {
    sendJson(response, 200, {
      ok: true,
      scanning: Boolean(scanPromise),
      ready: Boolean(indexCache),
    });
    return;
  }

  if (url.pathname === "/api/index" && request.method === "GET") {
    const index = indexCache ?? (await rescan());
    sendJson(response, 200, index);
    return;
  }

  if (url.pathname === "/api/rescan" && request.method === "POST") {
    const index = await rescan();
    sendJson(response, 200, index);
    return;
  }

  if (url.pathname.startsWith("/asset/")) {
    let relativePath;
    try {
      relativePath = decodeURIComponent(url.pathname.slice("/asset/".length));
    } catch {
      sendText(response, 400, "Invalid asset path");
      return;
    }
    const absolutePath = path.resolve(assetsRoot, relativePath);
    if (!isInside(assetsRoot, absolutePath)) {
      sendText(response, 403, "Forbidden");
      return;
    }
    await sendFile(response, absolutePath, "image/png", "private, max-age=60");
    return;
  }

  const requestedPath = url.pathname === "/" ? "index.html" : url.pathname.slice(1);
  const absolutePath = path.resolve(publicRoot, requestedPath);
  if (!isInside(publicRoot, absolutePath)) {
    sendText(response, 403, "Forbidden");
    return;
  }
  const extension = path.extname(absolutePath).toLowerCase();
  await sendFile(
    response,
    absolutePath,
    contentTypes[extension] || "application/octet-stream",
  );
});

server.listen(port, host, async () => {
  console.log(`Image Manager: http://${host}:${port}`);
  console.log(`Project: ${projectRoot}`);
  try {
    const index = await rescan();
    console.log(
      `Indexed ${index.summary.assets} images in ${index.scanDurationMs} ms`,
    );
  } catch (error) {
    console.error("Initial scan failed:", error);
  }
});
