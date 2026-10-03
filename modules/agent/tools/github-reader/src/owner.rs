use std::{fmt, str::FromStr};

use serde::Deserialize;

use crate::error::Error;

/// A GitHub user or organization login.
#[derive(Debug, Deserialize)]
#[serde(try_from = "String")]
pub struct Owner(String);

impl fmt::Display for Owner {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl FromStr for Owner {
    type Err = Error;

    fn from_str(value: &str) -> Result<Self, Error> {
        let valid = (1..=39).contains(&value.len())
            && !value.starts_with('-')
            && value
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || byte == b'-');
        if valid {
            Ok(Self(value.to_owned()))
        } else {
            Err(Error::Argument(format!("{value:?} is not a GitHub login")))
        }
    }
}

impl TryFrom<String> for Owner {
    type Error = Error;

    fn try_from(value: String) -> Result<Self, Error> {
        value.parse()
    }
}
