use std::{fmt, io};

#[derive(Debug)]
pub enum Error {
    Argument(String),
    Http(ureq::Error),
    Io(io::Error),
    Json(serde_json::Error),
    Status { status: u16, message: String },
}

impl fmt::Display for Error {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Argument(message) => f.write_str(message),
            Self::Http(error) => write!(f, "GitHub request failed: {error}"),
            Self::Io(error) => write!(f, "I/O failed: {error}"),
            Self::Json(error) => write!(f, "GitHub sent invalid JSON: {error}"),
            Self::Status { status, message } => write!(f, "GitHub returned {status}: {message}"),
        }
    }
}

impl std::error::Error for Error {}

impl From<io::Error> for Error {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

impl From<serde_json::Error> for Error {
    fn from(error: serde_json::Error) -> Self {
        Self::Json(error)
    }
}

impl From<ureq::Error> for Error {
    fn from(error: ureq::Error) -> Self {
        Self::Http(error)
    }
}
