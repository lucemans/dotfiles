use serde::de::DeserializeOwned;
use serde_json::{Value, json};

use crate::{
    actions,
    error::Error,
    github::GitHub,
    issues,
    listing::{self, Kind},
    pulls, repos, search,
};

pub fn call(github: &GitHub, name: &str, arguments: Value) -> Result<String, Error> {
    match name {
        "get_checks" => actions::checks(github, &parse(arguments)?),
        "get_issue" => issues::get(github, &parse(arguments)?),
        "get_job_log" => actions::job_log(github, &parse(arguments)?),
        "get_pull" => pulls::get(github, &parse(arguments)?),
        "get_pull_diff" => pulls::diff(github, &parse(arguments)?),
        "get_repo" => repos::get(github, &parse(arguments)?),
        "get_workflow_run" => actions::run(github, &parse(arguments)?),
        "list_issues" => listing::list(github, Kind::Issue, &parse(arguments)?),
        "list_pulls" => listing::list(github, Kind::Pull, &parse(arguments)?),
        "list_repos" => repos::list(github, &parse(arguments)?),
        "list_workflow_runs" => actions::runs(github, &parse(arguments)?),
        "rate_limit" => search::rate_limit(github),
        "search" => search::search(github, &parse(arguments)?),
        _ => Err(Error::Argument(format!("there is no tool named {name}"))),
    }
}

pub fn catalogue() -> Value {
    let repo = json!({"type": "string", "description": "Repository as owner/name"});
    let number = json!({"type": "integer", "minimum": 1});
    let limit = json!({"type": "integer", "minimum": 1, "maximum": 100, "description": "Items to return, 30 unless set"});
    let comments =
        json!({"type": "boolean", "description": "Include the discussion, true unless set"});
    let login = json!({"type": "string", "description": "GitHub login"});
    let label = json!({"type": "string", "description": "Label name"});
    json!([
        tool(
            "get_repo",
            "Repository metadata: description, default branch, visibility, language, stars, topics.",
            &json!({"repo": repo}),
            &["repo"]
        ),
        tool(
            "list_repos",
            "Repositories of a user or organization, most recently pushed first.",
            &json!({"owner": login, "limit": limit}),
            &["owner"]
        ),
        tool(
            "list_pulls",
            "Pull requests of a repository, most recently updated first.",
            &json!({"repo": repo, "state": {"enum": ["open", "closed", "merged", "all"], "description": "open unless set"},
                "author": login, "label": label, "limit": limit}),
            &["repo"]
        ),
        tool(
            "get_pull",
            "One pull request: state, branches, merge state, description, checks of the head commit, reviews, comments, and review comments.",
            &json!({"repo": repo, "number": number, "comments": comments}),
            &["repo", "number"]
        ),
        tool(
            "get_pull_diff",
            "Changed files of a pull request. Set file to a number from that list for one patch, or to \"all\" for every patch.",
            &json!({"repo": repo, "number": number, "file": {"type": "string"}}),
            &["repo", "number"]
        ),
        tool(
            "list_issues",
            "Issues of a repository, most recently updated first. Pull requests are excluded.",
            &json!({"repo": repo, "state": {"enum": ["open", "closed", "all"], "description": "open unless set"},
                "author": login, "label": label, "limit": limit}),
            &["repo"]
        ),
        tool(
            "get_issue",
            "One issue with its description and comments.",
            &json!({"repo": repo, "number": number, "comments": comments}),
            &["repo", "number"]
        ),
        tool(
            "get_checks",
            "Check runs and commit statuses of a branch, tag, or commit. Failures list their job_id for get_job_log.",
            &json!({"repo": repo, "ref": {"type": "string", "description": "Branch, tag, or commit SHA"}}),
            &["repo", "ref"]
        ),
        tool(
            "list_workflow_runs",
            "GitHub Actions runs of a repository, newest first.",
            &json!({"repo": repo, "branch": {"type": "string"}, "status": {"type": "string", "description": "For example failure, success, in_progress, queued"},
                "event": {"type": "string", "description": "For example push, pull_request, schedule"}, "limit": limit}),
            &["repo"]
        ),
        tool(
            "get_workflow_run",
            "One Actions run with its jobs. Steps that did not pass are listed under their job.",
            &json!({"repo": repo, "run_id": number}),
            &["repo", "run_id"]
        ),
        tool(
            "get_job_log",
            "The last lines of the log of one Actions job.",
            &json!({"repo": repo, "job_id": number, "tail": {"type": "integer", "minimum": 1, "maximum": 5000, "description": "Lines from the end, 300 unless set"}}),
            &["repo", "job_id"]
        ),
        tool(
            "search",
            "GitHub search with its qualifier syntax, for example \"org:v3xlabs is:open author:luc\".",
            &json!({"kind": {"enum": ["issues", "prs", "code", "commits", "repos"]}, "query": {"type": "string"}, "limit": limit}),
            &["kind", "query"]
        ),
        tool(
            "rate_limit",
            "Remaining GitHub API requests for the read-only token.",
            &json!({}),
            &[]
        ),
    ])
}

fn parse<T: DeserializeOwned>(arguments: Value) -> Result<T, Error> {
    serde_json::from_value(arguments).map_err(|error| Error::Argument(error.to_string()))
}

fn tool(name: &str, description: &str, properties: &Value, required: &[&str]) -> Value {
    json!({
        "name": name,
        "description": description,
        "inputSchema": {"type": "object", "properties": properties, "required": required, "additionalProperties": false},
        "annotations": {"readOnlyHint": true, "openWorldHint": true},
    })
}
