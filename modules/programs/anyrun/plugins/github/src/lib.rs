use abi_stable::std_types::{ROption, RString, RVec};
use anyrun_plugin::*;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;
use std::process::Command;
use std::time::{Duration, SystemTime, UNIX_EPOCH};

const CACHE_TTL: Duration = Duration::from_secs(3600);
const REPO_SOURCES: &[(&str, &str)] = &[("users", "lucemans"), ("orgs", "v3xlabs"), ("orgs", "ethereum")];
const KNOWN_OWNERS: &[&str] = &["lucemans", "v3xlabs", "ethereum"];

#[derive(Clone, Serialize, Deserialize)]
struct Repository {
    full_name: String,
    description: Option<String>,
}

#[derive(Serialize, Deserialize)]
struct Cache {
    fetched_at: u64,
    repositories: Vec<Repository>,
}

struct State {
    repositories: Vec<Repository>,
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
    base.join("anyrun-plugins/github-repos.json")
}

fn fetch_repositories() -> Option<Vec<Repository>> {
    let mut repositories = Vec::new();
    for (kind, owner) in REPO_SOURCES {
        let url = format!("https://api.github.com/{kind}/{owner}/repos?per_page=100&sort=pushed");
        let mut response = ureq::get(&url)
            .header("User-Agent", "anyrun-plugin-github")
            .call()
            .map_err(|why| eprintln!("[github] GET {url} failed: {why}"))
            .ok()?;
        let body = response
            .body_mut()
            .read_to_string()
            .map_err(|why| eprintln!("[github] Reading {url} failed: {why}"))
            .ok()?;
        let mut page: Vec<Repository> = serde_json::from_str(&body)
            .map_err(|why| eprintln!("[github] Parsing {url} failed: {why}"))
            .ok()?;
        repositories.append(&mut page);
    }
    Some(repositories)
}

fn load_repositories() -> Vec<Repository> {
    let path = cache_path();
    let cached = fs::read_to_string(&path)
        .ok()
        .and_then(|content| serde_json::from_str::<Cache>(&content).ok());

    if let Some(cache) = &cached {
        if now().saturating_sub(cache.fetched_at) < CACHE_TTL.as_secs() {
            return cache.repositories.clone();
        }
    }

    match fetch_repositories() {
        Some(repositories) => {
            let cache = Cache {
                fetched_at: now(),
                repositories,
            };
            if let Some(parent) = path.parent() {
                let _ = fs::create_dir_all(parent);
            }
            if let Ok(content) = serde_json::to_string(&cache) {
                let _ = fs::write(&path, content);
            }
            cache.repositories
        }
        None => cached.map(|cache| cache.repositories).unwrap_or_default(),
    }
}

fn fuzzy_score(query: &str, candidate: &str) -> Option<u32> {
    let mut score = 0u32;
    let mut remaining = query.chars().peekable();
    let mut consecutive = 0u32;

    for c in candidate.chars() {
        match remaining.peek() {
            Some(&q) if q == c => {
                consecutive += 1;
                score += 1 + consecutive * 2;
                remaining.next();
            }
            _ => consecutive = 0,
        }
    }

    if remaining.peek().is_some() {
        return None;
    }

    if candidate.contains(query) {
        score += 50 + 5 * query.len() as u32;
    }
    Some(score)
}

#[init]
fn init(_config_dir: RString) -> State {
    State {
        repositories: load_repositories(),
    }
}

#[info]
fn info() -> PluginInfo {
    PluginInfo {
        name: "GitHub".into(),
        icon: "folder".into(),
    }
}

#[get_matches]
fn get_matches(input: RString, state: &State) -> RVec<Match> {
    let query = input.trim();
    if query.is_empty() {
        return RVec::new();
    }

    let head = query.split('/').next().unwrap_or(query);
    if !query.contains(char::is_whitespace) && head.contains('.') && head.chars().any(|c| c.is_ascii_alphabetic()) {
        return vec![Match {
            title: query.into(),
            description: ROption::RSome("Open website".into()),
            use_pango: false,
            icon: ROption::RSome("applications-internet".into()),
            id: ROption::RSome(1),
        }]
        .into();
    }

    let lowercase = query.to_lowercase();
    let mut scored: Vec<(u32, &Repository)> = state
        .repositories
        .iter()
        .filter_map(|repo| fuzzy_score(&lowercase, &repo.full_name.to_lowercase()).map(|score| (score, repo)))
        .collect();
    scored.sort_by(|left, right| right.0.cmp(&left.0));

    let exact = query.split_once('/').and_then(|(owner, name)| {
        if KNOWN_OWNERS.contains(&owner) && !name.is_empty() && !name.contains(char::is_whitespace) {
            Some(query)
        } else {
            None
        }
    });

    let mut matches: Vec<Match> = Vec::new();
    if let Some(full_name) = exact {
        if !scored.iter().any(|(_, repo)| repo.full_name == full_name) {
            matches.push(Match {
                title: full_name.into(),
                description: ROption::RSome("Open GitHub repository".into()),
                use_pango: false,
                icon: ROption::RSome("folder".into()),
                id: ROption::RSome(0),
            });
        }
    }

    matches.extend(scored.into_iter().take(10).map(|(_, repo)| Match {
        title: repo.full_name.clone().into(),
        description: repo.description.clone().map(RString::from).into(),
        use_pango: false,
        icon: ROption::RSome("folder".into()),
        id: ROption::RSome(0),
    }));

    matches.into()
}

#[handler]
fn handler(selection: Match) -> HandleResult {
    let url = match selection.id {
        ROption::RSome(1) => format!("https://{}", selection.title),
        _ => format!("https://github.com/{}", selection.title),
    };

    if let Err(why) = Command::new("sh").arg("-c").arg(format!("xdg-open \"{url}\"")).spawn() {
        eprintln!("[github] Failed to open {url}: {why}");
    }

    HandleResult::Close
}
