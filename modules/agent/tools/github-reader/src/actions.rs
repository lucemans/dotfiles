use std::fmt::Write as _;

use serde::Deserialize;
use serde_json::Value;

use crate::{
    error::Error,
    git_ref::GitRef,
    github::{GitHub, encode, page_size},
    repo::Repo,
    text::{Field, bounded},
};

const DEFAULT_LOG_LINES: usize = 300;
const MAX_CHECK_PAGES: usize = 3;
const MAX_JOB_PAGES: usize = 3;
const MAX_LOG_LINES: usize = 5_000;
const PASSING: [&str; 3] = ["success", "skipped", "neutral"];
const RUN_STATUSES: [&str; 14] = [
    "action_required",
    "cancelled",
    "completed",
    "failure",
    "in_progress",
    "neutral",
    "pending",
    "queued",
    "requested",
    "skipped",
    "stale",
    "success",
    "timed_out",
    "waiting",
];

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct ChecksArgs {
    #[serde(rename = "ref")]
    git_ref: GitRef,
    repo: Repo,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct LogArgs {
    job_id: u64,
    repo: Repo,
    tail: Option<usize>,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RunArgs {
    repo: Repo,
    run_id: u64,
}

#[derive(Deserialize)]
#[serde(deny_unknown_fields)]
pub struct RunsArgs {
    branch: Option<GitRef>,
    event: Option<String>,
    limit: Option<u32>,
    repo: Repo,
    status: Option<String>,
}

pub fn checks(github: &GitHub, args: &ChecksArgs) -> Result<String, Error> {
    let mut out = format!("# Checks for {}@{}\n\n", args.repo, args.git_ref);
    out.push_str(&check_summary(github, &args.repo, &args.git_ref.encoded())?);
    Ok(bounded(out))
}

/// Failing and pending check runs and commit statuses in full, passing ones by name.
pub fn check_summary(github: &GitHub, repo: &Repo, reference: &str) -> Result<String, Error> {
    let runs = github.pages(
        &format!("/repos/{repo}/commits/{reference}/check-runs"),
        Some("check_runs"),
        MAX_CHECK_PAGES,
    )?;
    let combined = github.get(&format!("/repos/{repo}/commits/{reference}/status"))?;
    let mut out = String::new();
    let mut passed = Vec::new();
    for run in &runs {
        let outcome = outcome(run);
        if PASSING.contains(&outcome) {
            passed.push(run.text("name"));
        } else {
            let _ = writeln!(
                out,
                "- [{outcome}] {} (job_id {})",
                run.text("name"),
                run.count("id")
            );
        }
    }
    for status in combined["statuses"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default()
    {
        let state = status.text("state");
        if state == "success" {
            passed.push(status.text("context"));
        } else {
            let _ = writeln!(
                out,
                "- [{state}] {}: {} {}",
                status.text("context"),
                status.text("description"),
                status.text("target_url"),
            );
        }
    }
    if out.is_empty() && passed.is_empty() {
        out.push_str("No checks reported.\n");
    }
    if !passed.is_empty() {
        let _ = writeln!(
            out,
            "Passed or skipped ({}): {}",
            passed.len(),
            passed.join(", ")
        );
    }
    Ok(out)
}

pub fn job_log(github: &GitHub, args: &LogArgs) -> Result<String, Error> {
    let log = github.job_log(&format!(
        "/repos/{}/actions/jobs/{}/logs",
        args.repo, args.job_id
    ))?;
    let lines: Vec<&str> = log.lines().map(without_timestamp).collect();
    let tail = args
        .tail
        .unwrap_or(DEFAULT_LOG_LINES)
        .clamp(1, MAX_LOG_LINES);
    let shown = &lines[lines.len().saturating_sub(tail)..];
    let mut out = format!(
        "# Log of job {} in {} (last {} of {} lines)\n\n",
        args.job_id,
        args.repo,
        shown.len(),
        lines.len(),
    );
    for line in shown {
        out.push_str(line);
        out.push('\n');
    }
    Ok(bounded(out))
}

pub fn run(github: &GitHub, args: &RunArgs) -> Result<String, Error> {
    let path = format!("/repos/{}/actions/runs/{}", args.repo, args.run_id);
    let run = github.get(&path)?;
    let jobs = github.pages(&format!("{path}/jobs"), Some("jobs"), MAX_JOB_PAGES)?;
    let mut out = format!(
        "# Run {} of {}: {} #{}\n\n",
        args.run_id,
        args.repo,
        run.text("name"),
        run.count("run_number"),
    );
    let _ = writeln!(out, "Title: {}", run.text("display_title"));
    let _ = writeln!(out, "Result: {}", outcome(&run));
    let _ = writeln!(
        out,
        "Branch: {}, commit {}, event {}, attempt {}",
        run.text("head_branch"),
        run.short_sha("head_sha"),
        run.text("event"),
        run.count("run_attempt"),
    );
    let _ = writeln!(
        out,
        "Started: {}, updated: {}",
        run.text("run_started_at"),
        run.text("updated_at")
    );
    let _ = writeln!(
        out,
        "URL: {}\n\n## Jobs ({})\n",
        run.text("html_url"),
        jobs.len()
    );
    for job in &jobs {
        let _ = writeln!(
            out,
            "- [{}] {} (job_id {})",
            outcome(job),
            job.text("name"),
            job.count("id")
        );
        let steps = job["steps"]
            .as_array()
            .map(Vec::as_slice)
            .unwrap_or_default();
        for step in steps
            .iter()
            .filter(|step| !PASSING.contains(&outcome(step)))
        {
            let _ = writeln!(
                out,
                "  - step {} [{}] {}",
                step.count("number"),
                outcome(step),
                step.text("name")
            );
        }
    }
    Ok(bounded(out))
}

pub fn runs(github: &GitHub, args: &RunsArgs) -> Result<String, Error> {
    let mut path = format!(
        "/repos/{}/actions/runs?per_page={}",
        args.repo,
        page_size(args.limit)
    );
    if let Some(branch) = &args.branch {
        let _ = write!(path, "&branch={}", branch.encoded());
    }
    if let Some(status) = &args.status {
        if !RUN_STATUSES.contains(&status.as_str()) {
            return Err(Error::Argument(format!(
                "status is one of {}",
                RUN_STATUSES.join(", ")
            )));
        }
        let _ = write!(path, "&status={status}");
    }
    if let Some(event) = &args.event {
        if event.is_empty()
            || !event
                .bytes()
                .all(|byte| byte.is_ascii_lowercase() || byte == b'_')
        {
            return Err(Error::Argument(format!(
                "{event:?} is not a workflow event"
            )));
        }
        let _ = write!(path, "&event={}", encode(event));
    }
    let found = github.get(&path)?;
    let runs = found["workflow_runs"]
        .as_array()
        .map(Vec::as_slice)
        .unwrap_or_default();
    let mut out = format!(
        "# Workflow runs in {} ({} of {})\n\n",
        args.repo,
        runs.len(),
        found.count("total_count"),
    );
    for run in runs {
        let _ = writeln!(
            out,
            "- run_id {} {} #{} [{}] {} {} @{}, {}\n  {}",
            run.count("id"),
            run.text("name"),
            run.count("run_number"),
            outcome(run),
            run.text("event"),
            run.text("head_branch"),
            run.short_sha("head_sha"),
            run.text("created_at"),
            run.text("display_title"),
        );
    }
    Ok(bounded(out))
}

/// The conclusion of a finished run, job, or step, or its status while it runs.
fn outcome(item: &Value) -> &str {
    item["conclusion"]
        .as_str()
        .unwrap_or_else(|| item.text("status"))
}

/// Actions prefixes every log line with an RFC 3339 timestamp.
fn without_timestamp(line: &str) -> &str {
    match line.split_once(' ') {
        Some((stamp, rest))
            if stamp.len() == 28 && stamp.ends_with('Z') && stamp.as_bytes()[10] == b'T' =>
        {
            rest
        }
        _ => line,
    }
}
