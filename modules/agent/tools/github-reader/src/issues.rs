use std::fmt::Write as _;

use serde::Deserialize;

use crate::{
    error::Error,
    github::GitHub,
    repo::Repo,
    text::{Field, bounded, push_comment},
};

const MAX_COMMENT_PAGES: usize = 10;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GetArgs {
    comments: Option<bool>,
    number: u64,
    repo: Repo,
}

pub fn get(github: &GitHub, args: &GetArgs) -> Result<String, Error> {
    let path = format!("/repos/{}/issues/{}", args.repo, args.number);
    let issue = github.get(&path)?;
    let mut out = format!(
        "# {}#{}: {}\n\n",
        args.repo,
        args.number,
        issue.text("title")
    );
    if issue["pull_request"].is_object() {
        out.push_str(
            "This number is a pull request; get_pull shows its review, merge, and check state.\n\n",
        );
    }
    let state = match issue.text("state_reason") {
        "" => issue.text("state").to_owned(),
        reason => format!("{} ({reason})", issue.text("state")),
    };
    let _ = writeln!(out, "State: {state}");
    let _ = writeln!(out, "Author: @{}", issue.login("user"));
    let _ = writeln!(
        out,
        "Created: {}, updated: {}",
        issue.text("created_at"),
        issue.text("updated_at")
    );
    let _ = writeln!(out, "Labels: {}", issue.names("labels"));
    let _ = writeln!(out, "Assignees: {}", issue.names("assignees"));
    let _ = writeln!(out, "URL: {}\n\n## Description\n", issue.text("html_url"));
    let _ = writeln!(out, "{}\n", issue.text("body").trim());
    if args.comments.unwrap_or(true) {
        let comments = github.pages(&format!("{path}/comments"), None, MAX_COMMENT_PAGES)?;
        let _ = writeln!(out, "## Comments ({})\n", comments.len());
        for comment in &comments {
            push_comment(&mut out, comment, "");
        }
    }
    Ok(bounded(out))
}
