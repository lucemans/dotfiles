use std::{fmt, str::FromStr};

use serde::Deserialize;

use crate::{error::Error, owner::Owner};

#[derive(Debug, Deserialize)]
#[serde(try_from = "String")]
pub struct Repo {
    owner: Owner,
    name: String,
}

impl fmt::Display for Repo {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        write!(f, "{}/{}", self.owner, self.name)
    }
}

impl FromStr for Repo {
    type Err = Error;

    fn from_str(value: &str) -> Result<Self, Error> {
        let invalid = || Error::Argument(format!("{value:?} is not an owner/name repository"));
        let (owner, name) = value.split_once('/').ok_or_else(invalid)?;
        let valid_name = (1..=100).contains(&name.len())
            && name != "."
            && name != ".."
            && name
                .bytes()
                .all(|byte| byte.is_ascii_alphanumeric() || b"-._".contains(&byte));
        if !valid_name {
            return Err(invalid());
        }
        Ok(Self {
            owner: owner.parse()?,
            name: name.to_owned(),
        })
    }
}

impl TryFrom<String> for Repo {
    type Error = Error;

    fn try_from(value: String) -> Result<Self, Error> {
        value.parse()
    }
}
