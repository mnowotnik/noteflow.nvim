import {
  createConnection,
  TextDocuments,
  Diagnostic,
  DiagnosticSeverity,
  ProposedFeatures,
  InitializeParams,
  DidChangeConfigurationNotification,
  CompletionItem,
  CompletionItemKind,
  TextDocumentPositionParams,
  TextDocumentSyncKind,
  InitializeResult,
  CancellationToken,
  WorkDoneProgressReporter,
  HandlerResult,
  DidOpenTextDocumentNotification,
  DidOpenTextDocumentParams,
  ExecuteCommandParams,
  DidChangeTextDocumentParams,
  DidChangeTextDocumentNotification,
  ExecuteCommandRequest,
  DidSaveTextDocumentParams,
  DidSaveTextDocumentNotification,
} from "vscode-languageserver/node";

import path from "path";
import tmp from "tmp";
import pino from "pino";
import fsPromises from "fs/promises";
import url from "url";
import * as mume from "@shd101wyy/mume";
import os from "os";
import fastify from "fastify";
import fastifyWs from "fastify-websocket";
import fastifyStatic from "fastify-static";
import { execFile } from "child_process";
import getPort from "get-port";

require("svelte/register")({
  generate: "ssr",
});

// state

class StateManager {
  previewMap: { [key: string]: string | null } = {};
  documentMap: { [key: string]: string } = {};
  socket: WebSocket | null = null;
  currentNote: object | null = null;
  url: string | null = null;

  constructor(private configPath: string) {}

  updateDocument = (uri: string, text: string) => {
    this.invalidatePreview(uri);
    this.documentMap[uri] = text;
  };

  invalidatePreview = (uri: string) => {
    this.previewMap[uri] = null;
  };

  updateNoteView = () => {
    if (this.currentNote == null || this.socket == null) {
      return;
    }
    this.socket.send(
      JSON.stringify({
        method: "updateNote",
        params: this.currentNote,
      })
    );
  };

  updateCurrentNote = async (uri: string) => {
    if (!this.documentMap[uri]) {
      return;
    }
    const filepath = url.fileURLToPath(uri);
    if (this.previewMap[uri]) {
      this.currentNote = {
        title: "-",
        html: this.previewMap[uri],
      };
      this.updateNoteView();
      return;
    }
    try {
      const engine = new mume.MarkdownEngine({
        filePath: filepath,
        projectDirectoryPath: "",
        config: {
          configPath: this.configPath,
          previewTheme: "github-light.css",
          codeBlockTheme: "default.css",
          printBackground: true,
          enableScriptExecution: true,
        },
      });
      const { html } = await engine.parseMD(this.documentMap[uri], {
        useRelativeFilePath: false,
        hideFrontMatter: true,
        isForPreview: false,
        runAllCodeChunks: false,
      });
      const noteHtml = await engine.generateHTMLTemplateForExport(
        html,
        {},
        {
          offline: false,
          isForPrint: false,
          isForPrince: false,
          embedLocalImages: false,
          embedSVG: true,
        }
      );

      const styleStart = noteHtml.indexOf("<style>");
      const styleEnd = noteHtml.indexOf("</style>");
      const style = noteHtml.substring(
        styleStart,
        styleEnd + "</style>".length
      );
      const bodyStart = noteHtml.indexOf("<body");
      const bodyEnd = noteHtml.indexOf("</body>");
      let body = noteHtml.substring(bodyStart, bodyEnd);
      body = body.replace(/(<body[^>]+>)/, `${style}`);
      this.previewMap[uri] = body;

      this.currentNote = {
        title: "-",
        html: body,
      };
      this.updateNoteView();
    } catch (err) {
      logger.error(`Error while reading note: ${err}`);
    }
  };
}

// logger
// -------

