use std::fmt::Write as _;

use serde::Deserialize;
use serde_json::Value;

use crate::{
    error::Error,
    github::{GitHub, page_size},
    owner::Owner,
    repo::Repo,
    text::{Field, bounded},
};

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GetArgs {
    repo: Repo,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ListArgs {
    limit: Option<u32>,
    owner: Owner,
}

pub fn get(github: &GitHub, args: &GetArgs) -> Result<String, Error> {
    let repo = github.get(&format!("/repos/{}", args.repo))?;
    let mut out = format!("# {}\n\n", repo.text("full_name"));
    let _ = writeln!(out, "{}\n", repo.text("description"));
    let _ = writeln!(out, "URL: {}", repo.text("html_url"));
    let _ = writeln!(out, "Default branch: {}", repo.text("default_branch"));
    let _ = writeln!(
        out,
        "Visibility: {}{}",
        repo.text("visibility"),
        flags(&repo)
    );
    let _ = writeln!(out, "Language: {}", repo.text("language"));
    let _ = writeln!(
        out,
        "Stars: {}, forks: {}, open issues and PRs: {}",
        repo.count("stargazers_count"),
        repo.count("forks_count"),
        repo.count("open_issues_count"),
    );
    let _ = writeln!(out, "Topics: {}", topics(&repo));
    let _ = writeln!(
        out,
        "Pushed: {}, updated: {}",
        repo.text("pushed_at"),
        repo.text("updated_at")
    );
    Ok(out)
}

pub fn list(github: &GitHub, args: &ListArgs) -> Result<String, Error> {
    let query = format!("repos?sort=pushed&per_page={}", page_size(args.limit));
    let repos = match github.get(&format!("/orgs/{}/{query}", args.owner)) {
        Err(Error::Status { status: 404, .. }) => {
            github.get(&format!("/users/{}/{query}", args.owner))?
        }
        result => result?,
    };
    let repos = repos.as_array().map(Vec::as_slice).unwrap_or_default();
    let mut out = format!(
        "# Repositories of {} ({} shown, most recently pushed first)\n\n",
        args.owner,
        repos.len()
    );
    for repo in repos {
        let _ = writeln!(
            out,
            "- {} [{}{}] {} stars, pushed {}\n  {}",
            repo.text("full_name"),
            repo.text("visibility"),
            flags(repo),
            repo.count("stargazers_count"),
            repo.text("pushed_at"),
            repo.text("description"),
        );
    }
    Ok(bounded(out))
}

fn flags(repo: &Value) -> String {
    let mut flags = String::new();
    for flag in ["archived", "fork"] {
        if repo[flag].as_bool().unwrap_or_default() {
            flags.push_str(", ");
            flags.push_str(flag);
        }
    }
    flags
}

fn topics(repo: &Value) -> String {
    repo["topics"]
        .as_array()
        .map(|topics| {
            topics
                .iter()
                .filter_map(Value::as_str)
                .collect::<Vec<_>>()
                .join(", ")
        })
        .unwrap_or_default()
}
