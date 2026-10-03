use std::fmt::Write as _;

use serde::Deserialize;
use serde_json::Value;

use crate::{
    actions::check_summary,
    error::Error,
    github::{GitHub, encode},
    repo::Repo,
    text::{Field, bounded, push_comment},
};

const MAX_COMMENT_PAGES: usize = 10;
const MAX_FILE_PAGES: usize = 30;

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct DiffArgs {
    file: Option<String>,
    number: u64,
    repo: Repo,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct GetArgs {
    comments: Option<bool>,
    number: u64,
    repo: Repo,
}

/// The changed files of a pull request, the patch of one file by its 1-based
/// index, or every patch for `file = "all"`.
pub fn diff(github: &GitHub, args: &DiffArgs) -> Result<String, Error> {
    let files = github.pages(
        &format!("/repos/{}/pulls/{}/files", args.repo, args.number),
        None,
        MAX_FILE_PAGES,
    )?;
    let mut out = String::new();
    match args.file.as_deref() {
        None => {
            let _ = writeln!(
                out,
                "# Files of {}#{} ({})\n",
                args.repo,
                args.number,
                files.len()
            );
            for (index, file) in files.iter().enumerate() {
                let renamed = match file.text("previous_filename") {
                    "" => String::new(),
                    previous => format!(", from {previous}"),
                };
                let _ = writeln!(
                    out,
                    "{}. {} +{} -{} [{}{renamed}]",
                    index + 1,
                    file.text("filename"),
                    file.count("additions"),
                    file.count("deletions"),
                    file.text("status"),
                );
            }
            out.push_str("\nRead one patch with file set to its number, or every patch with file set to \"all\".\n");
        }
        Some("all") => files.iter().for_each(|file| push_patch(&mut out, file)),
        Some(index) => {
            let file = index
                .parse::<usize>()
                .ok()
                .and_then(|index| files.get(index.checked_sub(1)?))
                .ok_or_else(|| {
                    Error::Argument(format!(
                        "file is \"all\" or a number from 1 to {}",
                        files.len()
                    ))
                })?;
            push_patch(&mut out, file);
        }
    }
    Ok(bounded(out))
}

pub fn get(github: &GitHub, args: &GetArgs) -> Result<String, Error> {
    let path = format!("/repos/{}/pulls/{}", args.repo, args.number);
    let pull = github.get(&path)?;
    let mut out = format!(
        "# {}#{}: {}\n\n",
        args.repo,
        args.number,
        pull.text("title")
    );
    let _ = writeln!(out, "State: {}", state(&pull));
    let _ = writeln!(
        out,
        "Author: @{}, base {} <- head {} @{}",
        pull.login("user"),
        pull["base"].text("ref"),
        pull["head"].text("label"),
        pull["head"].short_sha("sha"),
    );
    let _ = writeln!(
        out,
        "Created: {}, updated: {}",
        pull.text("created_at"),
        pull.text("updated_at")
    );
    let _ = writeln!(
        out,
        "Merge state: {}, +{} -{} in {} files, {} commits",
        pull.text("mergeable_state"),
        pull.count("additions"),
        pull.count("deletions"),
        pull.count("changed_files"),
        pull.count("commits"),
    );
    let _ = writeln!(out, "Labels: {}", pull.names("labels"));
    let _ = writeln!(
        out,
        "Requested reviewers: {}",
        pull.names("requested_reviewers")
    );
    let _ = writeln!(out, "URL: {}\n\n## Description\n", pull.text("html_url"));
    let _ = writeln!(out, "{}\n\n## Checks\n", pull.text("body").trim());
    out.push_str(&check_summary(
        github,
        &args.repo,
        &encode(pull["head"].text("sha")),
    )?);
    if args.comments.unwrap_or(true) {
        // An empty COMMENTED review only groups review comments, which follow below.
        let reviews: Vec<_> = github
            .pages(&format!("{path}/reviews"), None, MAX_COMMENT_PAGES)?
            .into_iter()
            .filter(|review| {
                review.text("state") != "COMMENTED" || !review.text("body").trim().is_empty()
            })
            .collect();
        let comments = github.pages(
            &format!("/repos/{}/issues/{}/comments", args.repo, args.number),
            None,
            MAX_COMMENT_PAGES,
        )?;
        let review_comments = github.pages(&format!("{path}/comments"), None, MAX_COMMENT_PAGES)?;
        let _ = writeln!(out, "\n## Reviews ({})\n", reviews.len());
        for review in &reviews {
            push_comment(&mut out, review, &format!(" {}", review.text("state")));
        }
        let _ = writeln!(out, "## Comments ({})\n", comments.len());
        for comment in &comments {
            push_comment(&mut out, comment, "");
        }
        let _ = writeln!(out, "## Review comments ({})\n", review_comments.len());
        for comment in &review_comments {
            let line = comment["line"]
                .as_u64()
                .or_else(|| comment["original_line"].as_u64());
            let location = match line {
                Some(line) => format!(" on {}:{line}", comment.text("path")),
                None => format!(" on {}", comment.text("path")),
            };
            push_comment(&mut out, comment, &location);
        }
    }
    Ok(bounded(out))
}

fn push_patch(out: &mut String, file: &Value) {
    let path = file.text("filename");
    let previous = match file.text("previous_filename") {
        "" => path,
        previous => previous,
    };
    let _ = writeln!(out, "diff --git a/{previous} b/{path}");
    match file["patch"].as_str() {
        Some(text) => {
            out.push_str(text);
            out.push('\n');
        }
        None => out.push_str("(no text patch: binary file or patch too large)\n"),
    }
}

fn state(pull: &Value) -> String {
    if pull["merged"].as_bool().unwrap_or_default() {
        format!(
            "merged by @{} at {}",
            pull.login("merged_by"),
            pull.text("merged_at")
        )
    } else if pull.text("state") == "closed" {
        format!("closed at {}", pull.text("closed_at"))
    } else if pull["draft"].as_bool().unwrap_or_default() {
        "open, draft".to_owned()
    } else {
        "open".to_owned()
    }
}
