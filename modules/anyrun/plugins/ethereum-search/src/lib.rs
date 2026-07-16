use abi_stable::std_types::{ROption, RString, RVec};
use anyrun_plugin::*;
use regex::Regex;
use serde::{Deserialize, Serialize};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::sync::OnceLock;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const CACHE_TTL: Duration = Duration::from_secs(24 * 3600);

#[derive(Clone, Serialize, Deserialize)]
struct Proposal {
    number: u32,
    title: String,
    kind: String,
}

#[derive(Clone)]
struct PullRequest {
    repo: String,
    number: u32,
    title: String,
    state: String,
    url: String,
}

#[derive(Serialize, Deserialize)]
struct Cache {
    fetched_at: u64,
    proposals: Vec<Proposal>,
}

#[derive(Default)]
struct State {
    proposals: Vec<Proposal>,
    pull_requests: HashMap<(String, u32), Option<PullRequest>>,
}

fn now() -> u64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|duration| duration.as_secs())
        .unwrap_or(0)
}

fn cache_path() -> PathBuf {
    let base = std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(std::env::var_os("HOME").unwrap_or_default()).join(".cache"));
    base.join("anyrun-plugins/eip-index.json")
}

fn index_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r#"<a href="/EIPS/eip-(\d+)">\d+</a></td>\s*<td class="title">([^<]+)</td>"#).unwrap())
}

fn pull_request_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"^(eips|ercs)(?:\s*(?:pr)?#?\s*)(\d+)$").unwrap())
}

fn number_pattern() -> &'static Regex {
    static PATTERN: OnceLock<Regex> = OnceLock::new();
    PATTERN.get_or_init(|| Regex::new(r"^(?:(eip|erc)[\s-]*)?(\d+)$").unwrap())
}

fn get(url: &str) -> Option<String> {
    let mut response = ureq::get(url)
        .header("User-Agent", "anyrun-plugin-ethereum-search")
        .call()
        .map_err(|why| eprintln!("[ethereum-search] GET {url} failed: {why}"))
        .ok()?;
    response
        .body_mut()
        .read_to_string()
        .map_err(|why| eprintln!("[ethereum-search] Reading {url} failed: {why}"))
        .ok()
}

fn decode_html(value: &str) -> String {
    value
        .replace("&amp;", "&")
        .replace("&apos;", "'")
        .replace("&quot;", "\"")
        .replace("&lt;", "<")
        .replace("&gt;", ">")
}

fn parse_proposals(html: &str, kind: &str) -> Vec<Proposal> {
    index_pattern()
        .captures_iter(html)
        .filter_map(|capture| {
            let number = capture[1].parse().ok()?;
            let title = decode_html(capture[2].trim());
            if title.is_empty() {
                return None;
            }
            Some(Proposal {
                number,
                title,
                kind: kind.to_string(),
            })
        })
        .collect()
}

fn fetch_proposals() -> Option<Vec<Proposal>> {
    let all = get("https://eips.ethereum.org/all")?;
    let erc = get("https://eips.ethereum.org/erc")?;
    let erc_numbers: HashSet<u32> = parse_proposals(&erc, "ERC").into_iter().map(|proposal| proposal.number).collect();

    Some(
        parse_proposals(&all, "EIP")
            .into_iter()
            .map(|mut proposal| {
                if erc_numbers.contains(&proposal.number) {
                    proposal.kind = "ERC".to_string();
                }
                proposal
            })
            .collect(),
    )
}

fn load_proposals() -> Vec<Proposal> {
    let path = cache_path();
    let cached = fs::read_to_string(&path)
        .ok()
        .and_then(|content| serde_json::from_str::<Cache>(&content).ok());

    if let Some(cache) = &cached {
        if now().saturating_sub(cache.fetched_at) < CACHE_TTL.as_secs() {
            return cache.proposals.clone();
        }
    }

    match fetch_proposals() {
        Some(proposals) => {
            let cache = Cache {
                fetched_at: now(),
                proposals,
            };
            if let Some(parent) = path.parent() {
                let _ = fs::create_dir_all(parent);
            }
            if let Ok(content) = serde_json::to_string(&cache) {
                let _ = fs::write(&path, content);
            }
            cache.proposals
        }
        None => cached.map(|cache| cache.proposals).unwrap_or_default(),
    }
}