const logger = (() => {
  if (process.env.DEBUG_NOTEFLOW) {
    return pino(
      { level: "debug" },
      pino.destination(
        tmp.fileSync({
          mode: 0o700,
          prefix: "noteflow-server-",
          postfix: ".log",
        })
      )
    );
  }

  return pino({ level: "error" });
})();
const main = async () => {
  // lsp server
  const connection = createConnection(process.stdin, process.stdout);

  connection.onInitialize(
    (
      params: InitializeParams,
      token: CancellationToken,
      workDone: WorkDoneProgressReporter
    ): InitializeResult => {
      const capabilities = params.capabilities;
      logger.info(JSON.stringify(capabilities.workspace?.executeCommand));
      const result: InitializeResult = {
        serverInfo: {
          name: "noteflow-preview",
        },
        capabilities: {
          textDocumentSync: {
            change: TextDocumentSyncKind.Full,
            openClose: true,
            save: true,
          },
          executeCommandProvider: {
            // FIXME currently no other way to handle document focus
            // https://github.com/microsoft/language-server-protocol/issues/718
            commands: ["didFocusDocument", "openBrowser"],
          },
        },
      };
      return result;
    }
  );

  connection.onInitialized(() => {
    connection.client.register(DidOpenTextDocumentNotification.type);
    connection.client.register(DidChangeTextDocumentNotification.type, {
      documentSelector: null,
      // TODO only fetch edits
      syncKind: TextDocumentSyncKind.Full,
    });
    connection.client.register(ExecuteCommandRequest.type);
    connection.client.register(DidSaveTextDocumentNotification.type, {
      includeText: true,
      documentSelector: null,
    });
  });
  // TODO use local or user at ~/.config/noteflow/mume
  const configPath = path.resolve(os.homedir(), ".mume");

  const state = new StateManager(configPath);
  await mume.init(configPath); // default uses "~/.mume"

  // http server
  const app = fastify({
    logger,
  });

  app.register(fastifyWs);
  app.register(fastifyStatic, {
    root: path.resolve(__dirname, "..", "public"),
    prefix: "/static/",
  });

  // register websocket handler
  const { html } = require("./index.svelte").default.render();
  app.route({
    method: "GET",
    url: "/",
    handler: async (req, reply) => {
      reply.type("html");
      reply.send(html);
    },
    wsHandler: (conn, req) => {
      state.socket = conn.socket;
      state.updateNoteView();
    },
  });

  const port = await getPort({ port: 3000 });

  const serverUrl = (port: number): string => {
    return `http://localhost:${port}`;
  };

  const openBrowser = () => {
    if (process.platform === "darwin") {
      execFile("open", [serverUrl(port)]);
    } else {
      execFile("xdg-open", [serverUrl(port)]);
    }
  };

  const commandsMap = {
    openBrowser: (args?: any[]) => {
      openBrowser();
    },
    didFocusDocument: (args?: any[]) => {
      if (!args) return;
      state.updateCurrentNote(args[0] as string);
    },
  };

  connection.onDidSaveTextDocument((params: DidSaveTextDocumentParams) => {
    logger.debug("did save " + params.textDocument.uri);
    if (params.text) {
      state.updateDocument(params.textDocument.uri, params.text);
      state.updateCurrentNote(params.textDocument.uri);
    }
  });
  connection.onDidOpenTextDocument((params: DidOpenTextDocumentParams) => {
    logger.debug("did open " + params.textDocument.uri);
    state.updateDocument(params.textDocument.uri, params.textDocument.text);
    state.updateCurrentNote(params.textDocument.uri);
  });

  connection.onDidChangeTextDocument((params: DidChangeTextDocumentParams) => {
    logger.debug("did change " + params.textDocument.uri);
    const p = url.fileURLToPath(params.textDocument.uri);
    const changes = params.contentChanges;
    state.updateDocument(
      params.textDocument.uri,
      changes[changes.length - 1].text
    );
    state.updateCurrentNote(params.textDocument.uri);
  });

  connection.onExecuteCommand((params: ExecuteCommandParams) => {
    logger.debug("execute command  " + params.command);
    const command = params.command as keyof typeof commandsMap;
    commandsMap[command](params.arguments);
  });

  connection.listen();

  app.listen(port, (err) => {
    if (err) {
      app.log.error(err);
      process.exit(1);
    }
  });

  openBrowser();
};

main();
