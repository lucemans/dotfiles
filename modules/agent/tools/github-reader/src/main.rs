mod actions;
mod error;
mod git_ref;
mod github;
mod issues;
mod listing;
mod owner;
mod pulls;
mod repo;
mod repos;
mod search;
mod session;
mod text;
mod tools;

use std::{
    env, fs,
    io::{self, BufReader},
    os::{fd::FromRawFd, unix::net::UnixListener},
    path::Path,
    process::{self, ExitCode},
    sync::Arc,
    thread,
};

use crate::{github::GitHub, session::Session};

const SYSTEMD_FIRST_FD: i32 = 3;

/// Serves the clients of the systemd socket, or one client on stdin and
/// stdout when started by hand.
fn main() -> ExitCode {
    let token = match load_token() {
        Ok(token) => token,
        Err(error) => {
            eprintln!("github-reader: cannot read the token credential: {error}");
            return ExitCode::FAILURE;
        }
    };
    let github = Arc::new(GitHub::new(token));
    let result = match systemd_listener() {
        Some(listener) => {
            serve(&listener, &github);
            Ok(())
        }
        None => Session::new(&github, io::stdin().lock(), io::stdout().lock()).run(),
    };
    match result {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("github-reader: {error}");
            ExitCode::FAILURE
        }
    }
}

/// The token systemd passes with `LoadCredential=token:…`. Started by hand,
/// there is none and requests are anonymous.
fn load_token() -> io::Result<Option<String>> {
    let Some(directory) = env::var_os("CREDENTIALS_DIRECTORY") else {
        eprintln!("github-reader: no credential, requests are anonymous");
        return Ok(None);
    };
    let token = fs::read_to_string(Path::new(&directory).join("token"))?;
    Ok(Some(token.trim().to_owned()))
}

fn serve(listener: &UnixListener, github: &Arc<GitHub>) {
    for stream in listener.incoming() {
        let stream = match stream {
            Ok(stream) => stream,
            Err(error) => {
                eprintln!("github-reader: accept failed: {error}");
                continue;
            }
        };
        let github = Arc::clone(github);
        thread::spawn(move || {
            let result = stream
                .try_clone()
                .and_then(|reader| Session::new(&github, BufReader::new(reader), stream).run());
            if let Err(error) = result {
                eprintln!("github-reader: session ended: {error}");
            }
        });
    }
}

fn systemd_listener() -> Option<UnixListener> {
    let for_us = env::var("LISTEN_PID").ok()?.parse::<u32>().ok()? == process::id();
    let one = env::var("LISTEN_FDS").ok()? == "1";
    // SAFETY: with LISTEN_PID naming this process and LISTEN_FDS=1, systemd
    // passed exactly one listening socket at fd 3, and nothing else owns it.
    (for_us && one).then(|| unsafe { UnixListener::from_raw_fd(SYSTEMD_FIRST_FD) })
}