fn fetch_pull_request(repo: &str, number: u32) -> Option<PullRequest> {
    let body = get(&format!("https://api.github.com/repos/ethereum/{repo}/pulls/{number}"))?;
    let value: serde_json::Value = serde_json::from_str(&body)
        .map_err(|why| eprintln!("[ethereum-search] Parsing ethereum/{repo}#{number} failed: {why}"))
        .ok()?;

    Some(PullRequest {
        repo: repo.to_string(),
        number,
        title: value.get("title")?.as_str()?.to_string(),
        state: value.get("state")?.as_str()?.to_string(),
        url: value.get("html_url")?.as_str()?.to_string(),
    })
}

fn pull_request_match(state: &mut State, repo: &str, number: u32) -> Option<Match> {
    state
        .pull_requests
        .entry((repo.to_string(), number))
        .or_insert_with(|| fetch_pull_request(repo, number))
        .as_ref()
        .map(|pr| Match {
            title: format!("{} PR #{}: {}", pr.repo, pr.number, pr.title).into(),
            description: ROption::RSome(pr.url.clone().into()),
            use_pango: false,
            icon: ROption::RSome("vcs-git".into()),
            id: ROption::RNone,
        })
}

fn proposal_match(proposal: &Proposal) -> Match {
    Match {
        title: format!("{}-{}: {}", proposal.kind, proposal.number, proposal.title).into(),
        description: ROption::RSome(format!("https://eips.ethereum.org/EIPS/eip-{}", proposal.number).into()),
        use_pango: false,
        icon: ROption::RSome("text-x-generic".into()),
        id: ROption::RNone,
    }
}

#[init]
fn init(_config_dir: RString) -> State {
    State {
        proposals: load_proposals(),
        pull_requests: HashMap::new(),
    }
}

#[info]
fn info() -> PluginInfo {
    PluginInfo {
        name: "Ethereum Search".into(),
        icon: "text-x-generic".into(),
    }
}

#[get_matches]
fn get_matches(input: RString, state: &mut State) -> RVec<Match> {
    let query = input.trim().to_lowercase();
    if query.is_empty() {
        return RVec::new();
    }

    if let Some(capture) = pull_request_pattern().captures(&query) {
        let repo = if &capture[1] == "eips" { "EIPs" } else { "ERCs" };
        let number = capture[2].parse().unwrap_or(0);
        return pull_request_match(state, repo, number).into_iter().collect();
    }

    let mut matches: Vec<Match> = Vec::new();

    if let Some(capture) = number_pattern().captures(&query) {
        let kind_filter = capture.get(1).map(|kind| kind.as_str());
        let number = capture[2].parse().unwrap_or(0);

        matches.extend(
            state
                .proposals
                .iter()
                .filter(|proposal| {
                    proposal.number == number && kind_filter.map_or(true, |kind| proposal.kind.eq_ignore_ascii_case(kind))
                })
                .map(proposal_match),
        );

        if kind_filter.is_none() {
            matches.extend(pull_request_match(state, "EIPs", number));
            matches.extend(pull_request_match(state, "ERCs", number));
        }
        return matches.into();
    }

    let erc_only = query.starts_with("erc");
    let stripped = query
        .strip_prefix("erc")
        .or_else(|| query.strip_prefix("eip"))
        .unwrap_or(&query)
        .trim_start_matches([' ', '-']);

    if !stripped.is_empty() {
        matches.extend(
            state
                .proposals
                .iter()
                .filter(|proposal| {
                    if erc_only && proposal.kind != "ERC" {
                        return false;
                    }
                    proposal.title.to_lowercase().contains(stripped)
                })
                .take(15)
                .map(proposal_match),
        );
    }

    matches.into()
}

#[handler]
fn handler(selection: Match) -> HandleResult {
    if let ROption::RSome(url) = &selection.description {
        if let Err(why) = Command::new("sh").arg("-c").arg(format!("xdg-open \"{url}\"")).spawn() {
            eprintln!("[ethereum-search] Failed to open {url}: {why}");
        }
    }

    HandleResult::Close
}
