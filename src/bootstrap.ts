#!/usr/bin/env node
import { spawn, spawnSync, type SpawnSyncOptions, type SpawnSyncReturns } from "node:child_process";
import fs from "node:fs";
import path from "node:path";

const WORKSPACE = "/workspace";
const INJECTED_CONFIG = "/tmp/pbdc-volume-bootstrap/devcontainer.json";
const SOCKET_CANDIDATES = [
  process.env.POOP_SOCKET ?? "/root/.poop/poop",
  "/var/run/docker.sock",
  "/run/podman/podman.sock",
];

function log(message: string): void {
  console.log(`[dcbootstrap] ${message}`);
}

function run(cmd: string, args: string[], options: SpawnSyncOptions = {}): SpawnSyncReturns<string> {
  return spawnSync(cmd, args, { encoding: "utf8", ...options }) as SpawnSyncReturns<string>;
}

function failIfFailed(result: SpawnSyncReturns<string>): never {
  process.stdout.write(result.stdout);
  process.stderr.write(result.stderr);
  process.exit(result.status ?? 1);
}

function bindEngineSocket(): void {
  const found = SOCKET_CANDIDATES.find((candidate) => {
    try {
      return fs.lstatSync(candidate).isSocket();
    } catch {
      return false;
    }
  });
  if (!found) {
    log("WARNING: no container engine socket found; devcontainer CLI will fail");
    return;
  }
  for (const dest of ["/run/podman/podman.sock", "/var/run/docker.sock"]) {
    try {
      fs.unlinkSync(dest);
    } catch {
      // ok if missing
    }
    fs.mkdirSync(path.dirname(dest), { recursive: true });
    fs.symlinkSync(found, dest, "file");
  }
  process.env.DOCKER_HOST = "unix:///run/podman/podman.sock";
  process.env.PODMAN_HOST = process.env.DOCKER_HOST;
  process.env.CONTAINER_HOST = process.env.DOCKER_HOST;
  log(`socket -> DOCKER_HOST=${process.env.DOCKER_HOST}`);
}

function projectNameFor(gitUrl: string, projectName: string): string {
  if (!gitUrl) {
    return path.basename(process.cwd());
  }
  return projectName || path.basename(gitUrl).replace(/\.git$/, "");
}

function ensureLatestClone(gitUrl: string, projectName: string): string {
  const target = path.join(WORKSPACE, projectName);
  if (!gitUrl) {
    log("GIT_URL not set; using mounted workspace");
    return target;
  }
  if (fs.existsSync(path.join(target, ".git"))) {
    log("project exists; git pull");
    const result = run("git", ["-C", target, "pull", "--ff-only"]);
    if (result.status !== 0) {
      failIfFailed(result);
    }
    return target;
  }
  log(`cloning ${gitUrl} -> ${projectName}`);
  const result = run("git", ["clone", gitUrl, target]);
  if (result.status !== 0) {
    failIfFailed(result);
  }
  return target;
}

function stripComments(source: string): string {
  let out = "";
  let inString = false;
  let escaped = false;
  for (let i = 0; i < source.length; i++) {
    const c = source.charAt(i);
    const next = source.charAt(i + 1);
    if (inString) {
      out += c;
      if (escaped) {
        escaped = false;
      } else if (c === "\\") {
        escaped = true;
      } else if (c === '"') {
        inString = false;
      }
      continue;
    }
    if (c === '"') {
      inString = true;
      out += c;
    } else if (c === "/" && next === "/") {
      i += 2;
      while (i < source.length && source.charAt(i) !== "\n") i++;
      out += "\n";
    } else if (c === "/" && next === "*") {
      i += 2;
      while (i < source.length && !(source.charAt(i) === "*" && source.charAt(i + 1) === "/")) i++;
      i++;
    } else {
      out += c;
    }
  }
  return out;
}

function stripTrailingCommas(source: string): string {
  let out = "";
  let inString = false;
  let escaped = false;
  for (let i = 0; i < source.length; i++) {
    const c = source.charAt(i);
    if (inString) {
      out += c;
      if (escaped) {
        escaped = false;
      } else if (c === "\\") {
        escaped = true;
      } else if (c === '"') {
        inString = false;
      }
      continue;
    }
    if (c === '"') {
      inString = true;
      out += c;
    } else if (c === ",") {
      let j = i + 1;
      while (j < source.length && /\s/.test(source.charAt(j))) j++;
      if (source.charAt(j) === "}" || source.charAt(j) === "]") continue;
      out += c;
    } else {
      out += c;
    }
  }
  return out;
}

function parseJsonc(source: string): Record<string, unknown> {
  return JSON.parse(stripTrailingCommas(stripComments(source))) as Record<string, unknown>;
}

function findConfig(projectPath: string, maxDepth = 3, depth = 0): string | null {
  if (depth > maxDepth) {
    return null;
  }
  for (const candidate of [".devcontainer/devcontainer.json", ".devcontainer.json"]) {
    const file = path.join(projectPath, candidate);
    if (fs.existsSync(file)) {
      return file;
    }
  }
  for (const entry of fs.readdirSync(projectPath, { withFileTypes: true })) {
    if (!entry.isDirectory() || entry.name === "node_modules") {
      continue;
    }
    const found = findConfig(path.join(projectPath, entry.name), maxDepth, depth + 1);
    if (found) {
      return found;
    }
  }
  return null;
}

