import { spawn } from "node:child_process";
import fs from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import { parseSessionDocument } from "./core/detect.ts";
import { isRecord, parseJsonl, stringValue } from "./core/jsonl.ts";
import type { SessionDocument, SessionFormat } from "./core/types.ts";
import { buildSessionViewerHtml } from "./html.ts";
import { resolveFleetDeliveryCommand } from "./deliver-html.ts";

type Options = {
  blank: boolean;
  inputPath?: string;
  open: boolean;
  outPath?: string;
  raw: boolean;
};

type SessionInput = {
  chatPath: string;
  formatHint?: Exclude<SessionFormat, "unknown">;
  promptPath?: string;
  promptText?: string;
  sourcePath: string;
};

function usage(): string {
  return [
    "Usage:",
    "  node session-viewer.ts <session-or-directory> [--out session.html] [--open] [--raw]",
    "  node session-viewer.ts --blank [--out viewer.html] [--open]",
    "",
    "Options:",
    "  --blank        Write reusable file-picker viewer",
    "  --out PATH     Output HTML path",
    "  --open         Deliver to Anders's Mac with Fleet and open it",
    "  --raw          Embed one raw JSONL; subject bundles keep verified sidecars normalized",
    "  -h, --help     Show help",
  ].join("\n");
}

function parseArgs(argv: string[]): Options {
  const options: Options = { blank: false, open: false, raw: false };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "-h" || arg === "--help") {
      console.log(usage());
      process.exit(0);
    }
    if (arg === "--blank") {
      options.blank = true;
      continue;
    }
    if (arg === "--open") {
      options.open = true;
      continue;
    }
    if (arg === "--raw") {
      options.raw = true;
      continue;
    }
    if (arg === "--out") {
      const value = argv[index + 1];
      if (!value) {
        throw new Error("missing value after --out");
      }
      options.outPath = value;
      index += 1;
      continue;
    }
    if (arg.startsWith("-")) {
      throw new Error(`unknown option: ${arg}`);
    }
    if (options.inputPath) {
      throw new Error(`unexpected extra input: ${arg}`);
    }
    options.inputPath = arg;
  }
  if (!options.blank && !options.inputPath) {
    throw new Error("missing input session path");
  }
  return options;
}

function createTimestamp(): string {
  return new Date().toISOString().replace(/[-:.]/gu, "");
}

function defaultOutputPath(timestamp: string): string {
  return path.join(os.tmpdir(), `session-viewer-${timestamp}.html`);
}

async function resolveSessionInput(rawPath: string): Promise<SessionInput> {
  const sourcePath = path.resolve(rawPath);
  const stat = await fs.stat(sourcePath);
  if (stat.isDirectory()) {
    const analyticsMcpInput = await resolveAnalyticsMcpSubjectDirectory(sourcePath);
    if (analyticsMcpInput) {
      return analyticsMcpInput;
    }

    const grokChatPath = path.join(sourcePath, "chat_history.jsonl");
    try {
      if ((await fs.stat(grokChatPath)).isFile()) {
        return { sourcePath, chatPath: grokChatPath };
      }
    } catch (error) {
      if (!isMissingPath(error)) throw error;
    }

    const cursorPath = path.join(sourcePath, `${path.basename(sourcePath)}.jsonl`);
    try {
      if ((await fs.stat(cursorPath)).isFile()) {
        return { sourcePath, chatPath: cursorPath };
      }
    } catch (error) {
      if (!isMissingPath(error)) throw error;
    }

    const jsonlFiles = (await fs.readdir(sourcePath, { withFileTypes: true }))
      .filter((entry) => entry.isFile() && entry.name.endsWith(".jsonl"));
    if (jsonlFiles.length === 1) {
      return { sourcePath, chatPath: path.join(sourcePath, jsonlFiles[0].name) };
    }
    throw new Error(`session directory does not contain one recognizable JSONL transcript: ${sourcePath}`);
  }
  if (path.basename(sourcePath) === "summary.json") {
    return { sourcePath, chatPath: path.join(path.dirname(sourcePath), "chat_history.jsonl") };
  }
  return { sourcePath, chatPath: sourcePath };
}

