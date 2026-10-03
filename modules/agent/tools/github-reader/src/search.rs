use std::fmt::Write as _;

use serde::Deserialize;
use serde_json::Value;

use crate::{
    error::Error,
    github::{GitHub, encode, page_size},
    text::{Field, bounded},
};

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "lowercase")]
pub enum Kind {
    Code,
    Commits,
    Issues,
    Prs,
    Repos,
}

#[derive(Deserialize)]
#[serde(try_from = "String")]
pub struct Query(String);

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct SearchArgs {
    kind: Kind,
    limit: Option<u32>,
    query: Query,
}

impl TryFrom<String> for Query {
    type Error = Error;

    fn try_from(value: String) -> Result<Self, Error> {
        if (1..=256).contains(&value.trim().len()) {
            Ok(Self(value))
        } else {
            Err(Error::Argument(
                "a search query has 1 to 256 characters".to_owned(),
            ))
        }
    }
}

/// Append one item from the issue search endpoint, pull request or issue.
pub fn push_issue(out: &mut String, item: &Value) {
    let repo = item
        .text("repository_url")
        .strip_prefix("https://api.github.com/repos/")
        .unwrap_or_default();
    let state = if item["pull_request"]["merged_at"].is_string() {
        "merged"
    } else {
        item.text("state")
    };
    let draft = if item["draft"].as_bool().unwrap_or_default() {
        ", draft"
    } else {
        ""
    };
    let labels = item.names("labels");
    let _ = writeln!(
        out,
        "- {repo}#{} [{state}{draft}] {}\n  @{}, updated {}{}{labels}",
        item.count("number"),
        item.text("title"),
        item.login("user"),
        item.text("updated_at"),
        if labels.is_empty() { "" } else { ", labels: " },
    );
}

pub fn rate_limit(github: &GitHub) -> Result<String, Error> {
    let limits = github.get("/rate_limit")?;
    let mut out = String::from("# GitHub rate limits\n\n");
    for resource in ["core", "search", "graphql"] {
        let limit = &limits["resources"][resource];
        let _ = writeln!(
            out,
            "- {resource}: {} of {} left, resets at unix time {}",
            limit.count("remaining"),
            limit.count("limit"),
            limit.count("reset"),
        );
    }
    Ok(out)
}

pub fn search(github: &GitHub, args: &SearchArgs) -> Result<String, Error> {
    let Query(query) = &args.query;
    let (endpoint, query) = match args.kind {
        Kind::Code => ("code", query.clone()),
        Kind::Commits => ("commits", query.clone()),
        Kind::Issues => ("issues", format!("{query} is:issue")),
        Kind::Prs => ("issues", format!("{query} is:pr")),
        Kind::Repos => ("repositories", query.clone()),
    };
    let found = github.get(&format!(
        "/search/{endpoint}?q={}&per_page={}",
        encode(&query),
        page_size(args.limit),
    ))?;
    let items = found["items"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    let mut out = format!(
        "# Search: {query}\n\n{} of {} results\n\n",
        items.len(),
        found.count("total_count"),
    );
    for item in items {
        match args.kind {
            Kind::Code => {
                let _ = writeln!(
                    out,
                    "- {}:{}",
                    item["repository"].text("full_name"),
                    item.text("path")
                );
            }
            Kind::Commits => {
                let commit = &item["commit"];
                let _ = writeln!(
                    out,
                    "- {}@{} {}\n  {}, {}",
                    item["repository"].text("full_name"),
                    item.short_sha("sha"),
                    commit.text("message").lines().next().unwrap_or_default(),
                    commit["author"].text("name"),
                    commit["author"].text("date"),
                );
            }
            Kind::Issues | Kind::Prs => push_issue(&mut out, item),
            Kind::Repos => {
                let _ = writeln!(
                    out,
                    "- {} ({} stars, pushed {})\n  {}",
                    item.text("full_name"),
                    item.count("stargazers_count"),
                    item.text("pushed_at"),
                    item.text("description"),
                );
            }
        }
    }
    Ok(bounded(out))
}