function injectConfig(configPath: string, volume: string, proj: string, network: string, outPath: string): void {
  const config = parseJsonc(fs.readFileSync(configPath, "utf8"));
  config.workspaceMount = `type=volume,source=${volume},target=/workspace`;
  config.workspaceFolder = `/workspace/${proj}`;
  const runArgs = Array.isArray(config.runArgs) ? (config.runArgs as string[]) : [];
  const networkArg = `--network=${network}`;
  if (!runArgs.includes(networkArg)) {
    runArgs.push(networkArg);
  }
  config.runArgs = runArgs;
  fs.mkdirSync(path.dirname(outPath), { recursive: true });
  fs.writeFileSync(outPath, JSON.stringify(config, null, 2) + "\n");
  log(`injected ${outPath} (workspaceMount=${volume} -> /workspace, network=${network})`);
}

async function runDevcontainer(projectPath: string, configPath: string): Promise<string> {
  log(`launching dev container for ${projectPath}`);
  const child = spawn("devcontainer", [
    "up",
    "--docker-path", "/usr/bin/podman",
    "--workspace-folder", projectPath,
    "--config", configPath,
    "--mount-workspace-git-root=false",
  ]);
  let output = "";
  child.stdout.on("data", (chunk: Buffer) => {
    process.stdout.write(chunk);
    output += chunk.toString();
  });
  child.stderr.on("data", (chunk: Buffer) => {
    process.stderr.write(chunk);
    output += chunk.toString();
  });
  const code = await new Promise<number>((resolve) => child.on("close", resolve));
  if (code !== 0) {
    process.exit(code);
  }
  const match = output.match(/"containerId":"([0-9a-f]+)"/);
  return match ? match[1] : "";
}

function parseGitParts(gitUrl: string): { namespace: string; repo: string } {
  const body = gitUrl
    .replace(/\.git$/, "")
    .replace(/^[a-zA-Z0-9+.-]*:\/\//, "")
    .replace(/^[^@]*@/, "")
    .replace(/^[^/:]*[/:]/, "");
  const [namespace, repo] = body.split("/");
  return { namespace: namespace || "local", repo: repo || "project" };
}

function applyNaming(containerId: string, gitUrl: string, proj: string): void {
  if (!gitUrl || !containerId) {
    return;
  }
  const { namespace, repo } = parseGitParts(gitUrl);
  const localMachine = process.env.LOCAL_MACHINE ?? "local";
  const projPrefix = proj !== repo ? `${proj}.` : "";
  const wantedName = `${projPrefix}${localMachine}.${namespace}.${repo}.devcontainer`;
  const wantedImage = `${namespace}/${repo}-devcontainer`;

  const current = run("podman", ["inspect", "--type", "container", "-f", "{{.Name}}", containerId], {
    stdio: ["ignore", "pipe", "ignore"],
  });
  const currentName = current.stdout.trim().replace(/^\//, "");
  if (currentName !== wantedName) {
    const exists = run("podman", ["container", "exists", wantedName], {
      stdio: ["ignore", "pipe", "ignore"],
    });
    if (exists.status !== 0) {
      run("podman", ["rename", containerId, wantedName]);
      log(`renamed container to ${wantedName}`);
    }
  }

  const imageId = run("podman", ["inspect", "--type", "container", "-f", "{{.Image}}", containerId], {
    stdio: ["ignore", "pipe", "ignore"],
  }).stdout.trim();
  let currentImageId = "";
  const image = run("podman", ["image", "inspect", wantedImage, "--format", "{{.Id}}"], {
    stdio: ["ignore", "pipe", "ignore"],
  });
  if (image.status === 0) {
    currentImageId = image.stdout.trim();
  }
  if (imageId && currentImageId !== imageId) {
    run("podman", ["tag", imageId, wantedImage]);
    log(`tagged image to ${wantedImage}`);
  }
}

async function main(): Promise<void> {
  bindEngineSocket();

  const gitUrl = process.env.GIT_URL ?? "";
  const volume = process.env.WORKSPACE_VOLUME;
  if (!volume) {
    log("WORKSPACE_VOLUME is required");
    process.exit(1);
  }

  fs.mkdirSync(WORKSPACE, { recursive: true });
  const proj = projectNameFor(gitUrl, process.env.PROJECT_NAME ?? "");
  const projectPath = ensureLatestClone(gitUrl, proj);
  process.chdir(projectPath);

  const configPath = findConfig(projectPath);
  if (!configPath) {
    log(`no devcontainer.json found in ${projectPath}`);
    process.exit(1);
  }
  log(`config: ${configPath}`);

  injectConfig(configPath, volume, proj, process.env.NETWORK ?? "devnet", INJECTED_CONFIG);

  const containerId = await runDevcontainer(projectPath, INJECTED_CONFIG);
  applyNaming(containerId, gitUrl, proj);
}

main().catch((error) => {
  console.error(error);
  process.exit(1);
});