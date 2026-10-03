use std::{fmt, str::FromStr};

use serde::Deserialize;

use crate::{error::Error, github::encode};

/// A branch, tag, or commit SHA.
#[derive(Debug, Deserialize)]
#[serde(try_from = "String")]
pub struct GitRef(String);

impl GitRef {
    pub fn encoded(&self) -> String {
        encode(&self.0)
    }
}

impl fmt::Display for GitRef {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        f.write_str(&self.0)
    }
}

impl FromStr for GitRef {
    type Err = Error;

    fn from_str(value: &str) -> Result<Self, Error> {
        let valid = (1..=255).contains(&value.len())
            && !value.starts_with('-')
            && value
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || b"-._/".contains(&byte));
        if valid {
            Ok(Self(value.to_owned()))
        } else {
            Err(Error::Argument(format!(
                "{value:?} is not a branch, tag, or commit"
            )))
        }
    }
}

impl TryFrom<String> for GitRef {
    type Error = Error;

    fn try_from(value: String) -> Result<Self, Error> {
        value.parse()
    }
}
