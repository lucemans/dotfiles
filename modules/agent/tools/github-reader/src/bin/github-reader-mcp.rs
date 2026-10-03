//! The MCP server command a harness starts: it joins stdin and stdout to the
//! github-reader socket, so the token stays with the daemon outside the sandbox.

use std::{
    io::{self, Write},
    net::Shutdown,
    os::unix::net::UnixStream,
    process::ExitCode,
    thread,
};

const SOCKET_PATH: &str = "/run/github-reader/socket";

fn main() -> ExitCode {
    match bridge() {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("github-reader-mcp: {SOCKET_PATH}: {error}");
            ExitCode::FAILURE
        }
    }
}

fn bridge() -> io::Result<()> {
    let stream = UnixStream::connect(SOCKET_PATH)?;
    let mut upstream = stream.try_clone()?;
    thread::spawn(move || {
        let _ = io::copy(&mut io::stdin().lock(), &mut upstream);
        let _ = upstream.shutdown(Shutdown::Write);
    });
    let mut stdout = io::stdout().lock();
    io::copy(&mut &stream, &mut stdout)?;
    stdout.flush()
}
