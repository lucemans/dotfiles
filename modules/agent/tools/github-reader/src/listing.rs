use std::fmt::Write as _;

use serde::Deserialize;

use crate::{
    error::Error,
    github::{GitHub, encode, page_size},
    owner::Owner,
    repo::Repo,
    search::push_issue,
    text::{Field, bounded},
};

#[derive(Clone, Copy)]
pub enum Kind {
    Issue,
    Pull,
}

#[derive(Clone, Copy, Default, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum State {
    All,
    Closed,
    Merged,
    #[default]
    Open,
}

#[derive(Deserialize)]
#[serde(try_from = "String")]
pub struct Label(String);

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ListArgs {
    author: Option<Owner>,
    label: Option<Label>,
    limit: Option<u32>,
    repo: Repo,
    #[serde(default)]
    state: State,
}

impl Kind {
    fn noun(self) -> &'static str {
        match self {
            Self::Issue => "Issues",
            Self::Pull => "Pull requests",
        }
    }

    fn qualifier(self) -> &'static str {
        match self {
            Self::Issue => "is:issue",
            Self::Pull => "is:pr",
        }
    }
}

impl TryFrom<String> for Label {
    type Error = Error;

    fn try_from(value: String) -> Result<Self, Error> {
        if (1..=50).contains(&value.len()) && !value.contains('"') {
            Ok(Self(value))
        } else {
            Err(Error::Argument(format!("{value:?} is not a label name")))
        }
    }
}

/// Newest-updated pull requests or issues of one repository, through the
/// search endpoint because it is the only list that filters on all of state,
/// author, and label.
pub fn list(github: &GitHub, kind: Kind, args: &ListArgs) -> Result<String, Error> {
    let mut query = format!("repo:{} {}", args.repo, kind.qualifier());
    match (args.state, kind) {
        (State::All, _) => {}
        (State::Closed, _) => query.push_str(" is:closed"),
        (State::Merged, Kind::Pull) => query.push_str(" is:merged"),
        (State::Merged, Kind::Issue) => {
            return Err(Error::Argument("issues have no merged state".to_owned()));
        }
        (State::Open, _) => query.push_str(" is:open"),
    }
    if let Some(author) = &args.author {
        let _ = write!(query, " author:{author}");
    }
    if let Some(Label(label)) = &args.label {
        let _ = write!(query, " label:\"{label}\"");
    }
    let found = github.get(&format!(
        "/search/issues?q={}&sort=updated&order=desc&per_page={}",
        encode(&query),
        page_size(args.limit),
    ))?;
    let items = found["items"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    let mut out = format!(
        "# {} in {} ({query})\n\n{} of {} shown\n\n",
        kind.noun(),
        args.repo,
        items.len(),
        found.count("total_count"),
    );
    for item in items {
        push_issue(&mut out, item);
    }
    Ok(bounded(out))
}
