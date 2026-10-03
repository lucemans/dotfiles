use std::io::{self, BufRead, Read, Write};

use serde_json::{Value, json};

use crate::{github::GitHub, tools};

const INSTRUCTIONS: &str = "Read-only GitHub: pull requests, issues, CI checks, Actions runs and logs, repositories, and search. Nothing here can write to GitHub. Read file contents with repo_reader.";
const MAX_LINE_BYTES: u64 = 1024 * 1024;
const PROTOCOL_VERSION: &str = "2025-06-18";

/// One MCP client over newline-delimited JSON-RPC.
pub struct Session<'a, R, W> {
    github: &'a GitHub,
    reader: R,
    writer: W,
}

impl<'a, R: BufRead, W: Write> Session<'a, R, W> {
    pub fn new(github: &'a GitHub, reader: R, writer: W) -> Self {
        Self {
            github,
            reader,
            writer,
        }
    }

    pub fn run(mut self) -> io::Result<()> {
        let mut line = String::new();
        loop {
            line.clear();
            if (&mut self.reader)
                .take(MAX_LINE_BYTES)
                .read_line(&mut line)?
                == 0
            {
                return Ok(());
            }
            if !line.trim().is_empty() {
                let response = match serde_json::from_str(&line) {
                    Ok(request) => self.respond(&request),
                    Err(error) => Some(failure(&Value::Null, -32700, &error.to_string())),
                };
                if let Some(response) = response {
                    serde_json::to_writer(&mut self.writer, &response)?;
                    self.writer.write_all(b"\n")?;
                    self.writer.flush()?;
                }
            }
            // A line without a newline is the end of input or longer than the limit.
            if !line.ends_with('\n') {
                return Ok(());
            }
        }
    }

    fn call(&self, params: &Value) -> Value {
        let name = params["name"].as_str().unwrap_or_default();
        let arguments = match &params["arguments"] {
            Value::Null => json!({}),
            arguments => arguments.clone(),
        };
        match tools::call(self.github, name, arguments) {
            Ok(text) => json!({"content": [{"type": "text", "text": text}]}),
            Err(error) => {
                json!({"content": [{"type": "text", "text": error.to_string()}], "isError": true})
            }
        }
    }

    /// The response to one request, or nothing for a notification.
    fn respond(&self, request: &Value) -> Option<Value> {
        let id = request.get("id")?;
        let params = &request["params"];
        let result = match request["method"].as_str().unwrap_or_default() {
            "initialize" => json!({
                "protocolVersion": params["protocolVersion"].as_str().unwrap_or(PROTOCOL_VERSION),
                "capabilities": {"tools": {}},
                "serverInfo": {"name": "github-reader", "version": env!("CARGO_PKG_VERSION")},
                "instructions": INSTRUCTIONS,
            }),
            "ping" => json!({}),
            "tools/call" => self.call(params),
            "tools/list" => json!({"tools": tools::catalogue()}),
            method => return Some(failure(id, -32601, &format!("method not found: {method}"))),
        };
        Some(json!({"jsonrpc": "2.0", "id": id, "result": result}))
    }
}

fn failure(id: &Value, code: i64, message: &str) -> Value {
    json!({"jsonrpc": "2.0", "id": id, "error": {"code": code, "message": message}})
}