async function resolveAnalyticsMcpSubjectDirectory(
  sourcePath: string,
): Promise<SessionInput | null> {
  const manifestPath = path.join(sourcePath, "manifest.json");
  const promptPath = path.join(sourcePath, "prompt.txt");
  const tracePath = path.join(sourcePath, "trace.jsonl");
  try {
    const [manifestStat, promptStat, traceStat] = await Promise.all([
      fs.stat(manifestPath),
      fs.stat(promptPath),
      fs.stat(tracePath),
    ]);
    if (!manifestStat.isFile() || !promptStat.isFile() || !traceStat.isFile()) {
      return null;
    }
  } catch (error) {
    if (isMissingPath(error)) return null;
    throw error;
  }

  const manifest = JSON.parse(await fs.readFile(manifestPath, "utf8")) as unknown;
  const subject = isRecord(manifest) && isRecord(manifest.subject) ? manifest.subject : undefined;
  const product = stringValue(subject?.product);
  const formatHint = sessionFormatForProduct(product);
  return {
    chatPath: tracePath,
    formatHint,
    promptPath,
    promptText: await fs.readFile(promptPath, "utf8"),
    sourcePath,
  };
}

function sessionFormatForProduct(
  product: string | undefined,
): Exclude<SessionFormat, "unknown"> | undefined {
  return product === "codex" || product === "claude" || product === "grok"
    ? product
    : undefined;
}

function prependPreservedPrompt(document: SessionDocument, input: SessionInput): void {
  if (input.promptText === undefined || input.promptText.length === 0) {
    return;
  }
  const alreadyPresent = document.events.some(
    (event) => event.kind === "message" && event.role === "user" && event.text === input.promptText,
  );
  if (alreadyPresent) {
    return;
  }
  document.events.unshift({
    id: "analytics-mcp-user-prompt",
    kind: "message",
    role: "user",
    title: "user",
    text: input.promptText,
    raw: { source: input.promptPath },
  });
}

function isMissingPath(error: unknown): boolean {
  return error instanceof Error && "code" in error && error.code === "ENOENT";
}

async function deliverAndOpen(filePath: string, timestamp: string): Promise<void> {
  const command = resolveFleetDeliveryCommand(filePath, timestamp);
  await new Promise<void>((resolve, reject) => {
    const child = spawn(command.executable, command.args, { stdio: "inherit" });
    child.once("error", reject);
    child.once("close", (code, signal) => {
      if (code === 0) {
        resolve();
        return;
      }
      reject(
        new Error(
          signal
            ? `fleet delivery stopped by signal ${signal}`
            : `fleet delivery exited with status ${code ?? "unknown"}`,
        ),
      );
    });
  });
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));
  const timestamp = createTimestamp();
  const outputPath = path.resolve(
    options.outPath ?? defaultOutputPath(timestamp),
  );
  await fs.mkdir(path.dirname(outputPath), { recursive: true });

  if (options.blank) {
    const html = buildSessionViewerHtml(null, { embedMode: "blank" });
    await fs.writeFile(outputPath, html, "utf8");
    console.log(`wrote: ${outputPath}`);
    if (options.open) {
      await deliverAndOpen(outputPath, timestamp);
    }
    return;
  }

  const input = await resolveSessionInput(options.inputPath ?? "");
  const rawText = await fs.readFile(input.chatPath, "utf8");
  const { records, warnings } = parseJsonl(rawText);
  const document = parseSessionDocument(records, input.sourcePath, input.formatHint);
  prependPreservedPrompt(document, input);
  document.warnings.unshift(...warnings);
  const normalizeBundle = options.raw && input.promptText !== undefined;
  if (normalizeBundle) {
    document.warnings.push(
      "Analytics MCP subject directories use normalized embedding so prompt.txt and trace.jsonl stay together.",
    );
  }
  const html = buildSessionViewerHtml(document, {
    embedMode: options.raw && !normalizeBundle ? "raw" : "normalized",
    rawText,
  });
  await fs.writeFile(outputPath, html, "utf8");
  console.log(`wrote: ${outputPath}`);
  console.log(`format: ${document.format}`);
  console.log(`events: ${document.events.length}`);
  if (document.warnings.length > 0) {
    console.log(`warnings: ${document.warnings.length}`);
  }
  if (options.open) {
    await deliverAndOpen(outputPath, timestamp);
  }
}

main().catch((error: unknown) => {
  const message = error instanceof Error ? error.message : String(error);
  console.error(message);
  process.exit(1);
});
